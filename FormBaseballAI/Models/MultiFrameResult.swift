// MultiFrameResult.swift — Full recording analysis result.
// Mirrors: tfsapps.formbaseballai.model.MultiFrameResult

import Foundation

struct MultiFrameResult: Codable {
    let mode:           FormMode
    let phases:         [FrameCapture]
    let averageScore:   Float
    /// Index (into `phases`) of the lowest-scoring phase; used as the initial selection.
    let worstPhaseIndex: Int
    /// Strengths, indexed by phase (0–7), matching `phases`.
    let strengthsPerPhase:    [[String]]
    /// Improvements, indexed by phase (0–7), matching `phases`.
    let improvementsPerPhase: [[String]]
    /// Absolute paths to each phase's saved skeleton PNG, indexed by phase; nil entries on render failure.
    let imagePaths:     [String?]

    // MARK: – Star rating (1–5)

    var starsString: String {
        let stars = starsCount
        return String(repeating: "★", count: stars) +
               String(repeating: "☆", count: 5 - stars)
    }

    var starsCount: Int {
        switch averageScore {
        case 90...:  return 5
        case 75...:  return 4
        case 55...:  return 3
        case 35...:  return 2
        default:     return 1
        }
    }
}
