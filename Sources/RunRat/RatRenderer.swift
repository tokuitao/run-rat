import AppKit
import os

enum RatRenderer {
    private static let targetHeight = max(NSStatusBar.system.thickness - 1, 21)

    private static let frames: [NSImage] = {
        var loadedFrames: [NSImage] = []
        let manifestCount = frameCountFromManifest()

        if let manifestCount {
            for index in 0 ..< manifestCount {
                guard let image = loadFrame(index: index) else {
                    continue
                }
                image.isTemplate = true
                loadedFrames.append(image)
            }
        } else {
            for url in frameURLs() {
                guard let image = NSImage(contentsOf: url) else {
                    continue
                }
                image.isTemplate = true
                loadedFrames.append(image)
            }
        }

        return loadedFrames.isEmpty ? [fallbackFrame()] : loadedFrames
    }()

    static let frameCount = frames.count

    static let cachedImages: [NSImage] = {
        return (0..<frameCount).map { makeImage(frameIndex: $0) }
    }()

    static func cachedImage(frameIndex: Int) -> NSImage {
        cachedImages[frameIndex % cachedImages.count]
    }

    private static let widestAspectRatio: CGFloat = {
        frames.map { $0.size.width / max($0.size.height, 1) }.max() ?? 3.6
    }()

    static let canvasSize = NSSize(
        width: ceil(CGFloat(targetHeight) * widestAspectRatio) + 6,
        height: targetHeight
    )

    static func makeImage(frameIndex: Int) -> NSImage {
        let source = frames[frameIndex % frames.count]
        let image = NSImage(size: canvasSize)

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: fittedRect(for: source.size, in: canvasSize),
            from: NSRect(origin: .zero, size: source.size),
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()

        image.isTemplate = true
        return image
    }

    private static func frameCountFromManifest() -> Int? {
        let manifestURLs = [
            Bundle.module.url(forResource: "rat_frame_manifest", withExtension: "txt"),
            Bundle.module.url(forResource: "rat_frame_manifest", withExtension: "txt", subdirectory: "Frames"),
        ].compactMap { $0 }

        for manifestURL in manifestURLs {
            guard let text = try? String(contentsOf: manifestURL, encoding: .utf8) else {
                continue
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let count = Int(trimmed), count > 0 {
                return count
            }
        }
        return nil
    }

    private static func loadFrame(index: Int) -> NSImage? {
        let frameURLs = [
            Bundle.module.url(forResource: "rat_frame_\(index)", withExtension: "png"),
            Bundle.module.url(forResource: "rat_frame_\(index)", withExtension: "png", subdirectory: "Frames"),
        ].compactMap { $0 }

        for frameURL in frameURLs {
            if let image = NSImage(contentsOf: frameURL) {
                return image
            }
        }

        os_log("RunRat: Failed to load frame %d", log: .default, type: .debug, index)
        return nil
    }

    private static func frameURLs() -> [URL] {
        let rootURLs = Bundle.module.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        let frameURLs = rootURLs
            .filter { isOutputFrameName($0.lastPathComponent) }
            .sorted {
                frameNumber(for: $0) < frameNumber(for: $1)
            }

        if !frameURLs.isEmpty {
            return frameURLs
        }

        let nestedURLs = Bundle.module.urls(forResourcesWithExtension: "png", subdirectory: "Frames") ?? []
        return nestedURLs
            .filter { isOutputFrameName($0.lastPathComponent) }
            .sorted {
                frameNumber(for: $0) < frameNumber(for: $1)
            }
    }

    private static func isOutputFrameName(_ name: String) -> Bool {
        name.hasPrefix("rat_frame_") && name.hasSuffix(".png") && frameNumber(in: name) != nil
    }

    private static func frameNumber(for url: URL) -> Int {
        frameNumber(in: url.lastPathComponent) ?? 0
    }

    private static func frameNumber(in name: String) -> Int? {
        let digits = name.filter(\.isNumber)
        return digits.isEmpty ? nil : Int(digits)
    }

    private static func fittedRect(for contentSize: NSSize, in canvas: NSSize) -> NSRect {
        let availableRect = NSRect(x: 2, y: 0, width: canvas.width - 4, height: canvas.height)
        let scale = min(availableRect.width / contentSize.width, availableRect.height / contentSize.height)
        let destinationSize = NSSize(width: contentSize.width * scale, height: contentSize.height * scale)

        return NSRect(
            x: round((canvas.width - destinationSize.width) / 2),
            y: round((canvas.height - destinationSize.height) / 2),
            width: round(destinationSize.width),
            height: round(destinationSize.height)
        )
    }

    private static func fallbackFrame() -> NSImage {
        let fallbackSize = NSSize(width: 84, height: targetHeight)
        let image = NSImage(size: fallbackSize)
        image.lockFocus()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 14, y: 6, width: 42, height: 10)).fill()

        let tail = NSBezierPath()
        tail.lineWidth = 2
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 18, y: 12))
        tail.curve(
            to: NSPoint(x: 3, y: 13),
            controlPoint1: NSPoint(x: 11, y: 15),
            controlPoint2: NSPoint(x: 6, y: 14)
        )
        tail.stroke()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
