import SwiftUI

struct ContentView: View {
    @State private var camera = CameraManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.hasDevice {
                CameraPreview(session: camera.session, zoomLevel: camera.zoomLevel)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                    Text(camera.errorMessage ?? "No device connected")
                        .font(.title2)
                        .foregroundStyle(.gray)
                    Text("Connect a USB capture card to begin")
                        .font(.body)
                        .foregroundStyle(.gray.opacity(0.7))
                }
            }

            // Overlay controls
            if camera.hasDevice {
                OverlayControlsView(camera: camera)
            }

            // Capture flash
            if camera.showFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.15), value: camera.showFlash)
        .task {
            camera.setupSession()
        }
    }
}
