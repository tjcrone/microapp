import AVFoundation
import SwiftUI

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    let zoomLevel: CGFloat

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        nsView.previewLayer.transform = CATransform3DMakeScale(zoomLevel, zoomLevel, 1)
        CATransaction.commit()
    }
}

final class CameraPreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(previewLayer)
        previewLayer.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
