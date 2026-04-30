import Foundation
@preconcurrency import AVFoundation

// MARK: - Error

enum AudioConversionError: LocalizedError {
    case assetUnreadable
    case noAudioTrack
    case incompatibleOutputFormat(FileType)
    case exportFailed(Error?)
    case writerFailed(Error?)
    case unsupportedOutput(FileType)

    var errorDescription: String? {
        switch self {
        case .assetUnreadable:
            return "Could not read the audio file."
        case .noAudioTrack:
            return "The file contains no audio track."
        case .incompatibleOutputFormat(let t):
            return "\(t.displayName) output is not compatible with this audio source."
        case .exportFailed(let e):
            return "Export failed: \(e?.localizedDescription ?? "unknown error")"
        case .writerFailed(let e):
            return "PCM writer failed: \(e?.localizedDescription ?? "unknown error")"
        case .unsupportedOutput(let t):
            return "\(t.displayName) export is not supported. Try M4A, WAV, or AIFF."
        }
    }
}

// MARK: - Converter

struct AudioConverter: Sendable {

    /// Converts the audio file at `input` to `outputType`.
    /// - M4A / AAC → uses `AVAssetExportSession` with the Apple M4A preset.
    /// - WAV / AIFF / CAF → decoded to PCM via `AVAssetWriter` (works for all compressed sources).
    func convert(
        input: URL,
        to outputType: FileType,
        outputDir: URL? = nil
    ) async throws -> URL {
        let output = ImageConverter.outputURL(input: input, outputType: outputType, outputDir: outputDir)
        try? FileManager.default.removeItem(at: output)

        switch outputType {
        case .m4a, .aac:
            try await exportM4A(input: input, output: output)
        case .wav:
            try await exportPCM(input: input, output: output, fileType: .wav, bigEndian: false)
        case .aiff:
            try await exportPCM(input: input, output: output, fileType: .aiff, bigEndian: true)
        case .caf:
            try await exportPCM(input: input, output: output, fileType: .caf, bigEndian: false)
        default:
            throw AudioConversionError.unsupportedOutput(outputType)
        }
        return output
    }

    /// Returns the output types this file can realistically be converted to,
    /// verified at runtime against the asset.
    func availableOutputTypes(for input: URL) async -> [FileType] {
        let asset = AVURLAsset(url: input)
        var types: [FileType] = []
        if await isPresetCompatible(AVAssetExportPresetAppleM4A, with: asset, outputFileType: .m4a) {
            types.append(.m4a)
        }
        // PCM export (WAV/AIFF/CAF) works as long as the asset has an audio track
        if let tracks = try? await asset.loadTracks(withMediaType: .audio), !tracks.isEmpty {
            types.append(contentsOf: [.wav, .aiff, .caf])
        }
        // Remove the source format itself
        let inputType = FileTypeDetector.fileType(for: input)
        return types.filter { $0 != inputType }
    }

    // MARK: - M4A export (AVAssetExportSession)

    private func exportM4A(input: URL, output: URL) async throws {
        let asset = AVURLAsset(url: input)
        guard await isPresetCompatible(AVAssetExportPresetAppleM4A, with: asset, outputFileType: .m4a) else {
            throw AudioConversionError.incompatibleOutputFormat(.m4a)
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioConversionError.exportFailed(nil)
        }
        session.outputURL = output
        session.outputFileType = .m4a

        await session.export()

        if let error = session.error { throw AudioConversionError.exportFailed(error) }
        guard session.status == .completed else { throw AudioConversionError.exportFailed(nil) }
    }

    // MARK: - PCM export (AVAssetWriter + AVAssetReader)
    // Decodes any compressed audio source to raw PCM, enabling WAV/AIFF/CAF output.

    private func exportPCM(
        input: URL,
        output: URL,
        fileType: AVFileType,
        bigEndian: Bool
    ) async throws {
        let asset = AVURLAsset(url: input)

        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = tracks.first else {
            throw AudioConversionError.noAudioTrack
        }

        // Determine source sample rate + channel count from the format description
        let formatDescs = try await audioTrack.load(.formatDescriptions)
        let asbd = formatDescs.first.flatMap {
            CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
        }
        let sampleRate = asbd?.mSampleRate ?? 44100.0
        let channels = Int(asbd?.mChannelsPerFrame ?? 2)

        // Reader: decode to linear PCM
        let reader = try AVAssetReader(asset: asset)
        let readerSettings: [String: Any] = [
            AVFormatIDKey:              kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey:     16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey:      false,
            AVLinearPCMIsBigEndianKey:  bigEndian
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerSettings)
        reader.add(readerOutput)

        // Writer: encode to target format
        let writer = try AVAssetWriter(outputURL: output, fileType: fileType)
        let writerSettings: [String: Any] = [
            AVFormatIDKey:              kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey:     16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey:      false,
            AVLinearPCMIsBigEndianKey:  bigEndian,
            AVSampleRateKey:            sampleRate,
            AVNumberOfChannelsKey:      channels
        ]
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        guard reader.startReading() else {
            throw AudioConversionError.assetUnreadable
        }
        guard writer.startWriting() else {
            throw AudioConversionError.writerFailed(writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "audio.pcm.export", qos: .userInitiated)
            let exportSession = PCMExportSession(
                writer: writer,
                writerInput: writerInput,
                readerOutput: readerOutput,
                continuation: cont
            )

            writerInput.requestMediaDataWhenReady(on: queue, using: exportSession.drain)
        }

        guard writer.status == .completed else {
            throw AudioConversionError.writerFailed(writer.error)
        }
    }

    private func isPresetCompatible(
        _ preset: String,
        with asset: AVAsset,
        outputFileType: AVFileType?
    ) async -> Bool {
        await AVAssetExportSession.compatibility(
            ofExportPreset: preset,
            with: asset,
            outputFileType: outputFileType
        )
    }
}

private final class PCMExportSession: @unchecked Sendable {
    private let writer: AVAssetWriter
    private let writerInput: AVAssetWriterInput
    private let readerOutput: AVAssetReaderTrackOutput
    private let continuation: CheckedContinuation<Void, Error>

    init(
        writer: AVAssetWriter,
        writerInput: AVAssetWriterInput,
        readerOutput: AVAssetReaderTrackOutput,
        continuation: CheckedContinuation<Void, Error>
    ) {
        self.writer = writer
        self.writerInput = writerInput
        self.readerOutput = readerOutput
        self.continuation = continuation
    }

    func drain() {
        while writerInput.isReadyForMoreMediaData {
            if let buffer = readerOutput.copyNextSampleBuffer() {
                writerInput.append(buffer)
            } else {
                writerInput.markAsFinished()
                writer.finishWriting { [writer, continuation] in
                    if let error = writer.error {
                        continuation.resume(throwing: AudioConversionError.writerFailed(error))
                    } else {
                        continuation.resume()
                    }
                }
                return
            }
        }
    }
}
