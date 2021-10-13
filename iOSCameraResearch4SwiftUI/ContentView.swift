
import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: CameraViewModel = CameraViewModel(defaultCameraSide: .back, frontCameraMode: nil, backCameraMode: .normalWideAngle)
    var body: some View {
        Button(action: {
            viewModel.isShooting = true
        }) {
            Text("Let's shooting!")
                .padding()
        }
        .fullScreenCover(isPresented: $viewModel.isShooting) {
            CameraBaseView().environmentObject(viewModel)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
