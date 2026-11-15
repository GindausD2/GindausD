import AVFoundation
import SwiftUI
import UIKit

/// Session setup, start, stop and capture all run on one queue.
final class VisualCamera: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published private(set) var device: AVCaptureDevice?
    @Published private(set) var unavailable = false

    private let queue = DispatchQueue(label: "max.visual.camera", qos: .userInitiated)
    private let output = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?
    private var completion: ((UIImage?) -> Void)?
    private var capturedImage: UIImage?

    func setRunning(_ running: Bool) {
        queue.async { [self] in
            if running {
                if captureDevice == nil { captureDevice = configure() }
                if captureDevice != nil && !session.isRunning { session.startRunning() }
            } else if session.isRunning {
                session.stopRunning()
            }
            let availableDevice = running && session.isRunning ? captureDevice : nil
            DispatchQueue.main.async { [self] in
                device = availableDevice
                unavailable = running && availableDevice == nil
            }
        }
    }

    func takePhoto(completion: @escaping (UIImage?) -> Void) {
        queue.async { [self] in
            guard session.isRunning, let captureDevice, let connection = output.connection(with: .video),
                  self.completion == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.completion = completion
            let rotation = AVCaptureDevice.RotationCoordinator(device: captureDevice, previewLayer: nil)
            let angle = rotation.videoRotationAngleForHorizonLevelCapture
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = error == nil ? photo.fileDataRepresentation().flatMap { UIImage(data: $0) } : nil
        queue.async { [self] in
            capturedImage = image
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        queue.async { [self] in
            let callback = completion
            let image = error == nil ? capturedImage : nil
            completion = nil
            capturedImage = nil
            DispatchQueue.main.async { callback?(image) }
        }
    }

    private func configure() -> AVCaptureDevice? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return nil }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
        guard session.canAddInput(input) else { return nil }
        session.addInput(input)
        guard session.canAddOutput(output) else { session.removeInput(input); return nil }
        session.addOutput(output)
        return device
    }
}

struct VisualCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let device: AVCaptureDevice?

    func makeUIView(context: Context) -> Preview {
        let view = Preview()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ view: Preview, context: Context) { view.trackRotation(of: device) }

    final class Preview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        private var rotation: AVCaptureDevice.RotationCoordinator?
        private var observation: NSKeyValueObservation?

        func trackRotation(of device: AVCaptureDevice?) {
            guard rotation?.device != device else { return }
            observation = nil
            rotation = device.map { AVCaptureDevice.RotationCoordinator(device: $0, previewLayer: previewLayer) }
            observation = rotation?.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] rotation, _ in
                let angle = rotation.videoRotationAngleForHorizonLevelPreview
                DispatchQueue.main.async { [weak self] in
                    guard let connection = self?.previewLayer.connection,
                          connection.isVideoRotationAngleSupported(angle) else { return }
                    connection.videoRotationAngle = angle
                }
            }
        }
    }
}
