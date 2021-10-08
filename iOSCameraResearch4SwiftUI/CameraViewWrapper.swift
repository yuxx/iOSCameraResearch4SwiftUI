import SwiftUI
import AVFoundation
import CoreMotion

struct CameraViewWrapper: UIViewRepresentable {
    let geometrySize: CGSize
    @EnvironmentObject var shootingVM: ShootingViewModel

    private let baseView: UIView = UIView()

    func makeUIView(context: Context) -> UIViewType {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
        baseView.frame = CGRect(origin: .zero, size: geometrySize)
        setupPreviewLayer()
//        if let previewLayer = shootingVM.previewLayer {
//            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
//            baseView.layer.addSublayer(previewLayer)
//        }
        baseView.addGestureRecognizer(UITapGestureRecognizer(target: shootingVM, action: #selector(ShootingViewModel.tapGesture(_:))))
        baseView.addGestureRecognizer(UIPinchGestureRecognizer(target: shootingVM, action: #selector(ShootingViewModel.pinchGesture(_:))))
        baseView.backgroundColor = .gray
        return baseView
    }

    typealias UIViewType = UIView

    func updateUIView(_ uiView: UIViewType, context: Context) {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\nbaseView.frame:\t\(baseView.frame)"
            + "\nbaseView.bounds:\t\(baseView.bounds)"
            + "\nuiView.frame:\t\(uiView.frame)"
            + "\nuiView.bounds:\t\(uiView.bounds)"
            , level: .dbg)
    }
}

extension CameraViewWrapper {
    private func setupPreviewLayer() {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
        let newPreviewLayer = AVCaptureVideoPreviewLayer(session: shootingVM.captureSession)
        newPreviewLayer.videoGravity = .resizeAspect
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\nbaseView.frame:\t\(baseView.frame)"
            + "\nbaseView.bounds:\t\(baseView.bounds)"
            + "\nnewPreviewLayer.frame:\t\(newPreviewLayer.frame)"
            + "\nnewPreviewLayer.bounds:\t\(newPreviewLayer.bounds)"
            , level: .dbg)
        newPreviewLayer.frame = baseView.frame
        if let previewLayer = shootingVM.previewLayer {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            baseView.layer.replaceSublayer(previewLayer, with: newPreviewLayer)
            // todo: フリップアニメーション ref: https://superhahnah.com/swift-camera-position-switching/
        } else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            baseView.layer.insertSublayer(newPreviewLayer, at: 0)
        }
        shootingVM.previewLayer = newPreviewLayer
        shootingVM.adjustOrientationForAVCaptureVideoOrientation()
    }
}
