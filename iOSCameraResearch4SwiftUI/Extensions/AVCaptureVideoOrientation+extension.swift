import AVFoundation

extension AVCaptureVideoOrientation: CustomStringConvertible {
    public var description: String {
        switch self {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portraitUpsideDown"
        case .landscapeRight: return "landscapeRight"
        case .landscapeLeft: return "landscapeLeft"
        @unknown default: return "default"
        }
    }
}
