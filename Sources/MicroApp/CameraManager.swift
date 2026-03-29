import AVFoundation
import AppKit
import Observation

/// Wrapper to pass non-Sendable AVFoundation types across isolation boundaries safely.
struct UnsafeSendable<T>: @unchecked Sendable {
    let value: T
}

@MainActor
@Observable
final class CameraManager: NSObject {
    var isSessionRunning = false
    var isRecording = false
    var zoomLevel: CGFloat = 1.0
    var showFlash = false
    var errorMessage: String?
    var hasDevice = false
    var videoDimensions: CGSize?

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var currentDevice: AVCaptureDevice?

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 5.0

    private var photoCaptureDelegate: PhotoCaptureDelegate?
    private var movieRecordingDelegate: MovieRecordingDelegate?

    override init() {
        super.init()
    }

    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        let device = findCaptureDevice()
        guard let device else {
            session.commitConfiguration()
            errorMessage = "No capture device found"
            hasDevice = false
            startDeviceNotifications()
            return
        }

        addDevice(device)
        session.commitConfiguration()
        startSession()
        startDeviceNotifications()
    }

    private func findCaptureDevice() -> AVCaptureDevice? {
        let externalDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        )
        if let device = externalDiscovery.devices.first {
            return device
        }
        let allDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        return allDiscovery.devices.first
    }

    private func addDevice(_ device: AVCaptureDevice) {
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }

            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }

            currentDevice = device
            hasDevice = true
            errorMessage = nil

            let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            videoDimensions = CGSize(width: Int(dims.width), height: Int(dims.height))
        } catch {
            errorMessage = "Failed to configure device: \(error.localizedDescription)"
            hasDevice = false
        }
    }

    private func startSession() {
        let wrapped = UnsafeSendable(value: session)
        Task.detached {
            wrapped.value.startRunning()
            let running = wrapped.value.isRunning
            await MainActor.run {
                self.isSessionRunning = running
            }
        }
    }

    func stopSession() {
        session.stopRunning()
        isSessionRunning = false
    }

    // MARK: - Window

    func resetToNativeSize() {
        guard let dims = videoDimensions,
              let window = NSApplication.shared.mainWindow else { return }
        let contentSize = NSSize(width: dims.width, height: dims.height)
        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        let oldFrame = window.frame
        let newFrame = NSRect(
            x: oldFrame.origin.x,
            y: oldFrame.origin.y + (oldFrame.height - frameSize.height),
            width: frameSize.width,
            height: frameSize.height
        )
        window.setFrame(newFrame, display: true, animate: true)
    }

    // MARK: - Zoom

    func zoomIn() {
        zoomLevel = min(zoomLevel + 0.5, maxZoom)
    }

    func zoomOut() {
        zoomLevel = max(zoomLevel - 0.5, minZoom)
    }

    // MARK: - Photo Capture

    func capturePhoto() {
        guard hasDevice else { return }

        let settings = AVCapturePhotoSettings()
        let delegate = PhotoCaptureDelegate(zoomLevel: zoomLevel) { [weak self] in
            Task { @MainActor in
                self?.triggerFlash()
            }
        }
        self.photoCaptureDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func triggerFlash() {
        showFlash = true
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            showFlash = false
        }
    }

    // MARK: - Video Recording

    func toggleRecording() {
        guard hasDevice else { return }

        if isRecording {
            movieOutput.stopRecording()
        } else {
            let url = desktopURL(prefix: "MicroApp_Recording", ext: "mov")
            let delegate = MovieRecordingDelegate { [weak self] in
                Task { @MainActor in
                    self?.isRecording = false
                }
            }
            self.movieRecordingDelegate = delegate
            movieOutput.startRecording(to: url, recordingDelegate: delegate)
            isRecording = true
        }
    }

    // MARK: - Device Notifications

    private func startDeviceNotifications() {
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let wrapped = UnsafeSendable(value: notification.object as? AVCaptureDevice)
            Task { @MainActor in
                guard let self, !self.hasDevice else { return }
                if let device = wrapped.value, device.hasMediaType(.video) {
                    self.session.beginConfiguration()
                    self.addDevice(device)
                    self.session.commitConfiguration()
                    self.startSession()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let wrapped = UnsafeSendable(value: notification.object as? AVCaptureDevice)
            Task { @MainActor in
                guard let self else { return }
                if let device = wrapped.value, device == self.currentDevice {
                    self.hasDevice = false
                    self.isSessionRunning = false
                    self.currentDevice = nil
                    self.errorMessage = "Device disconnected"
                    for input in self.session.inputs {
                        self.session.removeInput(input)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func desktopURL(prefix: String, ext: String) -> URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return desktop.appendingPathComponent("\(prefix)_\(timestamp).\(ext)")
    }
}

// MARK: - Photo Capture Delegate

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let zoomLevel: CGFloat
    private let onCapture: @Sendable () -> Void

    init(zoomLevel: CGFloat, onCapture: @escaping @Sendable () -> Void) {
        self.zoomLevel = zoomLevel
        self.onCapture = onCapture
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        onCapture()

        guard let imageData = photo.fileDataRepresentation(),
              let ciImage = CIImage(data: imageData) else { return }

        let fullExtent = ciImage.extent
        let cropRect: CGRect

        if zoomLevel > 1.0 {
            let cropWidth = fullExtent.width / zoomLevel
            let cropHeight = fullExtent.height / zoomLevel
            let originX = (fullExtent.width - cropWidth) / 2
            let originY = (fullExtent.height - cropHeight) / 2
            cropRect = CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)
        } else {
            cropRect = fullExtent
        }

        let croppedCI = ciImage.cropped(to: cropRect)
        let rep = NSCIImageRep(ciImage: croppedCI)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let url = desktop.appendingPathComponent("MicroApp_Capture_\(timestamp).png")

        try? pngData.write(to: url)
    }
}

// MARK: - Movie Recording Delegate

final class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let onFinish: @Sendable () -> Void

    init(onFinish: @escaping @Sendable () -> Void) {
        self.onFinish = onFinish
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        onFinish()
    }
}
