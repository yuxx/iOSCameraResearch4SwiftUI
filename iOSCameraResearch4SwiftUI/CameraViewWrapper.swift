import SwiftUI
import AVFoundation
import CoreMotion

struct CameraViewWrapper: UIViewRepresentable {
    let geometrySize: CGSize
    @EnvironmentObject var shootingVM: ShootingViewModel

    private let baseView: UIView = UIView()
    let focusIndicator: UIView = UIView()
    let coreMotionManager: CMMotionManager = CMMotionManager()

    func makeUIView(context: Context) -> UIViewType {
        baseView.frame = CGRect(origin: .zero, size: geometrySize)

        setupBaseView()

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

// MARK: init stuff
extension CameraViewWrapper {
    private func setupBaseView() {
        shootingVM.cameraViewDeinitDelegate = self

        setupPreviewLayer()
        baseView.addGestureRecognizer(UITapGestureRecognizer(target: shootingVM, action: #selector(ShootingViewModel.tapGesture(_:))))
        baseView.addGestureRecognizer(UIPinchGestureRecognizer(target: shootingVM, action: #selector(ShootingViewModel.pinchGesture(_:))))
        baseView.backgroundColor = .gray

        setupFocusIndicator()
        startMotionAutoFocus()
    }

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

    private func setupFocusIndicator() {
        focusIndicator.frame = CGRect(x: 0, y: 0, width: baseView.bounds.width * 0.3, height: baseView.bounds.width * 0.3)
        focusIndicator.layer.borderWidth = 1
        focusIndicator.layer.borderColor = UIColor.systemYellow.cgColor
        focusIndicator.isHidden = true
        baseView.addSubview(focusIndicator)
    }

    // ref: https://qiita.com/jumperson/items/723737ed497fe2c6f2aa
    private func startMotionAutoFocus() {
        guard coreMotionManager.isAccelerometerAvailable else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nAccelerometer is not available."
                , level: .err)
            return
        }
        coreMotionManager.accelerometerUpdateInterval = 0.1

        guard let queue = OperationQueue.current else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nCurrent operation queue is not available."
                , level: .err)
            return
        }

        coreMotionManager.startAccelerometerUpdates(to: queue) { [self] accelerometerData, error in
            if let error = error {
                debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                    + "\nerror: \(error)"
                    , level: .err)
                return
            }
            guard let acceleration = accelerometerData?.acceleration else {
                debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                    + "\nNo acceleration found."
                    , level: .err)
                return
            }
            let intensity = abs(acceleration.x) + abs(acceleration.y) + abs(acceleration.z)
            guard intensity > 2 else {
                return
            }
            adjustAutoFocus(focusPoint: self.baseView.center, focusMode: .continuousAutoFocus, exposeMode: .continuousAutoExposure)
        }
    }
}

// MARK: CameraViewDeinitDelegate stuff
extension CameraViewWrapper: CameraViewDeinitDelegate {
    func deinitProc() {
        if coreMotionManager.isAccelerometerActive {
            coreMotionManager.stopAccelerometerUpdates()
        }
    }

    // ref: https://qiita.com/jumperson/items/723737ed497fe2c6f2aa
    func adjustAutoFocus(focusPoint: CGPoint, focusMode: AVCaptureDevice.FocusMode, exposeMode: AVCaptureDevice.ExposureMode) {
        focusIndicator.center = focusPoint
        focusIndicator.isHidden = false
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.5, delay: 0, options: []) {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            self.focusIndicator.frame = CGRect(
                x: focusPoint.x - (baseView.bounds.width * 0.075),
                y: focusPoint.y - (baseView.bounds.width * 0.075),
                width: (baseView.bounds.width * 0.15),
                height: (baseView.bounds.width * 0.15)
            )
        } completion: { (UIViewAnimatingPosition) in
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (Timer) in
                debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
                focusIndicator.isHidden = true
                focusIndicator.frame.size = CGSize(
                    width: baseView.bounds.width * 0.3,
                    height:baseView.bounds.width * 0.3
                )
            }
        }

        guard let currentCamera = shootingVM.currentCamera else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nNo active camera found."
                , level: .err)
            return
        }
        do {
            try currentCamera.lockForConfiguration()
        } catch {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nfailed to lock for configuration for current camera."
                , level: .err)
            return
        }
        defer {
            currentCamera.unlockForConfiguration()
        }

        guard let previewLayer = shootingVM.previewLayer else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\npreview layer is nil."
                , level: .err)
            return
        }
        let focusPoint4CaptureDevice = previewLayer.captureDevicePointConverted(fromLayerPoint: focusPoint)

        // NOTE: フォーカス調整
        if currentCamera.isFocusPointOfInterestSupported && currentCamera.isFocusModeSupported(focusMode) {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            currentCamera.focusMode = focusMode
            currentCamera.focusPointOfInterest = focusPoint4CaptureDevice
        }

        // NOTE: 露光調整
        if currentCamera.isExposurePointOfInterestSupported && currentCamera.isExposureModeSupported(exposeMode) {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            currentCamera.exposureMode = exposeMode
            currentCamera.exposurePointOfInterest = focusPoint4CaptureDevice
        }
    }

    func resetPreviewLayerFrame() {
        guard let previewLayer = shootingVM.previewLayer else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\npreviewLayer is nil"
                , level: .err)
            return
        }
        previewLayer.frame = baseView.frame
    }
}
