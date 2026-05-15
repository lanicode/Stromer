import CoreMedia
import CoreVideo
import Observation
import SwiftUI

@MainActor
@Observable
final class PipFrameRenderer {
    private(set) var errorMessage: String?

    @ObservationIgnored private let pixelScale: CGFloat
    @ObservationIgnored private var nextPresentationTime = CMTime.zero
    @ObservationIgnored private let frameDuration = CMTime(value: 1, timescale: 30)

    /// Creates a renderer that keeps the SwiftUI layout size stable while rendering denser pixels for sharper enlarged PiP windows.
    init(pixelScale: CGFloat = 3) {
        self.pixelScale = pixelScale
    }

    func render<V: View>(_ view: V, size: CGSize) -> CMSampleBuffer? {
        errorMessage = nil

        let logicalWidth = max(1, size.width)
        let logicalHeight = max(1, size.height)
        let pixelWidth = max(1, Int((logicalWidth * pixelScale).rounded(.toNearestOrAwayFromZero)))
        let pixelHeight = max(1, Int((logicalHeight * pixelScale).rounded(.toNearestOrAwayFromZero)))
        let framedView = view.frame(width: logicalWidth, height: logicalHeight)
        let renderer = ImageRenderer(content: framedView)
        renderer.scale = pixelScale

        guard let cgImage = renderer.cgImage else {
            errorMessage = "PiP-Frame konnte nicht gerendert werden."
            return nil
        }

        guard let pixelBuffer = makePixelBuffer(width: pixelWidth, height: pixelHeight) else {
            return nil
        }

        guard draw(cgImage, into: pixelBuffer, width: pixelWidth, height: pixelHeight) else {
            return nil
        }

        var formatDescription: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard formatStatus == noErr, let formatDescription else {
            errorMessage = "PiP-Videoformat konnte nicht erstellt werden (\(formatStatus))."
            return nil
        }

        var timing = CMSampleTimingInfo(
            duration: frameDuration,
            presentationTimeStamp: nextPresentationTime,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let bufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard bufferStatus == noErr, let sampleBuffer else {
            errorMessage = "PiP-SampleBuffer konnte nicht erstellt werden (\(bufferStatus))."
            return nil
        }

        nextPresentationTime = CMTimeAdd(nextPresentationTime, frameDuration)
        return sampleBuffer
    }

    private func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attributes: CFDictionary = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            errorMessage = "PiP-PixelBuffer konnte nicht erstellt werden (\(status))."
            return nil
        }
        return pixelBuffer
    }

    private func draw(
        _ cgImage: CGImage,
        into pixelBuffer: CVPixelBuffer,
        width: Int,
        height: Int
    ) -> Bool {
        let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, [])
        guard lockStatus == kCVReturnSuccess else {
            errorMessage = "PiP-PixelBuffer konnte nicht gesperrt werden (\(lockStatus))."
            return false
        }
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            errorMessage = "PiP-PixelBuffer hat keine Basisadresse."
            return false
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            errorMessage = "PiP-Bitmap-Kontext konnte nicht erstellt werden."
            return false
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(rect)
        context.draw(cgImage, in: rect)
        return true
    }
}
