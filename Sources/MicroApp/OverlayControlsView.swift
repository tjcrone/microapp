import SwiftUI

struct OverlayControlsView: View {
    @Bindable var camera: CameraManager

    var body: some View {
        VStack(alignment: .trailing, spacing: 16) {
            // Zoom controls (vertical: +, label, -)
            VStack(spacing: 8) {
                Button(action: { camera.zoomIn() }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 24, weight: .medium))
                        .frame(width: 80, height: 70)
                }
                .buttonStyle(OverlayButtonStyle())

                Text(String(format: "%.1fx", camera.zoomLevel))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .frame(width: 80)

                Button(action: { camera.zoomOut() }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 24, weight: .medium))
                        .frame(width: 80, height: 70)
                }
                .buttonStyle(OverlayButtonStyle())
            }

            // Capture + Record buttons
            Button(action: { camera.capturePhoto() }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .medium))
                    .frame(width: 80, height: 80)
            }
            .buttonStyle(OverlayButtonStyle())

            Button(action: { camera.toggleRecording() }) {
                Image(systemName: camera.isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(camera.isRecording ? .red : .white)
                    .frame(width: 80, height: 80)
                    .scaleEffect(camera.isRecording ? pulseScale : 1.0)
            }
            .buttonStyle(OverlayButtonStyle(isRecording: camera.isRecording))

            // Reset window to native resolution
            Button(action: { camera.resetToNativeSize() }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 80, height: 70)
            }
            .buttonStyle(OverlayButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(24)
    }

    @State private var pulseScale: CGFloat = 1.0

    private var pulseAnimation: Animation {
        .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    }
}

struct OverlayButtonStyle: ButtonStyle {
    var isRecording: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isRecording ? Color.red.opacity(0.6) : Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
