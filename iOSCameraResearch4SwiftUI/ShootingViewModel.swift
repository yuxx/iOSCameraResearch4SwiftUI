import Combine
import AVFoundation
import UIKit
import CoreMotion
import SwiftUI

final class ShootingViewModel: ObservableObject {
    @Published var isShooting: Bool = false
    private var defaultCameraSide: CameraSide
    private var currentCameraSide: CameraSide
    private var frontCameraMode: FrontCameraMode?
    private var backCameraMode: BackCameraMode?
    private(set) var captureSession: AVCaptureSession = AVCaptureSession()

    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    private(set) var currentCamera: AVCaptureDevice?

    @Published var previewLayer: AVCaptureVideoPreviewLayer?

    private var photoOut: AVCapturePhotoOutput?

    let focusIndicator: UIView = UIView()
    let coreMotionManager: CMMotionManager = CMMotionManager()

    private var exZoomFactor: CGFloat = 1.0

    var currentOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard let connection = previewLayer?.connection else {
                return
            }
            connection.videoOrientation = currentOrientation
        }
    }

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
//        setupPreviewLayer() // todo: CameraViewWrapper でやる
        // todo:
    }

    deinit {
        if coreMotionManager.isAccelerometerActive {
            coreMotionManager.stopAccelerometerUpdates()
        }
    }
}

extension ShootingViewModel {
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
debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
            photoOut.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])])
            if captureSession.canAddOutput(photoOut) {
debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
                captureSession.addOutput(photoOut)
            }
        } catch {
            debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                + "\nerror: \(error)"
                , level: .err)
        }
debuglog("\(String(describing: Self.self))::\(#function)@\(#line)", level: .dbg)
        captureSession.startRunning()
    }

}

extension ShootingViewModel {
    func adjustOrientationForAVCaptureVideoOrientation() {
        let newOrientation: AVCaptureVideoOrientation = {
            switch UIDevice.current.orientation {
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
                debuglog("\(String(describing: Self.self))::\(#function)@\(#line)\tlastOrientation: \(currentOrientation)", level: .dbg)
                return currentOrientation
            }
        }()
        currentOrientation = newOrientation
    }
}


extension ShootingViewModel {
    @objc func tapGesture(_ gesture: UITapGestureRecognizer) {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\ngesture.view?.frame: \(gesture.view?.frame)"
            , level: .dbg)
    }

    @objc func pinchGesture(_ gesture: UIPinchGestureRecognizer) {
        debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
            + "\ngesture.scale: \(gesture.scale)"
            + "\ngesture.velocity: \(gesture.velocity)"
            , level: .dbg)
    }
}


extension ShootingViewModel {
    enum CameraSide {
        case front
            , back
    }
}

extension ShootingViewModel {
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

extension ShootingViewModel {
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
