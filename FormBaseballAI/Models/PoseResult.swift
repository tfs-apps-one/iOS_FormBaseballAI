// PoseResult.swift — Single-frame full analysis result.
// Mirrors: tfsapps.formbaseballai.model.PoseResult

import Foundation

struct PoseResult {
    let mode:            FormMode
    let componentScores: [Float]
    let measuredAngles:  [Float]
    let idealAngles:     [Float]
    let overallScore:    Float
    let strengths:       [String]
    let improvements:    [String]
}
