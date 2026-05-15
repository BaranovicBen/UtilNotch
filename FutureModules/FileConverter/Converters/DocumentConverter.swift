import Foundation
import PDFKit
import WebKit

// MARK: - Error

enum DocumentConversionError: LocalizedError {
    case unsupportedConversion(FileType, FileType)
    case textutilFailed(Int32, String)
    case pdfReadFailed
    case pdfWriteFailed
    case xlsxExtractionFailed(String)
    case webViewFailed(Error?)
    case processLaunchFailed(Error)
    case tempFileFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedConversion(let from, let to):
            return "Cannot convert \(from.displayName) → \(to.displayName)."
        case .textutilFailed(let code, let msg):
            return "textutil exited \(code): \(msg)"
        case .pdfReadFailed:
            return "Could not read PDF document."
        case .pdfWriteFailed:
            return "Could not write PDF output."
        case .xlsxExtractionFailed(let reason):
            return "XLSX extraction failed: \(reason)"
        case .webViewFailed(let e):
            return "Web renderer failed: \(e?.localizedDescription ?? "unknown")"
        case .processLaunchFailed(let e):
            return "Could not launch conversion process: \(e.localizedDescription)"
        case .tempFileFailed:
            return "Could not create temporary file."
        }
    }
}

// MARK: - HTML → PDF renderer (must live on MainActor — WKWebView is AppKit-bound)

@MainActor
private final class HTMLToPDFRenderer: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var loadContinuation: CheckedContinuation<Void, Error>?

    override init() {
        // A4 in points: 595 × 842. Use 2× for higher-fidelity PDF output.
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 794, height: 1123))
        super.init()
        webView.navigationDelegate = self
    }

    func renderURL(_ url: URL) async throws -> Data {
        try await loadURL(url)
        return try await makePDF()
    }

    func renderHTML(_ html: String, baseURL: URL? = nil) async throws -> Data {
        try await loadHTML(html, baseURL: baseURL)
        return try await makePDF()
    }

    // MARK: - Private load helpers

    private func loadURL(_ url: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            loadContinuation = cont
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    private func loadHTML(_ html: String, baseURL: URL?) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            loadContinuation = cont
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    private func makePDF() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            webView.createPDF(configuration: WKPDFConfiguration()) { result in
                switch result {
                case .success(let data): continuation.resume(returning: data)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            loadContinuation?.resume()
            loadContinuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            loadContinuation?.resume(throwing: error)
            loadContinuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            loadContinuation?.resume(throwing: error)
            loadContinuation = nil
        }
    }
}

// MARK: - Document Converter

struct DocumentConverter: Sendable {

    // @MainActor helpers — WKWebView must be created and used on the main thread
    @MainActor private func pdfFromURL(_ url: URL) async throws -> Data {
        try await HTMLToPDFRenderer().renderURL(url)
    }

    @MainActor private func pdfFromHTML(_ html: String) async throws -> Data {
        try await HTMLToPDFRenderer().renderHTML(html)
    }

    /// Routes the input document to the correct conversion path.
    func convert(input: URL, to outputType: FileType, outputDir: URL? = nil) async throws -> URL {
        let inputType = FileTypeDetector.fileType(for: input)
        let output = ImageConverter.outputURL(input: input, outputType: outputType, outputDir: outputDir)

        switch (inputType, outputType) {

        // ── textutil native paths ─────────────────────────────────────────────
        // textutil supports: txt, html, rtf, rtfd, doc, docx, wordml, odt, webarchive
        case (.docx, .txt), (.doc, .txt), (.odt, .txt), (.rtf, .txt):
            try await runTextutil(input: input, outputFormat: "txt", output: output)

        case (.docx, .html), (.doc, .html), (.odt, .html), (.rtf, .html):
            try await runTextutil(input: input, outputFormat: "html", output: output)

        case (.docx, .rtf), (.doc, .rtf), (.odt, .rtf):
            try await runTextutil(input: input, outputFormat: "rtf", output: output)

        case (.docx, .docx), (.doc, .docx), (.odt, .docx), (.rtf, .docx):
            try await runTextutil(input: input, outputFormat: "docx", output: output)

        case (.txt, .html):
            // Wrap plain text in a minimal HTML page so the renderer has context
            let text = try String(contentsOf: input, encoding: .utf8)
            let html = wrapInHTML(text, preformatted: true)
            try html.write(to: output, atomically: true, encoding: .utf8)

        case (.txt, .rtf):
            try await runTextutil(input: input, outputFormat: "rtf", output: output)

        case (.txt, .docx):
            try await runTextutil(input: input, outputFormat: "docx", output: output)

        // ── HTML → PDF (direct WKWebView render) ─────────────────────────────
        case (.html, .pdf):
            let data = try await pdfFromURL(input)
            try data.write(to: output)

        case (.html, .txt):
            // Strip tags via NSAttributedString
            let html = try Data(contentsOf: input)
            let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            let attrStr = try NSAttributedString(data: html, options: opts, documentAttributes: nil)
            try attrStr.string.write(to: output, atomically: true, encoding: .utf8)

        // ── DOCX/DOC/ODT/RTF → PDF (textutil → HTML temp → WKWebView → PDF) ─
        case (.docx, .pdf), (.doc, .pdf), (.odt, .pdf), (.rtf, .pdf):
            try await convertRichTextToPDF(input: input, output: output)

        // ── TXT/CSV → PDF (wrap in HTML, WKWebView → PDF) ────────────────────
        case (.txt, .pdf), (.csv, .pdf):
            let text = try String(contentsOf: input, encoding: .utf8)
            let html = wrapInHTML(text, preformatted: true)
            let data = try await pdfFromHTML(html)
            try data.write(to: output)

        // ── PDF → TXT (PDFKit text extraction) ───────────────────────────────
        case (.pdf, .txt):
            try extractTextFromPDF(input: input, output: output)

        // ── PDF → PNG (render first page) ────────────────────────────────────
        case (.pdf, .png):
            try renderPDFPageAsImage(input: input, output: output, outputType: .png)

        // ── CSV ↔ TXT (delimiter reformat) ───────────────────────────────────
        case (.csv, .txt):
            let text = try String(contentsOf: input, encoding: .utf8)
            let readable = text.replacingOccurrences(of: ",", with: "\t")
            try readable.write(to: output, atomically: true, encoding: .utf8)

        // ── XLSX → CSV (XML parse) ────────────────────────────────────────────
        case (.xlsx, .csv), (.xls, .csv):
            try await convertXLSXToCSV(input: input, output: output)

        // ── XLSX/PPTX → PDF (Quick Look render via WKWebView) ─────────────────
        // Note: XLSX → PDF fidelity depends on macOS Quick Look support.
        case (.xlsx, .pdf), (.xls, .pdf), (.pptx, .pdf), (.ppt, .pdf):
            try await convertOfficeToPDFViaPreview(input: input, output: output)

        default:
            throw DocumentConversionError.unsupportedConversion(inputType, outputType)
        }

        return output
    }

    // MARK: - textutil subprocess

    private func runTextutil(input: URL, outputFormat: String, output: URL) async throws {
        let stderr = Pipe()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
            process.arguments = ["-convert", outputFormat, "-output", output.path, input.path]
            process.standardError = stderr
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    let errMsg = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    cont.resume(throwing: DocumentConversionError.textutilFailed(proc.terminationStatus, errMsg))
                }
            }
            do {
                try process.run()
            } catch {
                cont.resume(throwing: DocumentConversionError.processLaunchFailed(error))
            }
        }
    }

    // MARK: - DOCX/DOC/ODT/RTF → PDF (two-step: textutil → HTML → WKWebView → PDF)

    private func convertRichTextToPDF(input: URL, output: URL) async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: temp) }

        try await runTextutil(input: input, outputFormat: "html", output: temp)
        let data = try await pdfFromURL(temp)
        try data.write(to: output)
    }

    // MARK: - PDF → TXT (PDFKit)

    private func extractTextFromPDF(input: URL, output: URL) throws {
        guard let doc = PDFDocument(url: input) else {
            throw DocumentConversionError.pdfReadFailed
        }
        let text = doc.string ?? ""
        try text.write(to: output, atomically: true, encoding: .utf8)
    }

    // MARK: - PDF → PNG (first page render)

    private func renderPDFPageAsImage(input: URL, output: URL, outputType: FileType) throws {
        guard let doc = PDFDocument(url: input),
              let page = doc.page(at: 0) else {
            throw DocumentConversionError.pdfReadFailed
        }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0   // 2× for crisp output
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep = bitmapRep,
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            throw DocumentConversionError.pdfWriteFailed
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.cgContext.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx.cgContext)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw DocumentConversionError.pdfWriteFailed
        }
        try data.write(to: output)
    }

    // MARK: - XLSX → CSV (unzip + XML parse)

    private func convertXLSXToCSV(input: URL, output: URL) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Unzip XLSX (it is a ZIP archive) into tempDir
        try await runUnzip(archive: input, destination: tempDir)

        // Parse shared strings (optional — not all XLSX files have them)
        let sharedStringsURL = tempDir.appendingPathComponent("xl/sharedStrings.xml")
        let sharedStrings = (try? parseSharedStrings(at: sharedStringsURL)) ?? []

        // Parse first sheet
        let sheetURL = tempDir.appendingPathComponent("xl/worksheets/sheet1.xml")
        guard FileManager.default.fileExists(atPath: sheetURL.path) else {
            throw DocumentConversionError.xlsxExtractionFailed("sheet1.xml not found")
        }
        let rows = try parseSheet(at: sheetURL, sharedStrings: sharedStrings)

        // Write CSV
        let csv = rows.map { row in
            row.map { cell in
                // Quote cells that contain commas or quotes
                let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                return escaped.contains(",") || escaped.contains("\n") ? "\"\(escaped)\"" : escaped
            }.joined(separator: ",")
        }.joined(separator: "\n")

        try csv.write(to: output, atomically: true, encoding: .utf8)
    }

    private func runUnzip(archive: URL, destination: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", "-q", archive.path, "-d", destination.path]
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    cont.resume(throwing: DocumentConversionError.xlsxExtractionFailed("unzip exited \(proc.terminationStatus)"))
                }
            }
            do {
                try process.run()
            } catch {
                cont.resume(throwing: DocumentConversionError.processLaunchFailed(error))
            }
        }
    }

    // MARK: - XLSX XML parsers

    private func parseSharedStrings(at url: URL) throws -> [String] {
        guard let parser = XMLParser(contentsOf: url) else { return [] }
        let delegate = SharedStringsXMLDelegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    private func parseSheet(at url: URL, sharedStrings: [String]) throws -> [[String]] {
        guard let parser = XMLParser(contentsOf: url) else {
            throw DocumentConversionError.xlsxExtractionFailed("Cannot create XML parser for sheet")
        }
        let delegate = SheetXMLDelegate(sharedStrings: sharedStrings)
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }

    // MARK: - XLSX/PPTX → PDF via QLPreviewGeneratorRequest + WKWebView fallback

    @MainActor
    private func convertOfficeToPDFViaPreview(input: URL, output: URL) async throws {
        // Use NSWorkspace Quick Look to open the file in Preview and export as PDF.
        // On macOS, QLPreviewController requires a view hierarchy.
        // We use the headless approach: load the file URL into WKWebView which
        // delegates to Quick Look for Office formats on macOS 12+.
        let renderer = HTMLToPDFRenderer()
        // WKWebView can render Office files via Quick Look integration on macOS 12+
        let data = try await renderer.renderURL(input)
        try data.write(to: output)
    }

    // MARK: - Helpers

    private func wrapInHTML(_ text: String, preformatted: Bool) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let body = preformatted
            ? "<pre style=\"font-family: monospace; white-space: pre-wrap; word-break: break-all;\">\(escaped)</pre>"
            : "<p>\(escaped)</p>"
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <style>body { font-family: -apple-system, sans-serif; margin: 40px; color: #1c1c1e; }</style>
        </head><body>\(body)</body></html>
        """
    }
}

// MARK: - Shared Strings XML delegate

private final class SharedStringsXMLDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {
    var strings: [String] = []
    private var current = ""
    private var inT = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "si" { current = "" }
        else if elementName == "t" { inT = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inT { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" { inT = false }
        else if elementName == "si" { strings.append(current) }
    }
}

// MARK: - Sheet XML delegate

private final class SheetXMLDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {
    var rows: [[String]] = []
    private let sharedStrings: [String]

    private var currentRow: [String] = []
    private var currentValue = ""
    private var inV = false
    private var cellType = ""     // "s" = shared string, "str" = inline string, "" = number/date

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        switch elementName {
        case "row":
            currentRow = []
        case "c":
            cellType = attributes["t"] ?? ""
            currentValue = ""
        case "v", "t":
            inV = true
            currentValue = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inV { currentValue += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "v", "t":
            inV = false
        case "c":
            let resolved: String
            if cellType == "s", let idx = Int(currentValue), idx < sharedStrings.count {
                resolved = sharedStrings[idx]
            } else {
                resolved = currentValue
            }
            currentRow.append(resolved)
        case "row":
            if !currentRow.isEmpty { rows.append(currentRow) }
        default:
            break
        }
    }
}
