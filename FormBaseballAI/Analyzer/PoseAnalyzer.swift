// PoseAnalyzer.swift — AVFoundation capture + ML Kit pose detection pipeline.
// Mirrors: tfsapps.formbaseballai.analyzer.PoseAnalyzer
//
// Threading:
//   Capture session runs on a dedicated background queue.
//   Pose detection results are delivered on that same queue.
//   Callers must dispatch to the main queue for UI updates.

import AVFoundation
import CoreImage
import MLKitPoseDetectionCommon
import MLKitPoseDetectionAccurate
import MLKitVision
import UIKit

typealias PoseCallback = (_ pose: Pose, _ imageWidth: Int, _ imageHeight: Int) -> Void

final class PoseAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: – Public API

    /// Shared capture session (bound to PreviewLayer in the view).
    let captureSession = AVCaptureSession()

    var onPoseDetected: PoseCallback?

    // MARK: – Private

    private let poseDetector: PoseDetector
    private let sessionQueue = DispatchQueue(label: "com.tfsapps.poseAnalyzer",
                                             qos: .userInteractive)
    private var isProcessingFrame = false
    private var useFrontCamera    = false

    // MARK: – Init / deinit

    override init() {
        let options = AccuratePoseDetectorOptions()
        options.detectorMode = .stream
        poseDetector = PoseDetector.poseDetector(options: options)
        super.init()
    }

    // MARK: – Session setup

    func setupSession(useFrontCamera: Bool = false,
                      completion: @escaping (Bool) -> Void) {
        self.useFrontCamera = useFrontCamera
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let success = self.configureSession(front: useFrontCamera)
            DispatchQueue.main.async { completion(success) }
        }
    }

    func switchCamera(completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.stopRunning()
            let success = self.configureSession(front: !self.useFrontCamera)
            if success { self.captureSession.startRunning() }
            DispatchQueue.main.async { completion(success) }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    func shutdown() {
        stopSession()
    }

    // MARK: – Private session configuration

    private func configureSession(front: Bool) -> Bool {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = .hd1280x720

        // Remove existing inputs/outputs
        captureSession.inputs.forEach  { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        let position: AVCaptureDevice.Position = front ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else { return false }

        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(output) else { return false }
        captureSession.addOutput(output)

        // Fix orientation (videoRotationAngle replaces videoOrientation in iOS 17+)
        output.connections.forEach { connection in
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90  // portrait
            } else {
                connection.videoOrientation = .portrait
            }
        }

        useFrontCamera = front
        return true
    }

    // MARK: – AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !isProcessingFrame else { return }
        isProcessingFrame = true

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessingFrame = false
            return
        }

        let imgW = CVPixelBufferGetWidth(pixelBuffer)
        let imgH = CVPixelBufferGetHeight(pixelBuffer)

        let image = VisionImage(buffer: sampleBuffer)
        image.orientation = imageOrientation(front: useFrontCamera)

        poseDetector.process(image) { [weak self] poses, error in
            defer { self?.isProcessingFrame = false }
            guard error == nil, let pose = poses?.first else { return }
            self?.onPoseDetected?(pose, imgW, imgH)
        }
    }

    // MARK: – Orientation helper

    private func imageOrientation(front: Bool) -> UIImage.Orientation {
        // Assumes the device is held in portrait orientation
        return front ? .leftMirrored : .right
    }
}
