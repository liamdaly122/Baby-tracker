import ImageIO
import MissionUI
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers

/// The app icon is drawn from `AppIconArt`, so it always matches the home screen's rocket. This
/// writes the phone's and the watch's icon pictures when recording
/// (`TEST_RUNNER_RECORD_SNAPSHOTS=1`), and otherwise checks they still match the art. Apple turns
/// down icons with any transparency, so they're drawn opaque.
@MainActor
@Suite("App icon")
struct AppIconTests {
    private static let root = Snapshot.directory.deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    private static let icons = [
        "Apps/MissionControl/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
        "Apps/MissionControlWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    ]

    @Test("The phone and watch icons are the art, 1024 points square, with no transparency")
    func icons() throws {
        let image = try #require(Self.opaqueIcon())
        let png = try #require(Self.pngWithoutAlpha(image))
        for path in Self.icons {
            let file = Self.root.appending(path: path)
            if Snapshot.isRecording {
                try png.write(to: file)
                continue
            }
            let saved = try #require(UIImage(contentsOfFile: file.path), "No icon at \(path)")
            let cgImage = try #require(saved.cgImage)
            #expect(cgImage.width == 1024 && cgImage.height == 1024)
            #expect(
                [.none, .noneSkipFirst, .noneSkipLast].contains(cgImage.alphaInfo), "\(path) has transparency")
            #expect(Snapshot.difference(image, saved) == nil, "\(path) no longer matches AppIconArt")
        }
    }

    /// A PNG with no alpha channel at all. `pngData()` keeps one even for an opaque picture.
    private static func pngWithoutAlpha(_ image: UIImage) -> Data? {
        guard let source = image.cgImage,
            let context = CGContext(
                data: nil, width: source.width, height: source.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        guard let flat = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, flat, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// The art at 1024 × 1024, flattened onto an opaque canvas.
    private static func opaqueIcon() -> UIImage? {
        MissionType.registerFonts()
        let renderer = ImageRenderer(content: AppIconArt().frame(width: 1024, height: 1024))
        renderer.scale = 1
        guard let drawn = Snapshot.draw(renderer) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024), format: format).image { _ in
            drawn.draw(at: .zero)
        }
    }
}
