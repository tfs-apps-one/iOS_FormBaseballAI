// PracticeRecordStore.swift — Persists the last 30 diagnosis results
// (score + weak-point summary + per-component scores) so the "練習記録"
// screen can list and graph them.
// Mirrors: tfsapps.formbaseballai.history.HistoryManager
//
// 記録自体は無料ユーザーでも最大 30 件保存し続ける。無料プランで「見せる」のは
// 直近 freeVisibleLimit 件だけ（ソフトペイウォール）なので、後からアップグレード
// すればすぐに全件を確認できる。

import Foundation
import Combine

final class PracticeRecordStore: ObservableObject {

    static let shared = PracticeRecordStore()

    /// Newest record first — matches the order shown in the list screen.
    @Published private(set) var records: [PracticeRecord] = []

    /// Practice history keeps only the most recent N diagnoses; older ones
    /// are dropped automatically as new ones are added.
    static let maxRecords = 30

    /// 無料プランでユーザーに見せる直近の記録件数。
    static let freeVisibleLimit = 3

    private let storageKey = "practiceRecords"
    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    // MARK: - Queries

    /// 無料プランでは直近 freeVisibleLimit 件のみ、プレミアムでは最大 maxRecords 件を返す。
    func visibleRecords(isPremium: Bool) -> [PracticeRecord] {
        if !isPremium && records.count > Self.freeVisibleLimit {
            return Array(records.prefix(Self.freeVisibleLimit))
        }
        return records
    }

    /// 無料プランの上限を超えて、実際にロックされている記録があるかどうか。
    func hasLockedRecords(isPremium: Bool) -> Bool {
        !isPremium && records.count > Self.freeVisibleLimit
    }

    /// 同じモードの直近の記録（今回を保存する「前」に呼ぶと「前回」になる）。
    func latestRecord(for mode: FormMode) -> PracticeRecord? {
        records.first { $0.mode == mode }
    }

    // MARK: - Mutating

    /// Call once per completed diagnosis (see CameraView, right after a
    /// MultiFrameResult is built).
    func add(_ record: PracticeRecord) {
        records.insert(record, at: 0)
        if records.count > Self.maxRecords {
            // 保存上限から押し出された記録の画像も消す（参照されない PNG が溜まり続けないように）
            for dropped in records[Self.maxRecords...] {
                WeakPointImageStore.delete(dropped.weakPointImageFile)
            }
            records.removeLast(records.count - Self.maxRecords)
        }
        save()
    }

    #if DEBUG
    func debugClear() {
        records.forEach { WeakPointImageStore.delete($0.weakPointImageFile) }
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
