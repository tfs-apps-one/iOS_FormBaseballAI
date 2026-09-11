// PracticeRecord.swift — A single saved practice-history entry.
// Created whenever a diagnosis finishes (see CameraView), so the user can
// look back at their score trend over time.
// Mirrors: tfsapps.formbaseballai.practice.PracticeRecord

import Foundation

struct PracticeRecord: Identifiable, Codable, Equatable {
    let id:                 UUID
    let date:               Date
    let mode:               FormMode
    /// The diagnosis's overall average score (0–100).
    let score:              Float
    /// The worst-scoring phase's improvement tips, joined into one paragraph —
    /// e.g. "Keep your throwing elbow at ~85°. (4° → 85°), …".
    let improvementSummary: String

    init(id: UUID = UUID(), date: Date = Date(), mode: FormMode, score: Float, improvementSummary: String) {
        self.id = id
        self.date = date
        self.mode = mode
        self.score = score
        self.improvementSummary = improvementSummary
    }
}
