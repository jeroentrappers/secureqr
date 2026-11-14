import AVFoundation
import SwiftUI
import UIKit

/// Live camera picture, filling its bounds.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// `CameraController.runGeneration`: a new value reconnects the layer.
    var generation = 0

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var generation = 0
    }

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        context.coordinator.generation = generation
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        } else if context.coordinator.generation != generation {
            // Detach and attach again so the layer takes the new run's frames.
            uiView.previewLayer.session = nil
            uiView.previewLayer.session = session
        }
        context.coordinator.generation = generation
    }
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // Safe: `layerClass` above guarantees the type.
        return layer as! AVCaptureVideoPreviewLayer
    }
}
