import CoreMedia
import CoreVideo
import SwiftUI
import XCTest

@MainActor
final class PipFrameRendererTests: XCTestCase {
    func testRenderCreatesBGRAImageBuffer() {
        let renderer = PipFrameRenderer()

        let sampleBuffer = renderer.render(Color.black, size: CGSize(width: 64, height: 64))

        guard let sampleBuffer else {
            XCTFail(renderer.errorMessage ?? "Expected a sample buffer.")
            return
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            XCTFail("Expected an image buffer.")
            return
        }

        XCTAssertEqual(CVPixelBufferGetPixelFormatType(imageBuffer), kCVPixelFormatType_32BGRA)
        XCTAssertEqual(CVPixelBufferGetWidth(imageBuffer), 64)
        XCTAssertEqual(CVPixelBufferGetHeight(imageBuffer), 64)
    }
}
