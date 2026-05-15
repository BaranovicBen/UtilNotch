import Foundation

// MARK: - Error

enum ArchiveConversionError: LocalizedError {
    case processLaunchFailed(Error)
    case processFailed(Int32, String)
    case unsupportedConversion(FileType, FileType)
    case outputDirCreationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .processLaunchFailed(let e):
            return "Could not launch archive tool: \(e.localizedDescription)"
        case .processFailed(let code, let msg):
            return "Archive tool exited \(code): \(msg)"
        case .unsupportedConversion(let from, let to):
            return "Cannot convert \(from.displayName) → \(to.displayName)."
        case .outputDirCreationFailed(let e):
            return "Could not create output directory: \(e.localizedDescription)"
        }
    }
}

// MARK: - Converter

struct ArchiveConverter: Sendable {

    /// Compresses `input` (file or folder) to `outputType`.
    func compress(
        input: URL,
        to outputType: FileType,
        outputDir: URL? = nil
    ) async throws -> URL {
        let output = ImageConverter.outputURL(input: input, outputType: outputType, outputDir: outputDir)
        try? FileManager.default.removeItem(at: output)

        switch outputType {
        case .zip:
            try await compressToZIP(input: input, output: output)
        case .tar:
            try await compressToTAR(input: input, output: output, compress: .none)
        case .tarGz:
            try await compressToTAR(input: input, output: output, compress: .gzip)
        case .tarBz2:
            try await compressToTAR(input: input, output: output, compress: .bzip2)
        default:
            throw ArchiveConversionError.unsupportedConversion(FileTypeDetector.fileType(for: input), outputType)
        }
        return output
    }

    /// Extracts `input` archive into a folder next to the source (or into `outputDir`).
    /// Returns the URL of the extraction folder.
    func decompress(input: URL, outputDir: URL? = nil) async throws -> URL {
        let destFolder: URL
        if let dir = outputDir {
            destFolder = dir
        } else {
            let base = input.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: ".tar", with: "")  // handle double ext
            destFolder = input.deletingLastPathComponent().appendingPathComponent(base)
        }

        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)

        let inputType = FileTypeDetector.fileType(for: input)
        switch inputType {
        case .zip:
            try await extractZIP(archive: input, destination: destFolder)
        case .tar:
            try await extractTAR(archive: input, destination: destFolder, flags: ["-xf"])
        case .tarGz:
            try await extractTAR(archive: input, destination: destFolder, flags: ["-xzf"])
        case .tarBz2:
            try await extractTAR(archive: input, destination: destFolder, flags: ["-xjf"])
        default:
            throw ArchiveConversionError.unsupportedConversion(inputType, .unknown("folder"))
        }
        return destFolder
    }

    /// Converts between archive formats (extract → recompress).
    func convert(
        input: URL,
        to outputType: FileType,
        outputDir: URL? = nil
    ) async throws -> URL {
        let inputType = FileTypeDetector.fileType(for: input)
        guard inputType.category == .archive else {
            throw ArchiveConversionError.unsupportedConversion(inputType, outputType)
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let extracted = try await decompress(input: input, outputDir: tempDir)
        return try await compress(input: extracted, to: outputType, outputDir: outputDir)
    }

    // MARK: - ZIP

    private func compressToZIP(input: URL, output: URL) async throws {
        // ditto is the macOS-preferred tool for ZIP creation; preserves resource forks + metadata
        try await run(
            executable: "/usr/bin/ditto",
            arguments: ["-c", "-k", "--keepParent", "--sequesterRsrc", input.path, output.path]
        )
    }

    private func extractZIP(archive: URL, destination: URL) async throws {
        try await run(
            executable: "/usr/bin/unzip",
            arguments: ["-o", "-q", archive.path, "-d", destination.path]
        )
    }

    // MARK: - TAR

    private enum TARCompression { case none, gzip, bzip2 }

    private func compressToTAR(input: URL, output: URL, compress: TARCompression) async throws {
        let flag: String
        switch compress {
        case .none:  flag = "-cf"
        case .gzip:  flag = "-czf"
        case .bzip2: flag = "-cjf"
        }
        // Change to the parent directory so tar stores relative paths
        let parent = input.deletingLastPathComponent().path
        let name   = input.lastPathComponent
        try await run(
            executable: "/usr/bin/tar",
            arguments: [flag, output.path, "-C", parent, name]
        )
    }

    private func extractTAR(archive: URL, destination: URL, flags: [String]) async throws {
        try await run(
            executable: "/usr/bin/tar",
            arguments: flags + [archive.path, "-C", destination.path]
        )
    }

    // MARK: - Process runner

    private func run(executable: String, arguments: [String]) async throws {
        let stderr = Pipe()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardError = stderr
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    let msg = String(
                        data: stderr.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? ""
                    cont.resume(throwing: ArchiveConversionError.processFailed(proc.terminationStatus, msg))
                }
            }
            do {
                try process.run()
            } catch {
                cont.resume(throwing: ArchiveConversionError.processLaunchFailed(error))
            }
        }
    }
}
