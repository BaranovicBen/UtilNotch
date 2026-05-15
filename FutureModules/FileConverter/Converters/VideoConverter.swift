import Foundation
@preconcurrency import AVFoundation

// MARK: - Error

enum VideoConversionError: LocalizedError {
    case assetUnreadable
    case noVideoTrack
    case incompatiblePreset(String)
    case exportFailed(Error?)
    case unsupportedOutput(FileType)

    var errorDescription: String? {
        switch self {
        case .assetUnreadable:
            return "Could not read the video file."
        case .noVideoTrack:
            return "The file contains no video track."
        case .incompatiblePreset(let preset):
            return "Export preset '\(preset)' is not compatible with this video."
        case .exportFailed(let e):
            return "Export failed: \(e?.localizedDescription ?? "unknown error")"
        case .unsupportedOutput(let t):
            return "\(t.displayName) video export is not supported. Try MP4 or MOV."
        }
    }
}

// MARK: - Quality preset

enum VideoQuality: String, CaseIterable, Sendable {
    case high    = "1080p"
    case medium  = "720p"
    case low     = "480p"

    var avPreset: String {
        switch self {
        case .high:   return AVAssetExportPreset1920x1080
        case .medium: return AVAssetExportPreset1280x720
        case .low:    return AVAssetExportPreset640x480
        }
    }
}

// MARK: - Converter

struct VideoConverter: Sendable {

    /// Converts the video at `input` to `outputType` at the given quality.
    /// Falls back to the next available quality preset if the requested one is incompatible.
    func convert(
        input: URL,
        to outputType: FileType,
        quality: VideoQuality = .high,
        outputDir: URL? = nil
    ) async throws -> URL {
        let output = ImageConverter.outputURL(input: input, outputType: outputType, outputDir: outputDir)
        try? FileManager.default.removeItem(at: output)

        guard let avFileType = avFileType(for: outputType) else {
            throw VideoConversionError.unsupportedOutput(outputType)
        }

        let asset = AVURLAsset(url: input)

        // Verify asset has a video track
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoConversionError.noVideoTrack
        }

        // Find the best compatible preset (requested → medium → passthrough)
        let preset = try await resolvePreset(for: asset, preferred: quality, outputFileType: avFileType)

        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw VideoConversionError.exportFailed(nil)
        }
        session.outputURL = output
        session.outputFileType = avFileType
        // Preserve metadata (creation date, GPS tags, etc.)
        session.shouldOptimizeForNetworkUse = true

        await session.export()

        if let error = session.error { throw VideoConversionError.exportFailed(error) }
        guard session.status == .completed else { throw VideoConversionError.exportFailed(nil) }

        return output
    }

    /// Returns quality-aware output types available for this video at runtime.
    func availableOutputTypes(for input: URL) async -> [FileType] {
        let asset = AVURLAsset(url: input)
        let inputType = FileTypeDetector.fileType(for: input)
        var types: [FileType] = []

        for outputType in [FileType.mp4, .mov, .m4v] where outputType != inputType {
            guard let fileType = avFileType(for: outputType) else { continue }
            if await hasCompatiblePreset(for: asset, outputFileType: fileType) {
                types.append(outputType)
            }
        }

        return types
    }

    // MARK: - Helpers

    private func resolvePreset(
        for asset: AVAsset,
        preferred: VideoQuality,
        outputFileType: AVFileType
    ) async throws -> String {
        // Walk from preferred quality downward, then try passthrough
        let candidates: [String] = VideoQuality.allCases
            .dropFirst(VideoQuality.allCases.firstIndex(of: preferred)!)
            .map(\.avPreset)
            + [AVAssetExportPresetPassthrough]

        for candidate in candidates {
            if await isPresetCompatible(candidate, with: asset, outputFileType: outputFileType) {
                return candidate
            }
        }

        throw VideoConversionError.incompatiblePreset(preferred.avPreset)
    }

    private func hasCompatiblePreset(for asset: AVAsset, outputFileType: AVFileType) async -> Bool {
        for quality in VideoQuality.allCases {
            if await isPresetCompatible(quality.avPreset, with: asset, outputFileType: outputFileType) {
                return true
            }
        }
        return await isPresetCompatible(
            AVAssetExportPresetPassthrough,
            with: asset,
            outputFileType: outputFileType
        )
    }

    private func isPresetCompatible(
        _ preset: String,
        with asset: AVAsset,
        outputFileType: AVFileType
    ) async -> Bool {
        await AVAssetExportSession.compatibility(
            ofExportPreset: preset,
            with: asset,
            outputFileType: outputFileType
        )
    }

    private func avFileType(for type: FileType) -> AVFileType? {
        switch type {
        case .mp4:  return .mp4
        case .mov:  return .mov
        case .m4v:  return .m4v
        default:    return nil
        }
    }
}
