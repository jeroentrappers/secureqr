import AVFoundation
import Combine
import Foundation
import Vision

/// Owns the capture session and looks for QR codes in its frames with Vision.
///
/// Threading: the session is configured, started and stopped on
/// `sessionQueue`; frames arrive and are analysed on `videoQueue`; published
/// state and `onDetect` are delivered on the main queue.
final class CameraController: NSObject, ObservableObject {
    @Published private(set) var isTorchOn = false
    @Published private(set) var hasTorch = false
    /// True when no usable camera was found (for example in the simulator).
    @Published private(set) var isUnavailable = false

    let session = AVCaptureSession()

    /// Called on the main queue with the text of a detected QR code.
    /// Detection then pauses until `start()` is called again.
    var onDetect: ((String) -> Void)?

    private let sessionQueue = DispatchQueue(label: "be.appmire.secureqr.camera.session")
    private let videoQueue = DispatchQueue(label: "be.appmire.secureqr.camera.video", qos: .userInitiated)

    // sessionQueue only
    private var isConfigured = false
    private var device: AVCaptureDevice?

    // videoQueue only
    private var detectionEnabled = false
    private var lastRequestTime: TimeInterval = 0
    private var lastPayload: String?
    private var ignoreLastPayloadUntil: TimeInterval = 0

    /// Vision runs at most this often.
    private let minimumRequestInterval: TimeInterval = 0.12
    /// After coming back to the scanner, the code that was just handled is
    /// ignored for a moment so that it does not fire again straight away.
    private let repeatGuardInterval: TimeInterval = 2.5

    private let barcodeRequest: VNDetectBarcodesRequest = {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        return request
    }()

    /// Starts the camera and (re)enables detection.
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.configureIfNeeded()
            guard self.isConfigured else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.videoQueue.async {
                self.ignoreLastPayloadUntil = ProcessInfo.processInfo.systemUptime + self.repeatGuardInterval
                self.detectionEnabled = true
            }
        }
    }

    /// Stops the camera. The torch goes off with it.
    func stop() {
        videoQueue.async { [weak self] in
            self?.detectionEnabled = false
        }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isTorchOn = false
            }
        }
    }

    func toggleTorch() {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.device, device.hasTorch, device.isTorchAvailable else { return }
            do {
                try device.lockForConfiguration()
                let turnOn = device.torchMode != .on
                device.torchMode = turnOn ? .on : .off
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.isTorchOn = turnOn
                }
            } catch {
                // The torch is a convenience; leave it as it is.
            }
        }
    }

    // MARK: - Configuration (sessionQueue)

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            reportUnavailable()
            return
        }

        session.beginConfiguration()
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            reportUnavailable()
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        // Frames that arrive while Vision is still busy are dropped.
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            reportUnavailable()
            return
        }
        session.addOutput(output)
        session.commitConfiguration()

        do {
            try camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            camera.unlockForConfiguration()
        } catch {
            // Default focus behaviour is fine.
        }

        device = camera
        isConfigured = true
        let torch = camera.hasTorch
        DispatchQueue.main.async { [weak self] in
            self?.hasTorch = torch
            self?.isUnavailable = false
        }
    }

    private func reportUnavailable() {
        DispatchQueue.main.async { [weak self] in
            self?.isUnavailable = true
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // Runs on `videoQueue`, a serial queue. The Vision request is performed
    // synchronously, so there is never more than one in flight; frames that
    // arrive meanwhile are discarded by the output, and the interval check
    // keeps the rate down further.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard detectionEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastRequestTime >= minimumRequestInterval else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastRequestTime = now

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([barcodeRequest])
        } catch {
            return
        }

        let observations = barcodeRequest.results ?? []
        guard let text = observations.compactMap({ $0.payloadStringValue }).first(where: { !$0.isEmpty }) else {
            return
        }
        if text == lastPayload && now < ignoreLastPayloadUntil {
            return
        }

        lastPayload = text
        detectionEnabled = false
        DispatchQueue.main.async { [weak self] in
            self?.onDetect?(text)
        }
    }
}
