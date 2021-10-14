import UIKit

extension UIDevice {
    var fixedOrientation: UIDeviceOrientation {
        let currentOrientation = UIDevice.current.orientation
        switch currentOrientation {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return currentOrientation
        default:
            let interfaceOrientation: UIInterfaceOrientation = {
                guard #available(iOS 13.0, *) else {
                    return UIApplication.shared.statusBarOrientation
                }
                // ref: https://stackoverflow.com/a/58441761/15474670
                guard let interfaceOrientation = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation else {
                    return .unknown
                }
                return interfaceOrientation
            }()
            switch interfaceOrientation {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeLeft
            case .landscapeRight: return .landscapeRight
            case .unknown: break
            @unknown default: break
            }
            return .portrait
        }
    }
}
