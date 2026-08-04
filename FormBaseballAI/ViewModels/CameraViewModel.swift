// CameraViewModel.swift — State management for the camera screen.
// Mirrors: tfsapps.formbaseballai.viewmodel.CameraViewModel

import Foundation
import Combine
import MLKitPoseDetectionCommon

@MainActor
final class CameraViewModel: ObservableObject {

    // MARK: – Recording state

    enum RecordingState { case idle, recording }

    @Published private(set) var recordingState: RecordingState = .idle

    private static let maxRecordedFrames = 400

    private var _recordedFrames: [RecordedFrame] = []
    var recordedFrames: [RecordedFrame] { _recordedFrames }

    func startRecording() {
        _recordedFrames.removeAll()
        resetBest()
        recordingState = .recording
    }

    func stopRecording() {
        recordingState = .idle
        cancelAutoStop()
    }

    // MARK: – Mode

    @Published var mode: FormMode = .pitching

    // MARK: – Latest overlay frame

    struct PoseFrame {
        let pose:        Pose
        let imageWidth:  Int
        let imageHeight: Int
    }

    @Published private(set) var poseFrame: PoseFrame? = nil

    // MARK: – Live score

    @Published private(set) var liveScore: Float = 0

    // MARK: – Validation state

    @Published private(set) var validationState: ValidationState = .noHuman

    // MARK: – Auto-stop timer (runs on @MainActor — no concurrency issues)

    @Published private(set) var autoStopRemaining: Int = 0
    private var autoStopTask: Task<Void, Never>?

    /// Starts a countdown; calls `onTrigger` on the main actor when it reaches 0.
    func startAutoStop(seconds: Int, onTrigger: @escaping @MainActor () -> Void) {
        autoStopTask?.cancel()
        autoStopRemaining = seconds
        autoStopTask = Task { [weak self] in
            guard let self else { return }
            while self.autoStopRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                guard self.recordingState == .recording else { return }
                self.autoStopRemaining -= 1
            }
            if !Task.isCancelled && self.recordingState == .recording {
                onTrigger()
            }
        }
    }

    func cancelAutoStop() {
        autoStopTask?.cancel()
        autoStopTask = nil
        autoStopRemaining = 0
    }

    // MARK: – Best-frame tracking

    private var bestScore: Float = -1
    private var bestFrame: PoseFrame? = nil

    func updatePoseFrame(pose: Pose, imageWidth: Int, imageHeight: Int,
                         score: Float, state: ValidationState) {
        let frame = PoseFrame(pose: pose, imageWidth: imageWidth, imageHeight: imageHeight)
        poseFrame        = frame
        validationState  = state

        if state == .valid {
            liveScore = score
            if score > bestScore {
                bestScore = score
                bestFrame = frame
            }
        } else {
            liveScore = 0
        }

        // スケルトン表示・録画は「人が検出されている（noHumanでない）」間はすべて行う
        // wrongPose（スイング途中など姿勢が一時的にずれたフレーム）も逃さずキャプチャする
        if state != .noHuman,
           recordingState == .recording,
           _recordedFrames.count < Self.maxRecordedFrames {
            _recordedFrames.append(RecordedFrame(pose: pose, imgW: imageWidth, imgH: imageHeight))
        }
    }

    func getBestFrame() -> PoseFrame? { bestFrame ?? poseFrame }

    func resetBest() {
        bestScore = -1
        bestFrame = nil
    }

    // MARK: – Inner data holders

    struct RecordedFrame {
        let pose: Pose
        let imgW: Int
        let imgH: Int
    }
}
