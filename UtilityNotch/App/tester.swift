
import Foundation

@MainActor
func runConverterSmokeTests() async {
    let desktop = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/ConverterTests")
    try? FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)

    // ── Image ─────────────────────────────────────────────────────────────────
    let imgSrc = URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")
    do {
        let out = try await ImageConverter().convert(input: imgSrc, to: .jpeg, outputDir: desktop)
        print("✅ Image HEIC→JPEG:", out.path)
    } catch { print("❌ Image:", error) }

    // ── Document (TXT → PDF via WKWebView) ────────────────────────────────────
    let txtSrc = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
    try? "Hello world!\nThis is a test.".write(to: txtSrc, atomically: true, encoding: .utf8)
    do {
        let out = try await DocumentConverter().convert(input: txtSrc, to: .pdf, outputDir: desktop)
        print("✅ Document TXT→PDF:", out.path)
    } catch { print("❌ Document:", error) }

    // ── Audio (MP3 / M4A / any audio file you have) /Users/benjaminbaranovic/Downloads/i-like-your-cut-g-revisited.mp3 ───────────────────────────
    // Replace with a real audio file path on your machine
    let audSrc = URL(fileURLWithPath: "/Users/benjaminbaranovic/Downloads/i-like-your-cut-g-revisited.mp3")
    if FileManager.default.fileExists(atPath: audSrc.path) {
        do {
            let out = try await AudioConverter().convert(input: audSrc, to: .m4a, outputDir:
desktop)
            print("✅ Audio MP3→M4A:", out.path)
        } catch { print("❌ Audio:", error) }
    }

    // ── Video (any .mov / .mp4 on your machine) ───────────────────────────────
    let vidSrc = URL(fileURLWithPath: "/Users/benjaminbaranovic/Downloads/file_example_MOV_480_700kB.mov")
    if FileManager.default.fileExists(atPath: vidSrc.path) {
        do {
            let out = try await VideoConverter().convert(input: vidSrc, to: .mp4, outputDir:
desktop)
            print("✅ Video MOV→MP4:", out.path)
        } catch { print("❌ Video:", error) }
    }

    // ── Archive (ZIP) ─────────────────────────────────────────────────────────
    do {
        let zipOut = try await ArchiveConverter().compress(inputs: [txtSrc], to: .zip, outputDir:
desktop)
        print("✅ Archive ZIP create:", zipOut.path)
        let unzipOut = try await ArchiveConverter().decompress(input: zipOut, outputDir: desktop)
        print("✅ Archive ZIP extract:", unzipOut.path)
    } catch { print("❌ Archive:", error) }

    print("\n📁 Outputs in:", desktop.path)
}
//
//  tester.swift
//  UtilityNotch
//
//  Created by Benjamín Baranovič on 23.04.2026.
//

