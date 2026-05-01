import CoreGraphics
import Foundation
import ImageIO

private enum AppIconGenerator {
    static let masterSize = 1024
    static let outputSizes = [
        20,
        29,
        40,
        58,
        60,
        76,
        80,
        87,
        120,
        152,
        167,
        180,
        1024
    ]

    static func run(arguments: [String]) throws {
        let outputDirectory = URL(fileURLWithPath: arguments.dropFirst().first ?? defaultOutputPath)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let masterImage = try AppIconRenderer().render(size: masterSize)

        for size in outputSizes {
            let image = size == masterSize
                ? masterImage
                : try downscaledImage(masterImage, size: size)
            try writePNG(
                image,
                to: outputDirectory.appendingPathComponent("Stromer-AppIcon-\(size).png")
            )
        }

        try contentsJSON.write(
            to: outputDirectory.appendingPathComponent("Contents.json"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static var defaultOutputPath: String {
        "Stromer/Assets.xcassets/AppIcon.appiconset"
    }

    private static func downscaledImage(_ image: CGImage, size: Int) throws -> CGImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw GeneratorError.contextCreationFailed(size)
        }

        // CoreGraphics' high-quality interpolation keeps the generated small
        // PNGs tied to the 1024px master while preserving clean geometric edges.
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

        guard let scaledImage = context.makeImage() else {
            throw GeneratorError.imageCreationFailed(size)
        }
        return scaledImage
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw GeneratorError.pngDestinationFailed(url.path)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw GeneratorError.pngWriteFailed(url.path)
        }
    }

    private static var contentsJSON: String {
        """
        {
          "images" : [
            {
              "filename" : "Stromer-AppIcon-40.png",
              "idiom" : "iphone",
              "scale" : "2x",
              "size" : "20x20"
            },
            {
              "filename" : "Stromer-AppIcon-60.png",
              "idiom" : "iphone",
              "scale" : "3x",
              "size" : "20x20"
            },
            {
              "filename" : "Stromer-AppIcon-58.png",
              "idiom" : "iphone",
              "scale" : "2x",
              "size" : "29x29"
            },
            {
              "filename" : "Stromer-AppIcon-87.png",
              "idiom" : "iphone",
              "scale" : "3x",
              "size" : "29x29"
            },
            {
              "filename" : "Stromer-AppIcon-80.png",
              "idiom" : "iphone",
              "scale" : "2x",
              "size" : "40x40"
            },
            {
              "filename" : "Stromer-AppIcon-120.png",
              "idiom" : "iphone",
              "scale" : "3x",
              "size" : "40x40"
            },
            {
              "filename" : "Stromer-AppIcon-120.png",
              "idiom" : "iphone",
              "scale" : "2x",
              "size" : "60x60"
            },
            {
              "filename" : "Stromer-AppIcon-180.png",
              "idiom" : "iphone",
              "scale" : "3x",
              "size" : "60x60"
            },
            {
              "filename" : "Stromer-AppIcon-20.png",
              "idiom" : "ipad",
              "scale" : "1x",
              "size" : "20x20"
            },
            {
              "filename" : "Stromer-AppIcon-40.png",
              "idiom" : "ipad",
              "scale" : "2x",
              "size" : "20x20"
            },
            {
              "filename" : "Stromer-AppIcon-29.png",
              "idiom" : "ipad",
              "scale" : "1x",
              "size" : "29x29"
            },
            {
              "filename" : "Stromer-AppIcon-58.png",
              "idiom" : "ipad",
              "scale" : "2x",
              "size" : "29x29"
            },
            {
              "filename" : "Stromer-AppIcon-40.png",
              "idiom" : "ipad",
              "scale" : "1x",
              "size" : "40x40"
            },
            {
              "filename" : "Stromer-AppIcon-80.png",
              "idiom" : "ipad",
              "scale" : "2x",
              "size" : "40x40"
            },
            {
              "filename" : "Stromer-AppIcon-76.png",
              "idiom" : "ipad",
              "scale" : "1x",
              "size" : "76x76"
            },
            {
              "filename" : "Stromer-AppIcon-152.png",
              "idiom" : "ipad",
              "scale" : "2x",
              "size" : "76x76"
            },
            {
              "filename" : "Stromer-AppIcon-167.png",
              "idiom" : "ipad",
              "scale" : "2x",
              "size" : "83.5x83.5"
            },
            {
              "filename" : "Stromer-AppIcon-1024.png",
              "idiom" : "ios-marketing",
              "scale" : "1x",
              "size" : "1024x1024"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
        + "\n"
    }
}

private struct AppIconRenderer {
    func render(size: Int) throws -> CGImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw GeneratorError.contextCreationFailed(size)
        }

        let canvas = CGFloat(size)
        context.translateBy(x: 0, y: canvas)
        context.scaleBy(x: 1, y: -1)

        drawBackground(in: context, size: canvas, colorSpace: colorSpace)
        drawSun(in: context, size: canvas)
        drawBattery(in: context, size: canvas)

        guard let image = context.makeImage() else {
            throw GeneratorError.imageCreationFailed(size)
        }
        return image
    }

    private func drawBackground(
        in context: CGContext,
        size: CGFloat,
        colorSpace: CGColorSpace
    ) {
        let colors = [
            CGColor.stromerColor(red: 0x0E, green: 0x6B, blue: 0x64),
            CGColor.stromerColor(red: 0x10, green: 0x2C, blue: 0x3A)
        ] as CFArray
        let locations: [CGFloat] = [0, 1]
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: locations
        )!

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: size / 2, y: 0),
            end: CGPoint(x: size / 2, y: size),
            options: []
        )
    }

    private func drawSun(in context: CGContext, size: CGFloat) {
        let center = CGPoint(x: size * 0.5, y: size * 0.31)
        let radius = size * 0.145
        let rayLength = size * 0.095
        let rayWidth = size * 0.024
        let rayGap = size * 0.037
        let solarColor = CGColor.stromerColor(red: 0xF6, green: 0xC4, blue: 0x45)

        context.setFillColor(solarColor)

        for index in 0..<8 {
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(index) * .pi / 4)

            let rect = CGRect(
                x: -rayWidth / 2,
                y: -(radius + rayGap + rayLength),
                width: rayWidth,
                height: rayLength
            )
            context.addPath(CGPath(
                roundedRect: rect,
                cornerWidth: rayWidth / 2,
                cornerHeight: rayWidth / 2,
                transform: nil
            ))
            context.fillPath()
            context.restoreGState()
        }

        context.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.fillPath()
    }

    private func drawBattery(in context: CGContext, size: CGFloat) {
        let offWhite = CGColor.stromerColor(red: 0xF7, green: 0xF8, blue: 0xF2)
        let chargeGreen = CGColor.stromerColor(red: 0x7B, green: 0xC8, blue: 0x6C)
        let body = CGRect(
            x: size * 0.225,
            y: size * 0.625,
            width: size * 0.55,
            height: size * 0.18
        )
        let cornerRadius = size * 0.042
        let terminal = CGRect(
            x: body.midX - size * 0.065,
            y: body.minY - size * 0.047,
            width: size * 0.13,
            height: size * 0.062
        )

        context.setFillColor(offWhite)
        context.addPath(CGPath(
            roundedRect: terminal,
            cornerWidth: size * 0.022,
            cornerHeight: size * 0.022,
            transform: nil
        ))
        context.fillPath()

        context.setFillColor(offWhite)
        context.addPath(CGPath(
            roundedRect: body,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        ))
        context.fillPath()

        let inset = size * 0.026
        let chargeTrack = body.insetBy(dx: inset, dy: inset)
        let chargeRect = CGRect(
            x: chargeTrack.minX,
            y: chargeTrack.minY,
            width: chargeTrack.width * 0.75,
            height: chargeTrack.height
        )

        context.setFillColor(chargeGreen)
        context.addPath(CGPath(
            roundedRect: chargeRect,
            cornerWidth: size * 0.024,
            cornerHeight: size * 0.024,
            transform: nil
        ))
        context.fillPath()
    }
}

private enum GeneratorError: LocalizedError {
    case contextCreationFailed(Int)
    case imageCreationFailed(Int)
    case pngDestinationFailed(String)
    case pngWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case let .contextCreationFailed(size):
            return "Could not create CGContext for \(size)x\(size)."
        case let .imageCreationFailed(size):
            return "Could not create CGImage for \(size)x\(size)."
        case let .pngDestinationFailed(path):
            return "Could not create PNG destination at \(path)."
        case let .pngWriteFailed(path):
            return "Could not write PNG at \(path)."
        }
    }
}

private extension CGColor {
    static func stromerColor(red: UInt8, green: UInt8, blue: UInt8) -> CGColor {
        CGColor(
            srgbRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}

do {
    try AppIconGenerator.run(arguments: CommandLine.arguments)
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
