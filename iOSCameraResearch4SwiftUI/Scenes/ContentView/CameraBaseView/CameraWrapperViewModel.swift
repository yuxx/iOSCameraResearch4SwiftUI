import Combine
import AVFoundation
import UIKit
import CoreMotion
import SwiftUI

protocol CameraWrapperViewDelegate {
    func deinitProc() -> Void
    func adjustAutoFocus(focusPoint: CGPoint, focusMode: AVCaptureDevice.FocusMode, exposeMode: AVCaptureDevice.ExposureMode)
    func resetPreviewLayerFrame()
}

final class CameraWrapperViewModel: NSObject, ObservableObject {
    @Published var isShooting: Bool = false {
        didSet {
            if !isShooting {
                debuglog("\(String(describing: Self.self))::\(#function)@line\(#line)", level: .dbg)
                previewLayer = nil
                NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
            }
        }
    }
    private var defaultCameraSide: CameraSide
    private var currentCameraSide: CameraSide
    private var frontCameraMode: FrontCameraMode?
    private var backCameraMode: BackCameraMode?
    private(set) var captureSession: AVCaptureSession = AVCaptureSession()

    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    private(set) var currentCamera: AVCaptureDevice?

    var previewLayer: AVCaptureVideoPreviewLayer?

    private var photoOut: AVCapturePhotoOutput?

    private var exZoomFactor: CGFloat = 1.0

    var currentOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard let connection = previewLayer?.connection else {
                return
            }
            connection.videoOrientation = currentOrientation
        }
    }

    var cameraWrapperViewDelegate: CameraWrapperViewDelegate?

    init(defaultCameraSide: CameraSide, frontCameraMode: FrontCameraMode?, backCameraMode: BackCameraMode?) {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\ndefaultCameraSide: \(defaultCameraSide)"
            + "\nfrontCameraMode: \(frontCameraMode)"
            + "\nbackCameraMode: \(backCameraMode)"
            , level: .dbg)
        self.defaultCameraSide = defaultCameraSide
        currentCameraSide = defaultCameraSide
        self.frontCameraMode = frontCameraMode
        self.backCameraMode = backCameraMode

        super.init()

        switch defaultCameraSide {
        case .front:
            guard frontCameraMode != nil else {
                debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .err)
                return
            }
        case .back:
            guard backCameraMode != nil else {
                debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .err)
                return
            }
        }

        captureSession.sessionPreset = .photo

        setupAVCaptureDevice()
        setupCameraIO()

        // NOTE: 回転時の通知を設定して videoOrientation を変更
        NotificationCenter.default.addObserver(self, selector: #selector(onOrientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    @objc private func onOrientationChanged() {
        let orientation = UIDevice.current.orientation
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\norientation: \(orientation)"
            , level: .dbg)
        guard orientation == .portrait || orientation == .landscapeLeft || orientation == .landscapeRight else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nupside down is not supported."
                + "\norientation: \(orientation)"
                , level: .dbg)
            return
        }
        applyOrientationToAVCaptureVideoOrientation()

        if let cameraViewDeinitDelegate = cameraWrapperViewDelegate {
            cameraViewDeinitDelegate.resetPreviewLayerFrame()
        }
    }

    deinit {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
        if let cameraViewDeinitDelegate = cameraWrapperViewDelegate {
            cameraViewDeinitDelegate.deinitProc()
        }
    }
}

// MARK: init stuff
extension CameraWrapperViewModel {
    private func setupAVCaptureDevice() {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\nAVCaptureDevice.DeviceType"
            + "\n.builtInTripleCamera   : \(AVCaptureDevice.DeviceType.builtInTripleCamera   .rawValue)"
            + "\n.builtInDualCamera     : \(AVCaptureDevice.DeviceType.builtInDualCamera     .rawValue)"
            + "\n.builtInDualWideCamera : \(AVCaptureDevice.DeviceType.builtInDualWideCamera .rawValue)"
            + "\n.builtInWideAngleCamera: \(AVCaptureDevice.DeviceType.builtInWideAngleCamera.rawValue)"
            + "\n.builtInUltraWideCamera: \(AVCaptureDevice.DeviceType.builtInUltraWideCamera.rawValue)"
            + "\n.builtInTrueDepthCamera: \(AVCaptureDevice.DeviceType.builtInTrueDepthCamera.rawValue)"
            + "\n.builtInTelephotoCamera: \(AVCaptureDevice.DeviceType.builtInTelephotoCamera.rawValue)"
            , level: .dbg)
        if let backCameraMode = backCameraMode {
            let backVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: backCameraMode.captureDevices,
                mediaType: .video,
                position: .back
            )
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nbackVideoDeviceDiscoverySession.devices.count: \(backVideoDeviceDiscoverySession.devices.count)"
                + "\n\tbackVideoDeviceDiscoverySession.devices: \(backVideoDeviceDiscoverySession.devices)"
                , level: .dbg)
            if let detectedBackCamera = backVideoDeviceDiscoverySession.devices.first {
                backCamera = detectedBackCamera
            }
        }

        if let frontCameraMode = frontCameraMode {
            let frontVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: frontCameraMode.captureDevices,
                mediaType: .video,
                position: .front
            )
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nfrontVideoDeviceDiscoverySession.devices.count: \(frontVideoDeviceDiscoverySession.devices.count)"
                + "\n\tfrontVideoDeviceDiscoverySession.devices: \(frontVideoDeviceDiscoverySession.devices)"
                , level: .dbg)
            if let detectedFrontCamera = frontVideoDeviceDiscoverySession.devices.first {
                frontCamera = detectedFrontCamera
            }
        }

        if currentCameraSide == .back {
            if backCamera != nil {
                currentCamera = backCamera
            } else {
                guard frontCamera != nil else {
                    debuglog("\(String(describing: Self.self))::\(#function)@\(#line) FATAL", level: .err)
                    isShooting = false
                    return
                }
                defaultCameraSide = .front
                currentCameraSide = .front
                currentCamera = frontCamera
            }
        } else {
            if frontCamera != nil {
                currentCamera = frontCamera
            } else {
                guard backCamera != nil else {
                    debuglog("\(String(describing: Self.self))::\(#function)@\(#line) FATAL", level: .err)
                    isShooting = false
                    return
                }
                defaultCameraSide = .back
                currentCameraSide = .back
                currentCamera = backCamera
            }
        }

        guard let currentCamera = currentCamera else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line) FATAL", level: .err)
            isShooting = false
            return
        }
        exZoomFactor = currentCamera.videoZoomFactor
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\n\tfrontCamera: \(frontCamera)"
            + "\n\tbackCamera: \(backCamera)"
            + "\n\tcurrentCamera: \(currentCamera)"
            + "\n\t\t.videoZoomFactor: \(currentCamera.videoZoomFactor)"
            + "\n\t\t.minAvailableVideoZoomFactor: \(currentCamera.minAvailableVideoZoomFactor)"
            + "\n\t\t.maxAvailableVideoZoomFactor: \(currentCamera.maxAvailableVideoZoomFactor)"
            + "\n\t\t.activeFormat.videoMaxZoomFactor: \(currentCamera.activeFormat.videoMaxZoomFactor)"
            , level: .dbg)
    }

    private func setupCameraIO() {
        guard let currentCamera = currentCamera else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .err)
            return
        }
        do {
            let captureInput = try AVCaptureDeviceInput(device: currentCamera)
            captureSession.addInput(captureInput)
            photoOut = AVCapturePhotoOutput()
            guard let photoOut = photoOut else {
                debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                    + "\nphotoOut is nil"
                    , level: .err)
                return
            }
            photoOut.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])])
            if captureSession.canAddOutput(photoOut) {
                captureSession.addOutput(photoOut)
            }
        } catch {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nerror: \(error)"
                , level: .err)
        }
        captureSession.startRunning()
    }
}

// MARK: shooting stuff
extension CameraWrapperViewModel {
    func shooting() {
        let settings = AVCapturePhotoSettings()
        // NOTE: オートフラッシュ
        settings.flashMode = .auto
        // NOTE: 手ブレ補正 ON(deprecated??)
        settings.isAutoStillImageStabilizationEnabled = true
        settings.photoQualityPrioritization = .speed
        guard let photoOut = photoOut else {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nphotoOut is nil"
                , level: .err)
            return
        }
        photoOut.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraWrapperViewModel: AVCapturePhotoCaptureDelegate {
    /// 撮影直後のコールバック
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)\terror: \(error)", level: .err)
            return
        }
        if let imageData = photo.fileDataRepresentation() {
            guard let uiImage = UIImage(data: imageData) else {
                debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .err)
                return
            }
            // NOTE: 回転を調整
            let orientationAdjustedImage: UIImage
            switch currentOrientation {
            case .landscapeRight:
                orientationAdjustedImage = UIImage(cgImage: uiImage.cgImage!, scale: uiImage.scale, orientation: .up)
            case .landscapeLeft:
                orientationAdjustedImage = UIImage(cgImage: uiImage.cgImage!, scale: uiImage.scale, orientation: .down)
            case .portrait, .portraitUpsideDown: fallthrough
            @unknown default:
                orientationAdjustedImage = uiImage
            }

            // NOTE: フォトライブラリへ保存
            UIImageWriteToSavedPhotosAlbum(orientationAdjustedImage, nil, nil, nil)
        }
    }
}

// MARK: adjust orientation stuff
extension CameraWrapperViewModel {
    func applyOrientationToAVCaptureVideoOrientation() {
        let newOrientation: AVCaptureVideoOrientation = fixedAVCaptureVideoOrientation
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\ncurrentOrientation: \(currentOrientation)"
            + "\nnewOrientation: \(newOrientation)"
            , level: .dbg)
        currentOrientation = newOrientation
    }
    var fixedAVCaptureVideoOrientation: AVCaptureVideoOrientation {
        switch UIDevice.current.statusBarOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            // NOTE: カメラ左右はデバイスの向きと逆
            return .landscapeRight
        case .landscapeRight:
            // NOTE: カメラ左右はデバイスの向きと逆
            return .landscapeLeft
        default:
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)\tcurrentOrientation: \(currentOrientation)", level: .dbg)
            return currentOrientation
        }
    }
    // ref: https://stackoverflow.com/a/35490266/15474670
    var captureResolution: CGSize {
        guard let formatDescription = currentCamera?.activeFormat.formatDescription else {
            return CGSize(width: 0, height: 0)
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let isPortrait = currentOrientation == .portrait || currentOrientation == .portraitUpsideDown
        guard isPortrait else {
            return CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        }
        return CGSize(width: CGFloat(dimensions.height), height: CGFloat(dimensions.width))
    }
}

extension CameraWrapperViewModel {
    func calcLayerFrame(baseViewSize: CGSize) -> CGRect {
        let currentImageDimensions = captureResolution
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\n\tcurrentImageDimensions:\t\(currentImageDimensions)"
            , level: .dbg)
        guard UIDevice.current.statusBarOrientation == .landscapeRight || UIDevice.current.statusBarOrientation == .landscapeLeft else {
            let fixedHeight: CGFloat = baseViewSize.width * currentImageDimensions.height / currentImageDimensions.width
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\n\tportrait (UIDevice.current.fixedOrientation: \(UIDevice.current.statusBarOrientation))"
                + "\n\tCGRect(x: 0, y: \((baseViewSize.height - fixedHeight) / 2), width: \(baseViewSize.width), height: \(fixedHeight)"
                , level: .dbg)
            return CGRect(x: 0, y: (baseViewSize.height - fixedHeight) / 2, width: baseViewSize.width, height: fixedHeight)
        }
        let fixedWidth: CGFloat = baseViewSize.height * currentImageDimensions.width / currentImageDimensions.height
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\n\tlandscape (UIDevice.current.fixedOrientation: \(UIDevice.current.statusBarOrientation))"
            + "\n\tCGRect(x: \((baseViewSize.width - fixedWidth) / 2), y: 0, width: \(fixedWidth), height: \(baseViewSize.height))"
            , level: .dbg)
        return CGRect(x: (baseViewSize.width - fixedWidth) / 2, y: 0, width: fixedWidth, height: baseViewSize.height)
    }
}

// MARK: gesture stuff
extension CameraWrapperViewModel {
    @objc func tapGesture(_ gesture: UITapGestureRecognizer) {
        let tappedPoint = gesture.location(in: gesture.view)
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\ngesture.view?.frame: \(gesture.view?.frame)"
            + "\ntappedPoint: \(tappedPoint)"
            , level: .dbg)
        if let cameraViewDeinitDelegate = cameraWrapperViewDelegate {
            cameraViewDeinitDelegate.adjustAutoFocus(focusPoint: tappedPoint, focusMode: .autoFocus, exposeMode: .autoExpose)
        }
    }

    @objc func pinchGesture(_ gesture: UIPinchGestureRecognizer) {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\ngesture.scale: \(gesture.scale)"
            + "\ngesture.velocity: \(gesture.velocity)"
            , level: .dbg)
        modifyZoomFactor(byScale: gesture.scale, isFix: gesture.state == UIPinchGestureRecognizer.State.ended)
    }

    // ref: https://qiita.com/touyu/items/6fd26a35212e75f98c6b
    private func modifyZoomFactor(byScale pinchScale: CGFloat, isFix: Bool) {
        guard let currentCamera = currentCamera else {
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

        var newZoomFactor: CGFloat = currentCamera.videoZoomFactor
        defer {
            currentCamera.videoZoomFactor = newZoomFactor
            currentCamera.unlockForConfiguration()
        }

        if pinchScale > 1.0 {
            newZoomFactor = exZoomFactor + pinchScale - 1
        } else {
            newZoomFactor = exZoomFactor - (1 - pinchScale) * exZoomFactor
        }

        if newZoomFactor < currentCamera.minAvailableVideoZoomFactor {
            newZoomFactor = currentCamera.minAvailableVideoZoomFactor
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nVideo scale factor capped to \(newZoomFactor)."
                , level: .dbg)
        } else if newZoomFactor > currentCamera.maxAvailableVideoZoomFactor {
            newZoomFactor = currentCamera.maxAvailableVideoZoomFactor
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nVideo scale factor capped to \(newZoomFactor)."
                , level: .dbg)
        }

        if isFix {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nFix video scale factor from \(exZoomFactor) to \(newZoomFactor)"
                + "\n\t\t.videoZoomFactor: \(currentCamera.videoZoomFactor)"
                + "\n\t\t.minAvailableVideoZoomFactor: \(currentCamera.minAvailableVideoZoomFactor)"
                + "\n\t\t.maxAvailableVideoZoomFactor: \(currentCamera.maxAvailableVideoZoomFactor)"
                + "\n\t\t.activeFormat.videoMaxZoomFactor: \(currentCamera.activeFormat.videoMaxZoomFactor)"
                , level: .dbg)
            exZoomFactor = newZoomFactor
        }
    }
}


extension CameraWrapperViewModel {
    enum CameraSide {
        case front
            , back
    }
}

extension CameraWrapperViewModel {
    enum FrontCameraMode {
        case normalWideAngle
            , trueDepth
        var captureDevices: [AVCaptureDevice.DeviceType] {
            switch self {
            case .normalWideAngle:
                return [.builtInWideAngleCamera]
            case .trueDepth:
                return [.builtInTrueDepthCamera]
            }
        }
    }
}

extension CameraWrapperViewModel {
    enum BackCameraMode {
        case normalWideAngle
            , dual
            , dualWideAngle
            , triple
            , ultraWide
            , telescope
        var captureDevices: [AVCaptureDevice.DeviceType] {
            switch self {
            case .normalWideAngle:
                return [.builtInWideAngleCamera]
            case .dual:
                return [.builtInDualCamera]
            case .dualWideAngle:
                return [.builtInDualWideCamera]
            case .triple:
                return [.builtInTripleCamera]
            case .ultraWide:
                return [.builtInUltraWideCamera]
            case .telescope:
                return [.builtInTelephotoCamera]
            }
        }
    }
}

