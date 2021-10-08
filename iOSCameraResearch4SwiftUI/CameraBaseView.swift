import SwiftUI

struct CameraBaseView: View {
    @EnvironmentObject var shootingVM: ShootingViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraViewWrapper(geometrySize: geometry.size).environmentObject(shootingVM)

                VStack(alignment: .trailing) {
                    Spacer().frame(height: 10)
                    HStack(alignment: .top) {
                        Spacer()
                        Button(action: {
                            shootingVM.isShooting = false
                        }) {
                            Image(systemName: "multiply")
                                .foregroundColor(.white)
                                .font(.system(size: 30))
                        }
                        Spacer().frame(width: 30)
                    }
                    Spacer()
                }
            }
        }
            .background(Color.black)
    }
}

struct CameraBaseView_Previews: PreviewProvider {
    static let shootingVM: ShootingViewModel = ShootingViewModel(defaultCameraSide: .back, frontCameraMode: nil, backCameraMode: .normalWideAngle)
    static var previews: some View {
        CameraBaseView().environmentObject(shootingVM)
    }
}
