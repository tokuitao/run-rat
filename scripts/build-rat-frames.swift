import AppKit
import Foundation

struct PixelPoint: Hashable {
    let x: Int
    let y: Int
}

struct PixelBounds {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    init() {
        minX = .max
        minY = .max
        maxX = .min
        maxY = .min
    }

    var isValid: Bool {
        minX <= maxX && minY <= maxY
    }
}

struct PreparedFrame {
    let image: NSImage
    let bounds: PixelBounds
}

enum BuildFramesError: Error {
    case usage
    case emptyFrameDirectory
    case invalidInput
    case loadFailed
    case cellExtractionFailed
    case frameEncodingFailed
    case previewEncodingFailed
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    throw BuildFramesError.usage
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputDirectoryURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
let previewURL = URL(fileURLWithPath: arguments[3])
let fileManager = FileManager.default
let manifestURL = outputDirectoryURL.deletingLastPathComponent().appendingPathComponent("rat_frame_manifest.txt")

func numericFrameIndex(from name: String) -> Int? {
    let digits = name.filter(\.isNumber)
    return digits.isEmpty ? nil : Int(digits)
}

func isOutputFrameName(_ name: String) -> Bool {
    name.hasPrefix("rat_frame_") && name.hasSuffix(".png") && numericFrameIndex(from: name) != nil
}

func isUniformSourceFrameName(_ name: String) -> Bool {
    name.hasSuffix("_uniform.png") && numericFrameIndex(from: name) != nil
}

func isPlainSourceFrameName(_ name: String) -> Bool {
    name.hasSuffix(".png") && !name.contains("_uniform") && numericFrameIndex(from: name) != nil
}

func clearOutputFrames() throws {
    try fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

    let existingFiles = try fileManager.contentsOfDirectory(
        at: outputDirectoryURL,
        includingPropertiesForKeys: nil
    )

    for fileURL in existingFiles where isOutputFrameName(fileURL.lastPathComponent) {
        try fileManager.removeItem(at: fileURL)
    }
}

func copyFile(from sourceURL: URL, to destinationURL: URL) throws {
    if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
    }
    try fileManager.copyItem(at: sourceURL, to: destinationURL)
}

func writeManifest(frameCount: Int) throws {
    try "\(frameCount)\n".write(to: manifestURL, atomically: true, encoding: .utf8)
}

func frameURLsInOutputDirectory() throws -> [URL] {
    try fileManager.contentsOfDirectory(
        at: outputDirectoryURL,
        includingPropertiesForKeys: nil
    )
    .filter { isOutputFrameName($0.lastPathComponent) }
    .sorted {
        let left = numericFrameIndex(from: $0.lastPathComponent) ?? 0
        let right = numericFrameIndex(from: $1.lastPathComponent) ?? 0
        return left < right
    }
}

func writePreview(from frameURLs: [URL]) throws {
    guard !frameURLs.isEmpty else {
        throw BuildFramesError.emptyFrameDirectory
    }

    let images = frameURLs.compactMap(NSImage.init(contentsOf:))
    guard !images.isEmpty else {
        throw BuildFramesError.previewEncodingFailed
    }

    let targetHeight = Int(max(NSStatusBar.system.thickness - 1, 21))
    let columns = min(4, images.count)
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    let widestAspectRatio = images.map { $0.size.width / max($0.size.height, 1) }.max() ?? 2
    let targetWidth = Int(ceil(CGFloat(targetHeight) * widestAspectRatio))
    let spacing = 8
    let previewWidth = columns * targetWidth + (columns - 1) * spacing
    let previewHeight = rows * targetHeight + (rows - 1) * spacing

    let previewSize = NSSize(
        width: CGFloat(previewWidth),
        height: CGFloat(previewHeight)
    )

    let preview = NSImage(size: previewSize)
    preview.lockFocus()
    NSColor(calibratedRed: 0.84, green: 0.92, blue: 0.99, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: previewSize)).fill()

    for (index, image) in images.enumerated() {
        let column = index % columns
        let row = rows - 1 - (index / columns)
        let destinationRect = NSRect(
            x: CGFloat(column * (targetWidth + spacing)),
            y: CGFloat(row * (targetHeight + spacing)),
            width: CGFloat(targetWidth),
            height: CGFloat(targetHeight)
        )

        image.draw(
            in: destinationRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1
        )
    }

    preview.unlockFocus()

    guard let tiffData = preview.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData),
          let pngData = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
        throw BuildFramesError.previewEncodingFailed
    }

    try fileManager.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try pngData.write(to: previewURL)
}

func importFrameDirectory(from sourceDirectoryURL: URL) throws {
    let files = try fileManager.contentsOfDirectory(
        at: sourceDirectoryURL,
        includingPropertiesForKeys: nil
    )

    let uniformFrames = files
        .filter { isUniformSourceFrameName($0.lastPathComponent) }
        .sorted {
            let left = numericFrameIndex(from: $0.lastPathComponent) ?? 0
            let right = numericFrameIndex(from: $1.lastPathComponent) ?? 0
            return left < right
        }

    let plainFrames = files
        .filter { isPlainSourceFrameName($0.lastPathComponent) }
        .sorted {
            let left = numericFrameIndex(from: $0.lastPathComponent) ?? 0
            let right = numericFrameIndex(from: $1.lastPathComponent) ?? 0
            return left < right
        }

    let sourceFrames = uniformFrames.isEmpty ? plainFrames : uniformFrames
    guard !sourceFrames.isEmpty else {
        throw BuildFramesError.emptyFrameDirectory
    }

    try clearOutputFrames()

    for (index, sourceFrameURL) in sourceFrames.enumerated() {
        let destinationURL = outputDirectoryURL.appendingPathComponent("rat_frame_\(index).png")
        try copyFile(from: sourceFrameURL, to: destinationURL)
    }

    let frameURLs = try frameURLsInOutputDirectory()
    try writeManifest(frameCount: frameURLs.count)
    try writePreview(from: frameURLs)
}

func brightness(_ data: UnsafeMutablePointer<UInt8>, index: Int) -> Int {
    max(Int(data[index]), max(Int(data[index + 1]), Int(data[index + 2])))
}

func neighbors(of point: PixelPoint, width: Int, height: Int) -> [PixelPoint] {
    var output: [PixelPoint] = []
    output.reserveCapacity(8)

    for deltaY in -1 ... 1 {
        for deltaX in -1 ... 1 {
            if deltaX == 0 && deltaY == 0 {
                continue
            }

            let nextX = point.x + deltaX
            let nextY = point.y + deltaY
            guard nextX >= 0, nextY >= 0, nextX < width, nextY < height else {
                continue
            }
            output.append(PixelPoint(x: nextX, y: nextY))
        }
    }

    return output
}

func index(of point: PixelPoint, width: Int) -> Int {
    point.y * width + point.x
}

func largestConnectedComponent(in mask: [Bool], width: Int, height: Int) -> Set<PixelPoint> {
    var visited = Array(repeating: false, count: mask.count)
    var largest: Set<PixelPoint> = []

    for y in 0 ..< height {
        for x in 0 ..< width {
            let start = PixelPoint(x: x, y: y)
            let startIndex = index(of: start, width: width)
            if visited[startIndex] || !mask[startIndex] {
                continue
            }

            var queue = [start]
            var component: Set<PixelPoint> = [start]
            visited[startIndex] = true
            var cursor = 0

            while cursor < queue.count {
                let current = queue[cursor]
                cursor += 1

                for next in neighbors(of: current, width: width, height: height) {
                    let nextIndex = index(of: next, width: width)
                    if visited[nextIndex] || !mask[nextIndex] {
                        continue
                    }
                    visited[nextIndex] = true
                    component.insert(next)
                    queue.append(next)
                }
            }

            if component.count > largest.count {
                largest = component
            }
        }
    }

    return largest
}

func grow(_ component: Set<PixelPoint>, into mask: [Bool], width: Int, height: Int) -> Set<PixelPoint> {
    var selected = component
    var queue = Array(component)
    var cursor = 0

    while cursor < queue.count {
        let current = queue[cursor]
        cursor += 1

        for next in neighbors(of: current, width: width, height: height) {
            let nextIndex = index(of: next, width: width)
            if selected.contains(next) || !mask[nextIndex] {
                continue
            }
            selected.insert(next)
            queue.append(next)
        }
    }

    return selected
}

func fillHoles(in selected: Set<PixelPoint>, width: Int, height: Int) -> Set<PixelPoint> {
    var exterior: Set<PixelPoint> = []
    var queue: [PixelPoint] = []

    for x in 0 ..< width {
        queue.append(PixelPoint(x: x, y: 0))
        queue.append(PixelPoint(x: x, y: height - 1))
    }

    for y in 1 ..< height - 1 {
        queue.append(PixelPoint(x: 0, y: y))
        queue.append(PixelPoint(x: width - 1, y: y))
    }

    var cursor = 0
    while cursor < queue.count {
        let current = queue[cursor]
        cursor += 1

        if exterior.contains(current) || selected.contains(current) {
            continue
        }
        exterior.insert(current)

        for next in neighbors(of: current, width: width, height: height) {
            if !exterior.contains(next) && !selected.contains(next) {
                queue.append(next)
            }
        }
    }

    var filled = selected
    for y in 0 ..< height {
        for x in 0 ..< width {
            let point = PixelPoint(x: x, y: y)
            if !selected.contains(point) && !exterior.contains(point) {
                filled.insert(point)
            }
        }
    }
    return filled
}

func bounds(of selected: Set<PixelPoint>) -> PixelBounds {
    var bounds = PixelBounds()
    for point in selected {
        bounds.minX = min(bounds.minX, point.x)
        bounds.minY = min(bounds.minY, point.y)
        bounds.maxX = max(bounds.maxX, point.x)
        bounds.maxY = max(bounds.maxY, point.y)
    }
    return bounds
}

func extractFramesFromSheet(sheetURL: URL) throws {
    let columns = 4
    let rows = 6
    let hardThreshold = 165
    let softThreshold = 132
    let padding = 3

    guard let sheet = NSImage(contentsOf: sheetURL) else {
        throw BuildFramesError.loadFailed
    }

    let cellSize = NSSize(
        width: floor(sheet.size.width / CGFloat(columns)),
        height: floor(sheet.size.height / CGFloat(rows))
    )

    func makeCellImage(row: Int, column: Int) -> NSImage? {
        let sourceRect = NSRect(
            x: CGFloat(column) * cellSize.width,
            y: sheet.size.height - CGFloat(row + 1) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )

        let image = NSImage(size: cellSize)
        image.lockFocus()
        sheet.draw(
            in: NSRect(origin: .zero, size: cellSize),
            from: sourceRect,
            operation: .copy,
            fraction: 1
        )
        image.unlockFocus()
        return image
    }

    var preparedFrames: [PreparedFrame] = []
    preparedFrames.reserveCapacity(columns * rows)
    var cellPixelWidth = 0
    var cellPixelHeight = 0

    for row in 0 ..< rows {
        for column in 0 ..< columns {
            guard let cellImage = makeCellImage(row: row, column: column),
                  let tiffData = cellImage.tiffRepresentation,
                  let sourceRep = NSBitmapImageRep(data: tiffData),
                  let sourceData = sourceRep.bitmapData,
                  let outputRep = NSBitmapImageRep(
                      bitmapDataPlanes: nil,
                      pixelsWide: sourceRep.pixelsWide,
                      pixelsHigh: sourceRep.pixelsHigh,
                      bitsPerSample: 8,
                      samplesPerPixel: 4,
                      hasAlpha: true,
                      isPlanar: false,
                      colorSpaceName: .deviceRGB,
                      bytesPerRow: 0,
                      bitsPerPixel: 0
                  ),
                  let outputData = outputRep.bitmapData else {
                throw BuildFramesError.cellExtractionFailed
            }

            let width = sourceRep.pixelsWide
            let height = sourceRep.pixelsHigh
            cellPixelWidth = width
            cellPixelHeight = height
            let pixelCount = width * height

            var hardMask = Array(repeating: false, count: pixelCount)
            var softMask = Array(repeating: false, count: pixelCount)

            for y in 0 ..< height {
                for x in 0 ..< width {
                    let offset = y * sourceRep.bytesPerRow + x * 4
                    let value = brightness(sourceData, index: offset)
                    let maskIndex = y * width + x
                    hardMask[maskIndex] = value >= hardThreshold
                    softMask[maskIndex] = value >= softThreshold
                }
            }

            let component = largestConnectedComponent(in: hardMask, width: width, height: height)
            let grown = grow(component, into: softMask, width: width, height: height)
            let selected = fillHoles(in: grown, width: width, height: height)
            let frameBounds = bounds(of: selected)

            for y in 0 ..< height {
                for x in 0 ..< width {
                    let point = PixelPoint(x: x, y: y)
                    let outputIndex = y * outputRep.bytesPerRow + x * 4
                    outputData[outputIndex] = 0
                    outputData[outputIndex + 1] = 0
                    outputData[outputIndex + 2] = 0
                    outputData[outputIndex + 3] = selected.contains(point) ? 255 : 0
                }
            }

            let frameImage = NSImage(size: cellImage.size)
            frameImage.addRepresentation(outputRep)
            frameImage.isTemplate = true
            preparedFrames.append(PreparedFrame(image: frameImage, bounds: frameBounds))
        }
    }

    var unionBounds = PixelBounds()
    for frame in preparedFrames {
        unionBounds.minX = min(unionBounds.minX, frame.bounds.minX)
        unionBounds.minY = min(unionBounds.minY, frame.bounds.minY)
        unionBounds.maxX = max(unionBounds.maxX, frame.bounds.maxX)
        unionBounds.maxY = max(unionBounds.maxY, frame.bounds.maxY)
    }

    guard unionBounds.isValid else {
        throw BuildFramesError.cellExtractionFailed
    }

    unionBounds.minX = max(0, unionBounds.minX - padding)
    unionBounds.minY = max(0, unionBounds.minY - padding)
    unionBounds.maxX = min(cellPixelWidth - 1, unionBounds.maxX + padding)
    unionBounds.maxY = min(cellPixelHeight - 1, unionBounds.maxY + padding)

    let cropWidth = unionBounds.maxX - unionBounds.minX + 1
    let cropHeight = unionBounds.maxY - unionBounds.minY + 1

    try clearOutputFrames()

    for (index, frame) in preparedFrames.enumerated() {
        let croppedRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: cropWidth,
            pixelsHigh: cropHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let croppedData = croppedRep.bitmapData!

        guard let frameTIFF = frame.image.tiffRepresentation,
              let frameRep = NSBitmapImageRep(data: frameTIFF),
              let frameData = frameRep.bitmapData else {
            throw BuildFramesError.frameEncodingFailed
        }

        for y in 0 ..< cropHeight {
            for x in 0 ..< cropWidth {
                let sourceX = unionBounds.minX + x
                let sourceY = unionBounds.minY + y
                let sourceIndex = sourceY * frameRep.bytesPerRow + sourceX * 4
                let outputIndex = y * croppedRep.bytesPerRow + x * 4
                croppedData[outputIndex] = frameData[sourceIndex]
                croppedData[outputIndex + 1] = frameData[sourceIndex + 1]
                croppedData[outputIndex + 2] = frameData[sourceIndex + 2]
                croppedData[outputIndex + 3] = frameData[sourceIndex + 3]
            }
        }

        guard let pngData = croppedRep.representation(using: .png, properties: [:]) else {
            throw BuildFramesError.frameEncodingFailed
        }

        try pngData.write(to: outputDirectoryURL.appendingPathComponent("rat_frame_\(index).png"))
    }

    let frameURLs = try frameURLsInOutputDirectory()
    try writeManifest(frameCount: frameURLs.count)
    try writePreview(from: frameURLs)
}

var isDirectory: ObjCBool = false
guard fileManager.fileExists(atPath: inputURL.path, isDirectory: &isDirectory) else {
    throw BuildFramesError.invalidInput
}

if isDirectory.boolValue {
    try importFrameDirectory(from: inputURL)
} else {
    try extractFramesFromSheet(sheetURL: inputURL)
}

let generatedFrames = try frameURLsInOutputDirectory()
print("Generated \(generatedFrames.count) frames in \(outputDirectoryURL.path)")
print("Preview: \(previewURL.path)")
