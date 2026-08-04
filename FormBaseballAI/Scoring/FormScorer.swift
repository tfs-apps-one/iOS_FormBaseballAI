// FormScorer.swift — Angle-based form scoring against CoachModel ideal values.
// Mirrors: tfsapps.formbaseballai.scoring.FormScorer
//
// Scoring formula
// ──────────────
//   deviation = |measured – ideal|
//   deviation ≤ tolerance              → 100 (green zone)
//   tolerance < dev ≤ 4×tol           → linear 100 → SCORE_FLOOR (yellow zone)
//   deviation > 4×tolerance            → SCORE_FLOOR (red zone; never 0)
//   SCORE_FLOOR = 20

import Foundation
import MLKitPoseDetectionCommon
import MLKitVision

enum FormScorer {

    // MARK: – Constants

    private static let scoreFloor: Float = 35
    private static let minConfidence: Float = 0.30

    /// Component weights (must sum to 1.0)
    private static let weights: [Float] = [
        0.25,  // 0  rightElbow
        0.25,  // 1  leftElbow
        0.20,  // 2  shoulderLevel
        0.15,  // 3  hipLevel
        0.15   // 4  leadKnee
    ]

    // MARK: – Quick score (real-time live bar)

    /// Fast, allocation-light score for the real-time HUD bar.
    /// Returns 0–100, or -1 if the pose is invalid.
    static func quickScore(pose: Pose, mode: FormMode) -> Float {
        guard PoseValidator.validate(pose: pose, mode: mode) == .valid else { return -1 }

        let coach = CoachModel.forMode(mode)

        let rElbow   = angleAt(pose: pose, a: .rightShoulder, b: .rightElbow, c: .rightWrist)
        let lElbow   = angleAt(pose: pose, a: .leftShoulder,  b: .leftElbow,  c: .leftWrist)
        let shoulder = horizontalAngle(pose: pose, a: .rightShoulder, b: .leftShoulder)
        let hip      = horizontalAngle(pose: pose, a: .rightHip,      b: .leftHip)
        let knee     = angleAt(pose: pose, a: .leftHip, b: .leftKnee, c: .leftAnkle)

        if rElbow == 0 && lElbow == 0 { return 0 }

        let measured = [rElbow, lElbow, shoulder, hip, knee]
        var overall: Float = 0
        for i in 0..<5 {
            let s = (measured[i] == 0) ? 50 : scoreComponent(measured[i],
                                                               ideal: coach.ideal(at: i),
                                                               tolerance: coach.tolerance(at: i))
            overall += s * weights[i]
        }
        return overall
    }

    // MARK: – scoreFrameCapture (multi-frame recording)

    /// Scores one pose frame for multi-frame recording analysis.
    static func scoreFrameCapture(pose: Pose, imgW: Int, imgH: Int,
                                   mode: FormMode, phaseIndex: Int) -> FrameCapture {
        let coach = CoachModel.forMode(mode)

        let rElbow   = angleAt(pose: pose, a: .rightShoulder, b: .rightElbow, c: .rightWrist)
        let lElbow   = angleAt(pose: pose, a: .leftShoulder,  b: .leftElbow,  c: .leftWrist)
        let shoulder = horizontalAngle(pose: pose, a: .rightShoulder, b: .leftShoulder)
        let hip      = horizontalAngle(pose: pose, a: .rightHip,      b: .leftHip)
        let knee     = angleAt(pose: pose, a: .leftHip, b: .leftKnee, c: .leftAnkle)

        let measured: [Float] = [rElbow, lElbow, shoulder, hip, knee]
        let ideals: [Float] = [
            coach.rightElbowIdeal, coach.leftElbowIdeal,
            coach.shoulderLevelIdeal, coach.hipLevelIdeal, coach.leadKneeIdeal
        ]

        var scores = [Float](repeating: 0, count: 5)
        var overall: Float = 0
        for i in 0..<5 {
            scores[i] = (measured[i] == 0) ? 50 : scoreComponent(measured[i],
                                                                   ideal: ideals[i],
                                                                   tolerance: coach.tolerance(at: i))
            overall += scores[i] * weights[i]
        }

        let cp = CapturePose.from(pose: pose, imgW: imgW, imgH: imgH)
        return FrameCapture(phaseIndex: phaseIndex, capturePose: cp,
                            componentScores: scores, measuredAngles: measured,
                            idealAngles: ideals, overallScore: overall)
    }

    // MARK: – addFeedback

    /// Populates strengths and improvements for a single scored phase (`frame`).
    /// Called once per phase so every phase (1–8) gets its own feedback.
    static func addFeedback(frame: FrameCapture, mode: FormMode,
                             strengths: inout [String], improvements: inout [String]) {
        let strengthKeys = [
            "strength_right_elbow", "strength_left_elbow",
            "strength_shoulder", "strength_hip", "strength_lead_knee"
        ]
        let improveKeys: [String] = {
            switch mode {
            case .pitching:
                return ["improve_pitch_right_elbow", "improve_pitch_left_elbow",
                        "improve_pitch_shoulder", "improve_pitch_hip", "improve_pitch_knee"]
            case .batting:
                return ["improve_bat_right_elbow", "improve_bat_left_elbow",
                        "improve_bat_shoulder", "improve_bat_hip", "improve_bat_knee"]
            }
        }()

        for i in 0..<5 {
            let s       = frame.componentScores[i]
            let measured = frame.measuredAngles[i]
            let ideal   = frame.idealAngles[i]
            if s >= 80, i < strengthKeys.count {
                strengths.append(NSLocalizedString(strengthKeys[i], comment: "") +
                                 String(format: " (%.0f°)", measured))
            } else if s < 60, i < improveKeys.count {
                improvements.append(NSLocalizedString(improveKeys[i], comment: "") +
                                    String(format: " (%.0f° → %.0f°)", measured, ideal))
            }
        }

        if strengths.isEmpty {
            strengths.append(NSLocalizedString("feedback_keep_practicing", comment: ""))
        }
        if improvements.isEmpty {
            improvements.append(NSLocalizedString("feedback_fine_tune", comment: ""))
        }
    }

    // MARK: – Scoring formula

    /// Zone 1 – green  (dev ≤ tol)         → 100
    /// Zone 2 – yellow (tol < dev ≤ 4×tol) → linear 100 → SCORE_FLOOR
    /// Zone 3 – red    (dev > 4×tol)        → SCORE_FLOOR
    static func scoreComponent(_ measured: Float, ideal: Float, tolerance: Float) -> Float {
        let dev = abs(measured - ideal)
        if dev <= tolerance { return 100 }
        let maxDev = tolerance * 4
        if dev >= maxDev { return scoreFloor }
        let ratio = (dev - tolerance) / (maxDev - tolerance)
        return 100 - ratio * (100 - scoreFloor)
    }

    // MARK: – Geometry helpers

    /// Interior angle (degrees) at B in A–B–C; 0 if any landmark is absent/low-conf.
    static func angleAt(pose: Pose,
                        a typeA: PoseLandmarkType,
                        b typeB: PoseLandmarkType,
                        c typeC: PoseLandmarkType) -> Float {
        guard let a = point(pose: pose, type: typeA),
              let b = point(pose: pose, type: typeB),
              let c = point(pose: pose, type: typeC) else { return 0 }

        let bax = Float(a.x - b.x), bay = Float(a.y - b.y)
        let bcx = Float(c.x - b.x), bcy = Float(c.y - b.y)
        let dot   = bax * bcx + bay * bcy
        let magBA = sqrt(bax * bax + bay * bay)
        let magBC = sqrt(bcx * bcx + bcy * bcy)
        guard magBA > 1e-6, magBC > 1e-6 else { return 0 }
        let cos = max(-1, min(1, dot / (magBA * magBC)))
        return Float(acos(cos)) * 180 / .pi
    }

    /// Horizontal tilt (degrees) of the line from landmark A to B.
    static func horizontalAngle(pose: Pose,
                                 a typeA: PoseLandmarkType,
                                 b typeB: PoseLandmarkType) -> Float {
        guard let a = point(pose: pose, type: typeA),
              let b = point(pose: pose, type: typeB) else { return 0 }
        return Float(atan2(b.y - a.y, b.x - a.x)) * 180 / .pi
    }

    private static func point(pose: Pose, type: PoseLandmarkType) -> CGPoint? {
        let lm = pose.landmark(ofType: type)
        guard lm.inFrameLikelihood >= minConfidence else { return nil }
        return CGPoint(x: lm.position.x, y: lm.position.y)
    }

    // MARK: – CapturePose geometry helpers

    static func angleAt(cp: CapturePose,
                        a typeA: PoseLandmarkType,
                        b typeB: PoseLandmarkType,
                        c typeC: PoseLandmarkType) -> Float {
        guard let a = cp.point(typeA), let b = cp.point(typeB), let c = cp.point(typeC) else { return 0 }
        let bax = Float(a.x - b.x), bay = Float(a.y - b.y)
        let bcx = Float(c.x - b.x), bcy = Float(c.y - b.y)
        let dot   = bax * bcx + bay * bcy
        let magBA = sqrt(bax * bax + bay * bay)
        let magBC = sqrt(bcx * bcx + bcy * bcy)
        guard magBA > 1e-6, magBC > 1e-6 else { return 0 }
        let cos = max(-1, min(1, dot / (magBA * magBC)))
        return Float(acos(cos)) * 180 / .pi
    }

    static func horizontalAngle(cp: CapturePose,
                                 a typeA: PoseLandmarkType,
                                 b typeB: PoseLandmarkType) -> Float {
        guard let a = cp.point(typeA), let b = cp.point(typeB) else { return 0 }
        return Float(atan2(b.y - a.y, b.x - a.x)) * 180 / .pi
    }
}
