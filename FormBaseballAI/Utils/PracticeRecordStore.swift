// PracticeRecordStore.swift — Persists the last 30 diagnosis results
// (score + weak-point summary) so the "練習記録" screen can list and
// graph them.
// Mirrors: tfsapps.formbaseballai.practice.PracticeRecordStore

import Foundation
import Combine

final class PracticeRecordStore: ObservableObject {

    static let shared = PracticeRecordStore()

    /// Newest record first — matches the order shown in the list screen.
    @Published private(set) var records: [PracticeRecord] = []

    /// Practice history keeps only the most recent N diagnoses; older ones
    /// are dropped automatically as new ones are added.
    private let maxRecords = 30

    private let storageKey = "practiceRecords"
    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    // MARK: - Mutating

    /// Call once per completed diagnosis (see CameraView, right after a
    /// MultiFrameResult is built).
    func add(mode: FormMode, score: Float, improvementSummary: String) {
        let record = PracticeRecord(mode: mode, score: score, improvementSummary: improvementSummary)
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records.removeLast(records.count - maxRecords)
        }
        save()
    }

    #if DEBUG
    func debugClear() {
        records.removeAll()
        save()
    }
    #endif

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PracticeRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
