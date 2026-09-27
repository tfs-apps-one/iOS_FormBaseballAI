// WeakPointImageStore.swift — ワーストフェーズのスケルトン比較画像を永続保存する。
// Mirrors: ResultActivity#persistWeakPointImage() / HistoryManager#deleteWeakPointImage()
//
// SkeletonRenderer は一時ディレクトリに phase_N_frame.png を書き出し、次の録画で
// 上書きされる。ウィークポイント傾向の画面で後から見返せるよう、診断ごとに
// Application Support/weakpoint_images/ へコピーしておく。
//
// 記録にはファイル名だけを保存する（iOS はアプリ更新・再インストールで
// コンテナの絶対パスが変わるため、フルパスを保存すると後で読めなくなる）。

import Foundation

enum WeakPointImageStore {

    static var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("weakpoint_images", isDirectory: true)
    }

    /// 一時ファイルを永続領域へコピーし、保存したファイル名を返す。失敗時は nil
    /// （記録側は画像なしとして扱う）。
    static func persist(sourcePath: String?) -> String? {
        guard let sourcePath, FileManager.default.fileExists(atPath: sourcePath),
              let dir = directory else { return nil }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let name = "wp_\(Int64(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8)).png"
            try FileManager.default.copyItem(at: URL(fileURLWithPath: sourcePath),
                                             to: dir.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    static func url(for fileName: String?) -> URL? {
        guard let fileName, let dir = directory else { return nil }
        let url = dir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func delete(_ fileName: String?) {
        guard let url = url(for: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
