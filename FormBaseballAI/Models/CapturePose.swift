// CapturePose.swift — Serializable snapshot of an ML Kit Pose.
// Mirrors: tfsapps.formbaseballai.model.CapturePose
//
// ML Kit Pose objects cannot be serialized, so this class extracts every
// landmark's x/y and confidence into plain Float arrays.
// Index = PoseLandmarkType raw value (0 – 32).

import Foundation
import MLKitPoseDetectionCommon
import MLKitVision

// MARK: – All landmark types (ML Kit iOS is ObjC-based, so we define the list here)

/// All 33 ML Kit pose landmark types in order (index 0–32).
let allPoseLandmarkTypes: [PoseLandmarkType] = [
    .nose,
    .leftEyeInner, .leftEye, .leftEyeOuter,
    .rightEyeInner, .rightEye, .rightEyeOuter,
    .leftEar, .rightEar,
    .mouthLeft, .mouthRight,
    .leftShoulder, .rightShoulder,
    .leftElbow, .rightElbow,
    .leftWrist, .rightWrist,
    .leftPinkyFinger, .rightPinkyFinger,
    .leftIndexFinger, .rightIndexFinger,
    .leftThumb, .rightThumb,
    .leftHip, .rightHip,
    .leftKnee, .rightKnee,
    .leftAnkle, .rightAnkle,
    .leftHeel, .rightHeel,
    .leftToe, .rightToe
]

// MARK: – CapturePose

struct CapturePose: Codable {

    // MARK: – Constants

    /// Total ML Kit landmark slots (33 types, index 0–32).
    static let landmarkCount = 33

    /// Minimum in-frame likelihood to store a landmark's position.
    static let confThreshold: Float = 0.35

    // MARK: – Data

    /// X-coordinate per landmark (image pixels); NaN if below threshold.
    let x: [Float]
    /// Y-coordinate per landmark (image pixels); NaN if below threshold.
    let y: [Float]
    /// In-frame likelihood per landmark (0–1).
    let conf: [Float]

    let imageWidth:  Int
    let imageHeight: Int

    // MARK: – Factory

    static func from(pose: Pose, imgW: Int, imgH: Int) -> CapturePose {
        var px = [Float](repeating: Float.nan, count: landmarkCount)
        var py = [Float](repeating: Float.nan, count: landmarkCount)
        var pc = [Float](repeating: 0,         count: landmarkCount)

        for (idx, type) in allPoseLandmarkTypes.enumerated() {
            guard idx < landmarkCount else { break }
            let lm = pose.landmark(ofType: type)
            pc[idx] = lm.inFrameLikelihood
            if lm.inFrameLikelihood >= confThreshold {
                px[idx] = Float(lm.position.x)
                py[idx] = Float(lm.position.y)
            }
        }
        return CapturePose(x: px, y: py, conf: pc, imageWidth: imgW, imageHeight: imgH)
    }

    // MARK: – Accessors

    /// Returns true if the landmark at the given type index was recorded above threshold.
    func hasLandmark(_ type: PoseLandmarkType) -> Bool {
        guard let idx = allPoseLandmarkTypes.firstIndex(of: type),
              idx < Self.landmarkCount else { return false }
        return !x[idx].isNaN
    }

    /// Returns image-space CGPoint for the landmark, or nil if absent/low-confidence.
    func point(_ type: PoseLandmarkType) -> CGPoint? {
        guard let idx = allPoseLandmarkTypes.firstIndex(of: type),
              idx < Self.landmarkCount, !x[idx].isNaN else { return nil }
        return CGPoint(x: CGFloat(x[idx]), y: CGFloat(y[idx]))
    }
}
