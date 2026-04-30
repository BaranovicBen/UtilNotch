import Foundation
import ImageIO
import AppKit
import CoreGraphics

// MARK: - Error

enum ImageConversionError: LocalizedError {
    case unreadableSource
    case unsupportedOutputType(FileType)
    case encodingFailed
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unreadableSource:
            return "Could not read the image source file."
        case .unsupportedOutputType(let t):
            return "Cannot write \(t.displayName) images."
        case .encodingFailed:
            return "Image encoding failed — the format may not be writable on this system."
        case .writeFailed(let e):
            return "Could not write output file: \(e.localizedDescription)"
        }
    }
}

// MARK: - Converter

struct ImageConverter: Sendable {

    /// Converts the image at `input` to `outputType`.
    /// - Parameters:
    ///   - quality: Compression quality 0.0–1.0 for lossy formats (JPEG, WebP, HEIC). Ignored for lossless.
    ///   - outputDir: Destination directory. Defaults to the same directory as the input file.
    /// - Returns: URL of the written output file.
    func convert(
        input: URL,
        to outputType: FileType,
        quality: Double = 0.85,
        outputDir: URL? = nil
    ) async throws -> URL {
        let output = Self.outputURL(input: input, outputType: outputType, outputDir: outputDir)
        let inputType = FileTypeDetector.fileType(for: input)

        if inputType == .svg {
            // NSImage renders SVG via WebKit — must run on main actor
            try await MainActor.run {
                try convertSVG(input: input, to: outputType, quality: quality, output: output)
            }
        } else {
            // ImageIO is thread-safe and runs inline
            try convertViaImageIO(input: input, to: outputType, quality: quality, output: output)
        }
        return output
    }

    // MARK: - ImageIO path (PNG, JPEG, WebP, GIF, TIFF, HEIC, BMP)

    private func convertViaImageIO(
        input: URL,
        to outputType: FileType,
        quality: Double,
        output: URL
    ) throws {
        guard
            let source = CGImageSourceCreateWithURL(input as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ImageConversionError.unreadableSource
        }

        if outputType == .pdf {
            try renderCGImageAsPDF(cgImage, output: output)
            return
        }

        guard let utiString = uti(for: outputType) else {
            throw ImageConversionError.unsupportedOutputType(outputType)
        }

        var options: [CFString: Any] = [:]
        if isLossy(outputType) {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }

        guard let dest = CGImageDestinationCreateWithURL(output as CFURL, utiString as CFString, 1, nil) else {
            throw ImageConversionError.encodingFailed
        }
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw ImageConversionError.encodingFailed
        }
    }

    // MARK: - SVG path (macOS rasterises SVG via NSImage/WebKit)

    @MainActor
    private func convertSVG(
        input: URL,
        to outputType: FileType,
        quality: Double,
        output: URL
    ) throws {
        guard let nsImage = NSImage(contentsOf: input) else {
            throw ImageConversionError.unreadableSource
        }

        if outputType == .pdf {
            try renderNSImageAsPDF(nsImage, output: output)
            return
        }

        var proposedRect = CGRect(origin: .zero, size: nsImage.size)
        guard let cgImage = nsImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            throw ImageConversionError.unreadableSource
        }
        guard let utiString = uti(for: outputType) else {
            throw ImageConversionError.unsupportedOutputType(outputType)
        }

        var options: [CFString: Any] = [:]
        if isLossy(outputType) {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }

        guard let dest = CGImageDestinationCreateWithURL(output as CFURL, utiString as CFString, 1, nil) else {
            throw ImageConversionError.encodingFailed
        }
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw ImageConversionError.encodingFailed
        }
    }

    // MARK: - PDF rendering

    private func renderCGImageAsPDF(_ image: CGImage, output: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard let ctx = CGContext(output as CFURL, mediaBox: &mediaBox, nil) else {
            throw ImageConversionError.encodingFailed
        }
        ctx.beginPDFPage(nil)
        ctx.draw(image, in: mediaBox)
        ctx.endPDFPage()
        ctx.closePDF()
    }

    @MainActor
    private func renderNSImageAsPDF(_ image: NSImage, output: URL) throws {
        var mediaBox = CGRect(origin: .zero, size: image.size)
        guard let ctx = CGContext(output as CFURL, mediaBox: &mediaBox, nil) else {
            throw ImageConversionError.encodingFailed
        }
        ctx.beginPDFPage(nil)
        if let cgImage = image.cgImage(forProposedRect: &mediaBox, context: nil, hints: nil) {
            ctx.draw(cgImage, in: mediaBox)
        }
        ctx.endPDFPage()
        ctx.closePDF()
    }

    // MARK: - Helpers

    private func uti(for type: FileType) -> String? {
        switch type {
        case .png:  return "public.png"
        case .jpeg: return "public.jpeg"
        case .webp: return "org.webmproject.webp"
        case .gif:  return "com.compuserve.gif"
        case .tiff: return "public.tiff"
        case .heic: return "public.heic"
        case .bmp:  return "com.microsoft.bmp"
        default:    return nil
        }
    }

    private func isLossy(_ type: FileType) -> Bool {
        switch type {
        case .jpeg, .webp, .heic: return true
        default: return false
        }
    }

    static func outputURL(input: URL, outputType: FileType, outputDir: URL?) -> URL {
        let dir = outputDir ?? input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent
        let ext = outputType.fileExtension
        // fileExtension may contain a dot (e.g. "tar.gz") — use appendingPathComponent instead of appendingPathExtension
        return dir.appendingPathComponent("\(base).\(ext)")
    }
}
