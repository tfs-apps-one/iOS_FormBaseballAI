// FrameCapture.swift — One scored phase in a multi-frame recording.
// Mirrors: tfsapps.formbaseballai.model.FrameCapture

import Foundation

struct FrameCapture: Codable {
    /// 0-based phase index (0 – 7).
    let phaseIndex:      Int
    /// Serializable pose snapshot.
    let capturePose:     CapturePose
    /// Per-component scores (5 values matching WEIGHTS order).
    let componentScores: [Float]
    /// Measured angles (degrees).
    let measuredAngles:  [Float]
    /// Ideal angles (degrees).
    let idealAngles:     [Float]
    /// Weighted overall score 0–100.
    let overallScore:    Float
}
