// AppColors.swift — 課金・お知らせ系の UI で共通に使う色（Android の colors.xml / drawable に対応）。

import SwiftUI

enum AppColors {
    /// ピッチング（#228B22）
    static let pitching = Color(red: 0.133, green: 0.545, blue: 0.133)
    /// バッティング（#D35400）
    static let batting  = Color(red: 0.827, green: 0.329, blue: 0)
    /// プレミアムのゴールド（#FFD700）
    static let gold     = Color(red: 1, green: 0.843, blue: 0)
    /// ダイアログ・上部お知らせの水色の外枠（#00E5FF）
    static let cyan     = Color(red: 0, green: 0.898, blue: 1)
    /// 良い変化（#00E676）
    static let good     = Color(red: 0, green: 0.902, blue: 0.463)
    /// 悪い変化（#EF5350）
    static let bad      = Color(red: 0.937, green: 0.325, blue: 0.314)
    /// 画面背景（#141414）
    static let background = Color(red: 0.078, green: 0.078, blue: 0.078)
    /// カード背景（#1E1E1E 相当）
    static let card     = Color.white.opacity(0.06)

    static func mode(_ mode: FormMode) -> Color {
        mode == .pitching ? pitching : batting
    }

    /// 前回差の色: +緑 / −赤 / ±0 は neutral
    static func delta(_ delta: Int, neutral: Color = Color.white.opacity(0.8)) -> Color {
        delta > 0 ? good : (delta < 0 ? bad : neutral)
    }
}
