import SwiftUI

struct CameraBaseView: View {
    @ObservedObject var cameraVM: CameraViewModel = CameraViewModel(defaultCameraSide: .back, frontCameraMode: nil, backCameraMode: .normalWideAngle)
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State var orientation: UIDeviceOrientation = UIDevice.current.fixedOrientation

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraWrapperView(geometrySize: geometry.size).environmentObject(cameraVM)
                VStack(alignment: .trailing) {
                    Spacer().frame(height: 10)
                    HStack(alignment: .top) {
                        Spacer()
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "multiply")
                                .foregroundColor(.white)
                                .font(.system(size: 30))
                        }
                        Spacer().frame(width: 30)
                    }
                    Spacer()
                }

                if orientation == .landscapeLeft {
                    debuglogAtView("\(String(describing: Self.self))::\(#function)@line\(#line)"
                        + "\nlandscapeLeft"
                        , level: .dbg)
                    HStack {
                        Spacer()
                        Button(action: {
                            cameraVM.shooting()
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .padding(10)
                        }
                    }
                } else if orientation == .landscapeRight {
                    debuglogAtView("\(String(describing: Self.self))::\(#function)@line\(#line)"
                        + "\nlandscapeRight"
                        , level: .dbg)
                    HStack {
                        Button(action: {
                            cameraVM.shooting()
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .padding(10)
                        }
                        Spacer()
                    }
                } else {
                    debuglogAtView("\(String(describing: Self.self))::\(#function)@line\(#line)"
                        + "\nportrait"
                        , level: .dbg)
                    VStack {
                        Spacer()
                        Button(action: {
                            cameraVM.shooting()
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .padding(10)
                        }
                    }
                }
            }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { orientation in
                    debuglog("\(String(describing: Self.self))::\(#function)@\(#line)"
                        + "\norientation: \(orientation)"
                        + "\nUIDevice.current.orientation: \(UIDevice.current.orientation)"
                        + "\nUIDevice.current.fixedOrientation: \(UIDevice.current.fixedOrientation)"
                        , level: .dbg)
                    self.orientation = UIDevice.current.fixedOrientation
                }
        }
            .background(Color.black)
    }
}

struct CameraBaseView_Previews: PreviewProvider {
    static let cameraVM: CameraViewModel = CameraViewModel(defaultCameraSide: .back, frontCameraMode: nil, backCameraMode: .normalWideAngle)
    static var previews: some View {
        CameraBaseView().environmentObject(cameraVM)
    }
}
