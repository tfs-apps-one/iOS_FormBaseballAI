// PoseValidator.swift — Three-state validation gate before scoring.
// Mirrors: tfsapps.formbaseballai.analyzer.PoseValidator
//
// ValidationState:
//   noHuman   – not enough high-confidence landmarks
//   wrongPose – a human is detected, but pose doesn't match the sport
//   valid     – confirmed human anatomy AND sport-pose → score it
//
// Design notes
// ─────────────
// • All checks use image-space Y coordinates: smaller Y = higher in frame.
// • Confidence threshold 0.55 is intentionally higher than FormScorer's
//   MIN_CONFIDENCE (0.30) so anatomy reasoning is based on reliable points.
// • Sport-pose thresholds are loose so genuine mid-motion frames aren't
//   rejected due to noisy keypoints.

import Foundation
import MLKitPoseDetectionCommon
import MLKitVision

enum ValidationState {
    case valid
    case noHuman
    case wrongPose
}

enum PoseValidator {

    // MARK: – Public entry point

    static func validate(pose: Pose, mode: FormMode) -> ValidationState {
        guard isHuman(pose) else { return .noHuman }
        switch mode {
        case .pitching: return isPitchingPose(pose) ? .valid : .wrongPose
        case .batting:  return isBattingPose(pose)  ? .valid : .wrongPose
        }
    }

    // MARK: – isHuman

    /// Passes only if:
    ///  1. ≥8 of 10 key landmarks visible at conf ≥ 0.55
    ///  2. Shoulder midpoint is ABOVE hip midpoint (basic upright anatomy)
    ///  3. Shoulder width ≥ 30% of torso height (not a thin pole)
    private static func isHuman(_ pose: Pose) -> Bool {
        let humanConf: Float = 0.65   // スイング・投球の回転中も信頼性を確保しつつ誤反応を抑制
        let minVisible = 7            // 横向き回転時は肩・肘などが隠れるため7に緩和
        let keyTypes: [PoseLandmarkType] = [
            .leftShoulder, .rightShoulder,
            .leftHip, .rightHip,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftKnee, .rightKnee
        ]
        let visible = keyTypes.filter { pose.landmark(ofType: $0).inFrameLikelihood >= humanConf }.count
        guard visible >= minVisible else { return false }

        let lS = pose.landmark(ofType: .leftShoulder).position
        let rS = pose.landmark(ofType: .rightShoulder).position
        let lH = pose.landmark(ofType: .leftHip).position
        let rH = pose.landmark(ofType: .rightHip).position

        let shoulderY = (lS.y + rS.y) * 0.5
        let hipY      = (lH.y + rH.y) * 0.5
        guard shoulderY < hipY else { return false } // shoulders must be higher (smaller Y)

        // 横向き回転時に肩幅がゼロ近くになる問題を解消するため
        // 肩幅と腰幅の大きい方を使用し、閾値も0.20に緩和する
        let shoulderWidth = abs(lS.x - rS.x)
        let hipWidth      = abs(lH.x - rH.x)
        let bodyWidth     = max(shoulderWidth, hipWidth)
        let torsoHeight   = hipY - shoulderY
        return bodyWidth >= torsoHeight * 0.20
    }

    // MARK: – isPitchingPose

    /// Pitching (any phase: windup / cocking / delivery / release / follow-through):
    ///  条件A: いずれかのひじが肩ラインより上 (テイクバック・コッキング)
    ///  条件B: 両ひじの水平スプレッドが肩幅の35%以上 (デリバリー・リリース・フォロースルー)
    ///  → AまたはBを満たし、かつ少なくとも1つのひじが腰より上にある
    private static func isPitchingPose(_ pose: Pose) -> Bool {
        let lS = pose.landmark(ofType: .leftShoulder).position
        let rS = pose.landmark(ofType: .rightShoulder).position
        let lH = pose.landmark(ofType: .leftHip).position
        let rH = pose.landmark(ofType: .rightHip).position
        let lE = pose.landmark(ofType: .leftElbow).position
        let rE = pose.landmark(ofType: .rightElbow).position

        let shoulderY     = (lS.y + rS.y) * 0.5
        let hipY          = (lH.y + rH.y) * 0.5
        let shoulderWidth = abs(lS.x - rS.x)
        let elbowSpread   = abs(lE.x - rE.x)

        // 最低条件: 少なくとも一方のひじが腰より高い
        guard rE.y < hipY || lE.y < hipY else { return false }

        // 条件A: ひじが肩より上 (テイクバック〜コッキング)
        let elbowAboveShoulder = rE.y < shoulderY || lE.y < shoulderY
        // 条件B: 腕が横に広がっている (デリバリー〜リリース〜フォロースルー)
        let wideArmSpread = elbowSpread >= shoulderWidth * 0.35

        return elbowAboveShoulder || wideArmSpread
    }

    // MARK: – isBattingPose

    /// Batting (any phase: stance / load / swing / contact / follow-through):
    ///  スイングの全フェーズをカバーするため条件を緩和。
    ///  • 少なくとも1つのひじが膝より高い (最低限の腕の動き)
    ///  • 両ひじの水平スプレッドが肩幅の20%以上 (構え〜フォロースルー)
    private static func isBattingPose(_ pose: Pose) -> Bool {
        let lS = pose.landmark(ofType: .leftShoulder).position
        let rS = pose.landmark(ofType: .rightShoulder).position
        let lK = pose.landmark(ofType: .leftKnee).position
        let rK = pose.landmark(ofType: .rightKnee).position
        let lE = pose.landmark(ofType: .leftElbow).position
        let rE = pose.landmark(ofType: .rightElbow).position

        let kneeY         = (lK.y + rK.y) * 0.5
        let shoulderWidth = abs(lS.x - rS.x)
        let elbowSpread   = abs(lE.x - rE.x)

        // 最低条件: 少なくとも一方のひじが膝より高い
        guard lE.y < kneeY || rE.y < kneeY else { return false }

        // 腕が何らかの広がりを持つ (ただ立っているだけでなく構えや動作中)
        return elbowSpread >= shoulderWidth * 0.20
    }
}
