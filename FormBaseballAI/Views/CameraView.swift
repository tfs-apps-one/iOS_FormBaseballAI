// CameraView.swift — Full-screen camera screen with pose overlay, live score,
// and recording controls.
// Mirrors: tfsapps.formbaseballai.camera.CameraActivity

import SwiftUI
import AVFoundation

struct CameraView: View {

    let mode: FormMode

    @StateObject private var viewModel = CameraViewModel()
    @State private var analyzer = PoseAnalyzer()

    // Navigation
    @State private var multiFrameResult: MultiFrameResult? = nil
    @State private var navigateToResult = false

    // UI helpers
    @State private var isProcessing   = false
    @State private var hintText       = ""
    @State private var showHelpSheet  = false
    @State private var useFrontCamera = false

    // Auto-stop
    @State private var autoStopEnabled = false
    private static let autoStopSeconds = 7

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(captureSession: analyzer.captureSession)
                .ignoresSafeArea()

            PoseOverlayRepresentable(viewModel: viewModel)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top row
                HStack {
                    // Back button (mode switching)
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5)).clipShape(Circle())
                    }
                    .disabled(viewModel.recordingState == .recording)

                    Text(mode.localizedName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(mode == .pitching
                            ? Color(red: 0.133, green: 0.545, blue: 0.133)
                            : Color(red: 0.827, green: 0.329, blue: 0))
                        .cornerRadius(8)

                    Button { switchCamera() } label: {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 22)).foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5)).clipShape(Circle())
                    }
                    .disabled(viewModel.recordingState == .recording)

                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 16)

                // Live score + help button share a row, right-aligned, so the
                // "?" button doesn't collide with the You/Coach legend up top.
                HStack(spacing: 10) {
                    LiveScoreView(score: viewModel.liveScore)
                        .frame(maxWidth: .infinity)

                    Button { showHelpSheet = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 22)).foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5)).clipShape(Circle())
                    }
                }
                .padding(.top, 12).padding(.horizontal, 16)

                Text(hintText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white).multilineTextAlignment(.center)
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(Color.black.opacity(0.6)).cornerRadius(10)
                    .padding(.top, 8).padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 10) {
                    HStack {
                        Toggle(isOn: $autoStopEnabled) {
                            Text(NSLocalizedString("label_auto_stop", comment: ""))
                                .font(.system(size: 13)).foregroundColor(.white)
                        }
                        .tint(Color(red: 0, green: 0.902, blue: 0.463)).labelsHidden()
                        Text(NSLocalizedString("label_auto_stop", comment: ""))
                            .font(.system(size: 13)).foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    recordButton
                }
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showHelpSheet) { HelpSheet() }
        .navigationDestination(isPresented: $navigateToResult) {
            if let result = multiFrameResult { ResultView(result: result) }
        }
        .onAppear {
            viewModel.mode = mode
            hintText = defaultHint
            setupAnalyzer()
        }
        .onDisappear {
            analyzer.stopSession()
            viewModel.cancelAutoStop()
        }
        .onChange(of: viewModel.validationState) { updateHint() }
        .onChange(of: viewModel.recordingState)  { updateHint() }
        .onChange(of: viewModel.autoStopRemaining) { remaining in
            if viewModel.recordingState == .recording && remaining > 0 {
                hintText = String(format: NSLocalizedString("hint_auto_stop_countdown", comment: ""),
                                  remaining)
            }
        }
    }

    // MARK: – Record button

    private var recordButton: some View {
        Button {
            if viewModel.recordingState == .idle {
                viewModel.startRecording()
                startAutoStopIfEnabled()
            } else {
                viewModel.stopRecording()   // also cancels auto-stop
                processRecording()
            }
        } label: {
            HStack(spacing: 10) {
                if viewModel.recordingState == .idle {
                    Image(systemName: "play.fill")
                    Text(NSLocalizedString("btn_start_record", comment: ""))
                } else {
                    Image(systemName: "stop.fill")
                    Text(NSLocalizedString("btn_stop_record", comment: ""))
                }
            }
            .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(viewModel.recordingState == .idle
                ? (mode == .pitching
                    ? Color(red: 0.133, green: 0.545, blue: 0.133)
                    : Color(red: 0.827, green: 0.329, blue: 0))
                : Color(red: 0.937, green: 0.325, blue: 0.314))
            .cornerRadius(14)
        }
        .disabled(isProcessing)
        .padding(.horizontal, 24)
    }

    // MARK: – Analyzer setup

    private func setupAnalyzer() {
        analyzer.onPoseDetected = { [weak viewModel] pose, imgW, imgH in
            let state = PoseValidator.validate(pose: pose, mode: mode)
            let score = (state == .valid) ? FormScorer.quickScore(pose: pose, mode: mode) : -1
            DispatchQueue.main.async {
                viewModel?.updatePoseFrame(pose: pose, imageWidth: imgW, imageHeight: imgH,
                                           score: score, state: state)
            }
        }
        analyzer.setupSession(useFrontCamera: useFrontCamera) { success in
            guard success else { return }
            analyzer.startSession()
        }
    }

    private func switchCamera() {
        analyzer.switchCamera { _ in }
        useFrontCamera.toggle()
    }

    // MARK: – Auto-stop (delegated to @MainActor ViewModel)

    private func startAutoStopIfEnabled() {
        guard autoStopEnabled else { return }
        viewModel.startAutoStop(seconds: Self.autoStopSeconds) {
            // This closure is called on @MainActor
            viewModel.stopRecording()
            processRecording()
        }
    }

    // MARK: – Recording processing

    private func processRecording() {
        let frames = viewModel.recordedFrames
        guard frames.count >= 3 else {
            hintText = NSLocalizedString("recording_too_short", comment: "")
            return
        }

        isProcessing = true
        hintText     = NSLocalizedString("hint_processing", comment: "")

        let capturedMode = mode

        DispatchQueue.global(qos: .userInitiated).async {
            let n     = frames.count
            let count = min(8, n)
            var phases = [FrameCapture]()

            for i in 0..<count {
                let idx = (count == 1) ? 0
                    : Int(round(Double(i) * Double(n - 1) / Double(count - 1)))
                let rf = frames[idx]
                phases.append(FormScorer.scoreFrameCapture(
                    pose: rf.pose, imgW: rf.imgW, imgH: rf.imgH,
                    mode: capturedMode, phaseIndex: i))
            }

            let worstIdx = phases.indices.min {
                phases[$0].overallScore < phases[$1].overallScore } ?? 0
            let avg = phases.map(\.overallScore).reduce(0, +) / Float(phases.count)

            // Build feedback + a skeleton render for every phase (1–8), not just the worst.
            var strengthsPerPhase    = [[String]]()
            var improvementsPerPhase = [[String]]()
            var imagePaths           = [String?]()

            for (i, phase) in phases.enumerated() {
                var strengths    = [String]()
                var improvements = [String]()
                FormScorer.addFeedback(frame: phase, mode: capturedMode,
                                       strengths: &strengths, improvements: &improvements)
                strengthsPerPhase.append(strengths)
                improvementsPerPhase.append(improvements)

                let path = SkeletonRenderer.render(
                    capturePose: phase.capturePose,
                    mode: capturedMode, phaseNumber: i + 1,
                    phaseScore: phase.overallScore)
                imagePaths.append(path)
            }

            let result = MultiFrameResult(
                mode: capturedMode, phases: phases, averageScore: avg,
                worstPhaseIndex: worstIdx,
                strengthsPerPhase: strengthsPerPhase,
                improvementsPerPhase: improvementsPerPhase,
                imagePaths: imagePaths)

            DispatchQueue.main.async {
                isProcessing     = false
                multiFrameResult = result
                navigateToResult = true
            }
        }
    }

    // MARK: – Hint text

    private var defaultHint: String {
        mode == .pitching
            ? NSLocalizedString("camera_hint_pitching", comment: "")
            : NSLocalizedString("camera_hint_batting",  comment: "")
    }

    private func updateHint() {
        guard viewModel.recordingState != .recording else { return }
        switch viewModel.validationState {
        case .noHuman:   hintText = NSLocalizedString("hint_no_human", comment: "")
        case .wrongPose: hintText = mode == .pitching
                ? NSLocalizedString("hint_wrong_pose_pitching", comment: "")
                : NSLocalizedString("hint_wrong_pose_batting",  comment: "")
        case .valid:     hintText = defaultHint
        }
    }
}

// MARK: – Camera preview

struct CameraPreviewView: UIViewRepresentable {
    let captureSession: AVCaptureSession
    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView(); v.session = captureSession; return v
    }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var session: AVCaptureSession? {
        get { previewLayer.session }
        set { previewLayer.session = newValue; previewLayer.videoGravity = .resizeAspectFill }
    }
}

// MARK: – Pose overlay

struct PoseOverlayRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    func makeUIView(context: Context) -> PoseOverlayUIView {
        let v = PoseOverlayUIView(); v.backgroundColor = .clear; v.isOpaque = false; return v
    }
    func updateUIView(_ uiView: PoseOverlayUIView, context: Context) {
        uiView.setMode(viewModel.mode)
        // 人が検出されている（noHumanでない）限りスケルトンを表示する
        // wrongPoseもスイング・投球動作の一部なので隠さない
        if viewModel.validationState != .noHuman, let frame = viewModel.poseFrame {
            uiView.setPose(frame.pose, imageWidth: frame.imageWidth, imageHeight: frame.imageHeight)
        } else {
            uiView.clearPose()
        }
    }
}

// MARK: – Live score HUD

struct LiveScoreView: View {
    let score: Float
    var color: Color {
        score >= 70 ? Color(red: 0, green: 0.902, blue: 0.463)
        : score >= 45 ? Color(red: 1, green: 0.792, blue: 0.157)
        : Color(red: 0.937, green: 0.325, blue: 0.314)
    }
    var body: some View {
        HStack(spacing: 8) {
            Text(NSLocalizedString("label_live_score", comment: ""))
                .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.8))
            ProgressView(value: Double(max(0, score)), total: 100)
                .tint(color).background(Color.white.opacity(0.15)).cornerRadius(4)
            Text("\(Int(max(0, score)))")
                .font(.system(size: 15, weight: .bold)).foregroundColor(color)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.black.opacity(0.6)).cornerRadius(10)
    }
}

// MARK: – Help Sheet

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.1).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(NSLocalizedString("help_dialog_title", comment: ""))
                            .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28)).foregroundColor(.gray)
                        }
                    }
                    HelpSection(header: NSLocalizedString("help_steps_header",    comment: ""),
                                text:   NSLocalizedString("help_steps_text",      comment: ""))
                    HelpSection(header: NSLocalizedString("help_coach_header",    comment: ""),
                                text:   NSLocalizedString("help_coach_text",      comment: ""))
                    HelpSection(header: NSLocalizedString("help_tips_header",     comment: ""),
                                text:   NSLocalizedString("help_tips_text",       comment: ""))
                    HelpSection(header: NSLocalizedString("help_controls_header", comment: ""),
                                text:   NSLocalizedString("help_controls_text",   comment: ""))
                }
                .padding(24)
            }
        }
    }
}

private struct HelpSection: View {
    let header: String
    let text:   String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header).font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0, green: 0.902, blue: 0.463))
            Text(text).font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).background(Color.white.opacity(0.07)).cornerRadius(12)
    }
}
