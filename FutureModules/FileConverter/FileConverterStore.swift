import Foundation

// MARK: - State

enum ConversionState: Sendable {
    case idle
    case detecting
    case converting(progress: Double)
    case done(outputURL: URL)
    case failed(String)

    var isActive: Bool {
        switch self {
        case .detecting, .converting: return true
        default: return false
        }
    }

    var label: String {
        switch self {
        case .idle:               return "Drop or select a file"
        case .detecting:          return "Detecting type…"
        case .converting:         return "Converting…"
        case .done(let url):      return "Saved: \(url.lastPathComponent)"
        case .failed(let msg):    return "Error: \(msg)"
        }
    }
}

// MARK: - Conversion error

enum ConversionRoutingError: LocalizedError {
    case unsupportedCategory(FileCategory)
    case noOutputTypeSelected

    var errorDescription: String? {
        switch self {
        case .unsupportedCategory(let c): return "No converter available for \(c.rawValue) files."
        case .noOutputTypeSelected:       return "No output format selected."
        }
    }
}

// MARK: - Store

/// Orchestrates all converters. Holds ephemeral session state only.
/// Instantiate as `@State private var store = FileConverterStore()` inside the module view.
@Observable
@MainActor
final class FileConverterStore {

    // ── Inputs ────────────────────────────────────────────────────────────────
    var selectedFileURL: URL?
    var detectedType: FileType?
    var availableOutputTypes: [FileType] = []
    var selectedOutputType: FileType?
    var videoQuality: VideoQuality = .high
    var imageQuality: Double = 0.85    // 0.0–1.0

    // ── State ─────────────────────────────────────────────────────────────────
    var state: ConversionState = .idle

    // ── Public API ────────────────────────────────────────────────────────────

    /// Called when the user drops or picks a file. Detects type and populates output options.
    func selectFile(_ url: URL) {
        selectedFileURL = url
        state = .detecting
        detectedType = FileTypeDetector.fileType(for: url)

        Task {
            await refreshOutputTypes(for: url)
            state = .idle
        }
    }

    /// Runs the conversion. The caller is responsible for managing DismissalLock(.activeConvert).
    func convert() async {
        guard let input = selectedFileURL, let outputType = selectedOutputType else {
            state = .failed(ConversionRoutingError.noOutputTypeSelected.localizedDescription)
            return
        }
        state = .converting(progress: 0)

        do {
            let output = try await route(input: input, to: outputType)
            state = .done(outputURL: output)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func reset() {
        selectedFileURL = nil
        detectedType = nil
        availableOutputTypes = []
        selectedOutputType = nil
        state = .idle
    }

    // MARK: - Private routing

    private func route(input: URL, to outputType: FileType) async throws -> URL {
        switch FileTypeDetector.category(for: input) {
        case .image:
            return try await ImageConverter().convert(input: input, to: outputType, quality: imageQuality)
        case .document:
            return try await DocumentConverter().convert(input: input, to: outputType)
        case .audio:
            return try await AudioConverter().convert(input: input, to: outputType)
        case .video:
            return try await VideoConverter().convert(input: input, to: outputType, quality: videoQuality)
        case .archive:
            return try await ArchiveConverter().convert(input: input, to: outputType)
        case .unknown:
            throw ConversionRoutingError.unsupportedCategory(.unknown)
        }
    }

    private func refreshOutputTypes(for url: URL) async {
        let category = FileTypeDetector.category(for: url)

        switch category {
        case .audio:
            availableOutputTypes = await AudioConverter().availableOutputTypes(for: url)
        case .video:
            availableOutputTypes = await VideoConverter().availableOutputTypes(for: url)
        default:
            availableOutputTypes = FileTypeDetector.outputTypes(for: url)
        }
        selectedOutputType = availableOutputTypes.first
    }
}
