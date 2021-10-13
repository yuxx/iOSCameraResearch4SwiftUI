import SwiftUI

struct CameraBaseView: View {
    @EnvironmentObject var cameraVM: CameraViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraWrapperView(geometrySize: geometry.size).environmentObject(cameraVM)
                VStack(alignment: .trailing) {
                    Spacer().frame(height: 10)
                    HStack(alignment: .top) {
                        Spacer()
                        Button(action: {
                            cameraVM.isShooting = false
                        }) {
                            Image(systemName: "multiply")
                                .foregroundColor(.white)
                                .font(.system(size: 30))
                        }
                        Spacer().frame(width: 30)
                    }
                    Spacer()
                }

                if cameraVM.fixedOrientation == .landscapeLeft {
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
                } else if cameraVM.fixedOrientation == .landscapeRight {
                    Button(action: {
                        cameraVM.shooting()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 50, height: 50)
                            .padding(10)
                    }
                    Spacer()
                } else {
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
