import SwiftUI
import AVFoundation
import CoreMotion

struct CameraWrapperView: UIViewRepresentable {
    let geometrySize: CGSize
    @EnvironmentObject var cameraWrapperVM: CameraWrapperViewModel

    private let baseView: UIView = UIView()
    private let previewAreaView: UIView = UIView()
    private let focusIndicator: UIView = UIView()
    private let coreMotionManager: CMMotionManager = CMMotionManager()

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
            + "\npreviewLayerView.frame:\t\(previewAreaView.frame)"
            + "\npreviewLayerView.bounds:\t\(previewAreaView.bounds)"
            + "\nuiView.frame:\t\(uiView.frame)"
            + "\nuiView.bounds:\t\(uiView.bounds)"
            + "\ncameraVM.captureResolution:\t\(cameraWrapperVM.captureResolution)"
            , level: .dbg)
    }
}

// MARK: init stuff
extension CameraWrapperView {
    private func setupBaseView() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            baseView.backgroundColor = .purple
            baseView.addSubview(previewAreaView)
            previewAreaView.frame = cameraWrapperVM.calcLayerFrame(baseViewSize: baseView.frame.size)
            previewAreaView.backgroundColor = .green
            return
        }
        deinitProc()
        cameraWrapperVM.cameraWrapperViewDelegate = self

        setupPreviewLayer()
        previewAreaView.addGestureRecognizer(UITapGestureRecognizer(target: cameraWrapperVM, action: #selector(CameraWrapperViewModel.tapGesture(_:))))
        previewAreaView.addGestureRecognizer(UIPinchGestureRecognizer(target: cameraWrapperVM, action: #selector(CameraWrapperViewModel.pinchGesture(_:))))
        baseView.backgroundColor = .gray
        previewAreaView.backgroundColor = .white

        setupFocusIndicator()
        startMotionAutoFocus()
    }

    private func setupPreviewLayer() {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
        previewAreaView.frame = baseView.frame
        baseView.addSubview(previewAreaView)
        let newPreviewLayer = AVCaptureVideoPreviewLayer(session: cameraWrapperVM.captureSession)
        newPreviewLayer.videoGravity = .resizeAspect
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\n\tbaseView.frame:\t\(baseView.frame)"
            + "\n\tbaseView.bounds:\t\(baseView.bounds)"
            + "\n\tpreviewLayerView.frame:\t\(previewAreaView.frame)"
            + "\n\tpreviewLayerView.bounds:\t\(previewAreaView.bounds)"
            + "\n\tnewPreviewLayer.frame:\t\(newPreviewLayer.frame)"
            + "\n\tnewPreviewLayer.bounds:\t\(newPreviewLayer.bounds)"
            , level: .dbg)
        if let previewLayer = cameraWrapperVM.previewLayer {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            previewAreaView.layer.replaceSublayer(previewLayer, with: newPreviewLayer)
            // todo: フリップアニメーション ref: https://superhahnah.com/swift-camera-position-switching/
        } else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            previewAreaView.layer.insertSublayer(newPreviewLayer, at: 0)
        }
        cameraWrapperVM.previewLayer = newPreviewLayer
        cameraWrapperVM.applyOrientationToAVCaptureVideoOrientation()
        resetPreviewLayerFrame()
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\n\tbaseView.frame:\t\(baseView.frame)"
            + "\n\tbaseView.bounds:\t\(baseView.bounds)"
            + "\n\tpreviewLayerView.frame:\t\(previewAreaView.frame)"
            + "\n\tpreviewLayerView.bounds:\t\(previewAreaView.bounds)"
            + "\n\tnewPreviewLayer.frame:\t\(newPreviewLayer.frame)"
            + "\n\tnewPreviewLayer.bounds:\t\(newPreviewLayer.bounds)"
            , level: .dbg)
    }

    private func setupFocusIndicator() {
        focusIndicator.frame = CGRect(x: 0, y: 0, width: previewAreaView.bounds.width * 0.3, height: previewAreaView.bounds.width * 0.3)
        focusIndicator.layer.borderWidth = 1
        focusIndicator.layer.borderColor = UIColor.systemYellow.cgColor
        focusIndicator.isHidden = true
        previewAreaView.addSubview(focusIndicator)
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
            adjustAutoFocus(focusPoint: previewAreaView.center, focusMode: .continuousAutoFocus, exposeMode: .continuousAutoExposure)
        }
    }
}

// MARK: CameraViewDeinitDelegate stuff
extension CameraWrapperView: CameraWrapperViewDelegate {
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
            focusIndicator.frame = CGRect(
                x: focusPoint.x - (previewAreaView.bounds.width * 0.075),
                y: focusPoint.y - (previewAreaView.bounds.width * 0.075),
                width: (previewAreaView.bounds.width * 0.15),
                height: (previewAreaView.bounds.width * 0.15)
            )
        } completion: { (UIViewAnimatingPosition) in
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
                focusIndicator.isHidden = true
                focusIndicator.frame.size = CGSize(
                    width: previewAreaView.bounds.width * 0.3,
                    height: previewAreaView.bounds.width * 0.3
                )
            }
        }

        guard let currentCamera = cameraWrapperVM.currentCamera else {
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

        guard let previewLayer = cameraWrapperVM.previewLayer else {
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
        guard let previewLayer = cameraWrapperVM.previewLayer else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\npreviewLayer is nil"
                , level: .err)
            return
        }
        let layerFrame = cameraWrapperVM.calcLayerFrame(baseViewSize: baseView.frame.size)
        previewAreaView.frame = layerFrame
        previewLayer.frame = CGRect(origin: .zero, size: layerFrame.size)
    }
}
