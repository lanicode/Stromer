import AVFoundation
import SwiftUI
import UIKit

final class PipDisplayLayerHostingView: UIView {
    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer? {
        layer as? AVSampleBufferDisplayLayer
    }
}

struct PipDisplayLayerView: UIViewRepresentable {
    let onLayerReady: (AVSampleBufferDisplayLayer) -> Void

    func makeUIView(context: Context) -> PipDisplayLayerHostingView {
        let view = PipDisplayLayerHostingView(frame: .zero)
        if let displayLayer = view.sampleBufferDisplayLayer {
            displayLayer.videoGravity = .resizeAspect
            onLayerReady(displayLayer)
        }
        return view
    }

    func updateUIView(_ uiView: PipDisplayLayerHostingView, context: Context) {
    }
}
