import Foundation
import UniformTypeIdentifiers

// MARK: - File Category

enum FileCategory: String, Sendable {
    case image, document, audio, video, archive, unknown
}

// MARK: - File Type

enum FileType: Hashable, Sendable {
    // Images
    case png, jpeg, webp, gif, tiff, heic, bmp, svg
    // Documents
    case pdf, txt, rtf, html, csv, docx, doc, odt, xlsx, xls, pptx, ppt
    // Audio
    case mp3, m4a, aac, wav, aiff, flac, ogg, caf
    // Video
    case mp4, mov, m4v, avi, mkv, webm
    // Archives
    case zip, tar, tarGz, tarBz2
    case unknown(String)

    var fileExtension: String {
        switch self {
        case .png:   return "png"
        case .jpeg:  return "jpg"
        case .webp:  return "webp"
        case .gif:   return "gif"
        case .tiff:  return "tiff"
        case .heic:  return "heic"
        case .bmp:   return "bmp"
        case .svg:   return "svg"
        case .pdf:   return "pdf"
        case .txt:   return "txt"
        case .rtf:   return "rtf"
        case .html:  return "html"
        case .csv:   return "csv"
        case .docx:  return "docx"
        case .doc:   return "doc"
        case .odt:   return "odt"
        case .xlsx:  return "xlsx"
        case .xls:   return "xls"
        case .pptx:  return "pptx"
        case .ppt:   return "ppt"
        case .mp3:   return "mp3"
        case .m4a:   return "m4a"
        case .aac:   return "aac"
        case .wav:   return "wav"
        case .aiff:  return "aiff"
        case .flac:  return "flac"
        case .ogg:   return "ogg"
        case .caf:   return "caf"
        case .mp4:   return "mp4"
        case .mov:   return "mov"
        case .m4v:   return "m4v"
        case .avi:   return "avi"
        case .mkv:   return "mkv"
        case .webm:  return "webm"
        case .zip:   return "zip"
        case .tar:   return "tar"
        case .tarGz: return "tar.gz"
        case .tarBz2: return "tar.bz2"
        case .unknown(let ext): return ext
        }
    }

    var displayName: String {
        switch self {
        case .png:   return "PNG"
        case .jpeg:  return "JPEG"
        case .webp:  return "WebP"
        case .gif:   return "GIF"
        case .tiff:  return "TIFF"
        case .heic:  return "HEIC"
        case .bmp:   return "BMP"
        case .svg:   return "SVG"
        case .pdf:   return "PDF"
        case .txt:   return "TXT"
        case .rtf:   return "RTF"
        case .html:  return "HTML"
        case .csv:   return "CSV"
        case .docx:  return "DOCX"
        case .doc:   return "DOC"
        case .odt:   return "ODT"
        case .xlsx:  return "XLSX"
        case .xls:   return "XLS"
        case .pptx:  return "PPTX"
        case .ppt:   return "PPT"
        case .mp3:   return "MP3"
        case .m4a:   return "M4A"
        case .aac:   return "AAC"
        case .wav:   return "WAV"
        case .aiff:  return "AIFF"
        case .flac:  return "FLAC"
        case .ogg:   return "OGG"
        case .caf:   return "CAF"
        case .mp4:   return "MP4"
        case .mov:   return "MOV"
        case .m4v:   return "M4V"
        case .avi:   return "AVI"
        case .mkv:   return "MKV"
        case .webm:  return "WebM"
        case .zip:   return "ZIP"
        case .tar:   return "TAR"
        case .tarGz: return "TAR.GZ"
        case .tarBz2: return "TAR.BZ2"
        case .unknown(let ext): return ext.uppercased()
        }
    }

    var category: FileCategory {
        switch self {
        case .png, .jpeg, .webp, .gif, .tiff, .heic, .bmp, .svg:
            return .image
        case .pdf, .txt, .rtf, .html, .csv, .docx, .doc, .odt, .xlsx, .xls, .pptx, .ppt:
            return .document
        case .mp3, .m4a, .aac, .wav, .aiff, .flac, .ogg, .caf:
            return .audio
        case .mp4, .mov, .m4v, .avi, .mkv, .webm:
            return .video
        case .zip, .tar, .tarGz, .tarBz2:
            return .archive
        case .unknown:
            return .unknown
        }
    }
}

// MARK: - Detector

struct FileTypeDetector: Sendable {

    /// Detects the FileType for a given URL using UTI first, extension fallback second.
    static func fileType(for url: URL) -> FileType {
        let path = url.path
        // Compound extensions must be checked before pathExtension (which only returns the last component)
        if path.hasSuffix(".tar.gz") || path.hasSuffix(".tgz") { return .tarGz }
        if path.hasSuffix(".tar.bz2") || path.hasSuffix(".tbz2") { return .tarBz2 }

        if let uti = UTType(filenameExtension: url.pathExtension.lowercased()),
           let resolved = fileType(fromUTI: uti) {
            return resolved
        }
        return fileType(fromExtension: url.pathExtension.lowercased())
    }

    static func category(for url: URL) -> FileCategory {
        fileType(for: url).category
    }

    /// Returns the valid output FileTypes for a given input URL.
    /// Note: audio and video output types are also verified at runtime via AVFoundation in their respective converters.
    static func outputTypes(for url: URL) -> [FileType] {
        outputTypes(for: fileType(for: url))
    }

    static func outputTypes(for type: FileType) -> [FileType] {
        switch type {
        // Images
        case .png:        return [.jpeg, .webp, .gif, .tiff, .heic, .bmp, .pdf]
        case .jpeg:       return [.png, .webp, .gif, .tiff, .heic, .bmp, .pdf]
        case .webp:       return [.png, .jpeg, .gif, .tiff, .bmp]
        case .gif:        return [.png, .jpeg, .webp, .tiff, .bmp]
        case .tiff:       return [.png, .jpeg, .webp, .gif, .heic, .bmp]
        case .heic:       return [.png, .jpeg, .webp, .tiff, .bmp]
        case .bmp:        return [.png, .jpeg, .webp, .gif, .tiff]
        case .svg:        return [.png, .jpeg, .pdf]
        // Documents
        case .pdf:        return [.txt, .png]
        case .txt:        return [.pdf, .html, .rtf, .docx]
        case .rtf:        return [.pdf, .txt, .html, .docx]
        case .html:       return [.pdf, .txt]
        case .csv:        return [.txt, .pdf]
        case .docx, .doc: return [.pdf, .txt, .html, .rtf]
        case .odt:        return [.pdf, .txt, .html, .rtf, .docx]
        case .xlsx, .xls: return [.csv, .pdf]
        case .pptx, .ppt: return [.pdf]
        // Audio (runtime verified in AudioConverter.availableOutputTypes)
        case .mp3, .m4a, .aac, .wav, .aiff, .flac, .ogg, .caf:
            return [.m4a, .wav, .aiff, .caf]
        // Video (runtime verified in VideoConverter.availableOutputTypes)
        case .mp4, .mov, .m4v, .avi, .mkv, .webm:
            return [.mp4, .mov, .m4v]
        // Archives
        case .zip:        return [.tarGz]
        case .tar, .tarGz, .tarBz2: return [.zip]
        case .unknown:    return []
        }
    }

    // MARK: - Private

    private static func fileType(fromUTI uti: UTType) -> FileType? {
        // Images
        if uti.conforms(to: .png)       { return .png }
        if uti.conforms(to: .jpeg)      { return .jpeg }
        if uti.conforms(to: .gif)       { return .gif }
        if uti.conforms(to: .tiff)      { return .tiff }
        if uti.conforms(to: .bmp)       { return .bmp }
        if uti.conforms(to: .svg)       { return .svg }
        // WebP has no system-level UTType conformance on all macOS versions; fall through to extension
        if uti.identifier == "org.webmproject.webp" || uti.identifier == "public.webp" { return .webp }
        if let heicType = UTType("public.heic"), uti.conforms(to: heicType) { return .heic }
        if let heifType = UTType("public.heif"), uti.conforms(to: heifType) { return .heic }

        // Documents
        if uti.conforms(to: .pdf)       { return .pdf }
        if uti.conforms(to: .html)      { return .html }
        if uti.conforms(to: .rtf)       { return .rtf }
        if uti.identifier == "public.comma-separated-values-text" { return .csv }
        if uti.conforms(to: .plainText) { return .txt }
        if uti.identifier == "org.openxmlformats.wordprocessingml.document" { return .docx }
        if uti.identifier == "com.microsoft.word.doc"                        { return .doc }
        if uti.identifier == "org.oasis-open.opendocument.text"              { return .odt }
        if uti.identifier == "org.openxmlformats.spreadsheetml.sheet"        { return .xlsx }
        if uti.identifier == "com.microsoft.excel.xls"                       { return .xls }
        if uti.identifier == "org.openxmlformats.presentationml.presentation" { return .pptx }
        if uti.identifier == "com.microsoft.powerpoint.ppt"                  { return .ppt }

        // Audio
        if uti.conforms(to: .mp3)         { return .mp3 }
        if uti.conforms(to: .mpeg4Audio)  { return .m4a }
        if uti.conforms(to: .aiff)        { return .aiff }
        if uti.conforms(to: .wav)         { return .wav }
        if uti.identifier == "org.xiph.flac"            { return .flac }
        if uti.identifier == "com.apple.coreaudio-format" { return .caf }

        // Video
        if uti.conforms(to: .mpeg4Movie)      { return .mp4 }
        if uti.conforms(to: .quickTimeMovie)  { return .mov }
        if uti.identifier == "com.apple.m4v-video" { return .m4v }
        if uti.identifier == "public.avi"          { return .avi }

        // Archives
        if uti.conforms(to: .zip) { return .zip }
        if uti.identifier == "public.tar-archive"          { return .tar }
        if uti.identifier == "org.gnu.gnu-zip-tar-archive" { return .tarGz }
        if uti.identifier == "public.bzip2-archive"        { return .tarBz2 }

        return nil
    }

    private static func fileType(fromExtension ext: String) -> FileType {
        switch ext {
        case "png":                return .png
        case "jpg", "jpeg":        return .jpeg
        case "webp":               return .webp
        case "gif":                return .gif
        case "tiff", "tif":        return .tiff
        case "heic", "heif":       return .heic
        case "bmp":                return .bmp
        case "svg":                return .svg
        case "pdf":                return .pdf
        case "txt", "text":        return .txt
        case "rtf":                return .rtf
        case "html", "htm":        return .html
        case "csv":                return .csv
        case "docx":               return .docx
        case "doc":                return .doc
        case "odt":                return .odt
        case "xlsx":               return .xlsx
        case "xls":                return .xls
        case "pptx":               return .pptx
        case "ppt":                return .ppt
        case "mp3":                return .mp3
        case "m4a":                return .m4a
        case "aac":                return .aac
        case "wav":                return .wav
        case "aiff", "aif":        return .aiff
        case "flac":               return .flac
        case "ogg", "oga":         return .ogg
        case "caf":                return .caf
        case "mp4":                return .mp4
        case "mov":                return .mov
        case "m4v":                return .m4v
        case "avi":                return .avi
        case "mkv":                return .mkv
        case "webm":               return .webm
        case "zip":                return .zip
        case "tar":                return .tar
        // .gz alone is ambiguous; treat as .tarGz (most common case on macOS)
        case "gz", "tgz":          return .tarGz
        case "bz2", "tbz2":        return .tarBz2
        default:                   return .unknown(ext)
        }
    }
}
