
import SwiftUI

struct ContentView: View {
    @State var isShooting = false

    var body: some View {
        Button(action: {
            isShooting = true
        }) {
            Text("Let's shooting!")
                .padding()
        }
        .fullScreenCover(isPresented: $isShooting) {
            CameraBaseView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
