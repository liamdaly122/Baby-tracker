import Foundation
import MissionUI
import SwiftUI
import Testing
import UIKit

/// Picture tests (redesign rule 9): draw a view off screen and compare it with a saved PNG in
/// `__Snapshots__`. To record new pictures after a deliberate change, run the tests with
/// `TEST_RUNNER_RECORD_SNAPSHOTS=1` in front of `xcodebuild test`, check the PNGs, and commit them.
/// The reference pictures are drawn on the iOS 27.0 simulator, the one CI uses. The watch's are drawn
/// on an Apple Watch Ultra 2 (49mm) on watchOS 27.0: watch text sizes depend on the screen size, so
/// they only match on that model.
@MainActor
enum Snapshot {
    static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appending(path: "__Snapshots__", directoryHint: .isDirectory)
    static var isRecording: Bool { ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil }

    /// A colour channel can be this far out (of 255) before a pixel counts as different, and up to
    /// this share of pixels can differ, so tiny anti-aliasing changes don't fail.
    static let channelTolerance = 32
    static let pixelTolerance = 0.01

    /// Draws `view` at a phone's width on the night sky's darkest band, at a text size, in real
    /// labour or practice, in the prototype's fonts.
    static func image(
        _ view: some View, width: CGFloat = 375, size: DynamicTypeSize, mode: MissionModeOption,
        background: Color = LabourTheme.space, colorScheme: ColorScheme = .dark, inset: CGFloat = 16
    ) -> UIImage? {
        MissionType.registerFonts()
        let content =
            view
            .padding(inset)
            .frame(width: width)
            .background(background)
            .environment(\.dynamicTypeSize, size)
            .environment(\.missionMode, mode.value)
            .environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.uiImage
    }

    /// Compares with the saved picture, or saves it when recording.
    static func check(_ image: UIImage?, named name: String, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let image, let png = image.pngData() else {
            Issue.record("Couldn't draw \(name)", sourceLocation: sourceLocation)
            return
        }
        let file = directory.appending(path: "\(name).png")
        if isRecording {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try png.write(to: file)
            } catch {
                Issue.record("Couldn't save \(name): \(error)", sourceLocation: sourceLocation)
            }
            return
        }
        guard let saved = UIImage(contentsOfFile: file.path) else {
            Issue.record(
                "No saved picture for \(name). Record one with TEST_RUNNER_RECORD_SNAPSHOTS=1.",
                sourceLocation: sourceLocation)
            return
        }
        if let problem = difference(image, saved) {
            let actual = FileManager.default.temporaryDirectory.appending(path: "\(name).actual.png")
            try? png.write(to: actual)
            Issue.record("\(name): \(problem). This run's picture: \(actual.path)", sourceLocation: sourceLocation)
        }
    }

    /// Nil if the two pictures match within tolerance, otherwise what's different.
    static func difference(_ first: UIImage, _ second: UIImage) -> String? {
        guard let left = pixels(first), let right = pixels(second) else { return "couldn't read the pixels" }
        guard left.width == right.width, left.height == right.height else {
            return "size \(left.width)×\(left.height), saved \(right.width)×\(right.height)"
        }
        var differing = 0
        for pixel in stride(from: 0, to: left.bytes.count, by: 4) {
            let changed = (0..<4).contains { channel in
                abs(Int(left.bytes[pixel + channel]) - Int(right.bytes[pixel + channel])) > channelTolerance
            }
            if changed {
                differing += 1
            }
        }
        let share = Double(differing) / Double(left.width * left.height)
        return share > pixelTolerance ? "\(Int((share * 100).rounded()))% of pixels differ" : nil
    }

    private struct Pixels {
        var width: Int
        var height: Int
        var bytes: [UInt8]
    }

    private static func pixels(_ image: UIImage) -> Pixels? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? Pixels(width: width, height: height, bytes: bytes) : nil
    }
}

/// Real labour or a practice run, with a short name for file names.
enum MissionModeOption: String, CaseIterable, Sendable {
    case live
    case practice
}

extension MissionModeOption {
    var value: MissionMode { self == .live ? .live : .practice }
}
