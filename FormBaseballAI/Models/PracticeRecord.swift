// PracticeRecord.swift — A single saved practice-history entry.
// Created whenever a diagnosis finishes (see CameraView), so the user can
// look back at their score trend over time.
// Mirrors: tfsapps.formbaseballai.model.DiagnosticRecord

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

    /// Per-component scores (0–100) averaged across all phases of the session,
    /// in the app-wide order: 0=rightElbow, 1=leftElbow, 2=shoulderLevel,
    /// 3=hipLevel, 4=leadKnee.
    ///
    /// `nil` for records saved before this field existed (older app versions) —
    /// the Weak Point Trend and "compared with last time" features simply skip
    /// those records, no migration needed (Codable decodes a missing key as nil).
    let componentScores:    [Float]?

    /// File name (NOT a full path — the app container path changes between
    /// installs/updates) of the permanently-saved skeleton comparison PNG for
    /// this session's worst phase, inside `WeakPointImageStore.directory`.
    /// `nil` for older records or if persisting the image failed.
    let weakPointImageFile: String?

    init(id: UUID = UUID(), date: Date = Date(), mode: FormMode, score: Float,
         improvementSummary: String, componentScores: [Float]? = nil,
         weakPointImageFile: String? = nil) {
        self.id = id
        self.date = date
        self.mode = mode
        self.score = score
        self.improvementSummary = improvementSummary
        self.componentScores = componentScores
        self.weakPointImageFile = weakPointImageFile
    }
}
