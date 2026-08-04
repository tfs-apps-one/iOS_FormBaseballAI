// FormMode.swift — Training mode enumeration
// Mirrors: tfsapps.formbaseballai.model.FormMode

import Foundation

enum FormMode: String, CaseIterable, Codable {
    case pitching
    case batting

    var localizedName: String {
        switch self {
        case .pitching: return NSLocalizedString("btn_pitching", comment: "")
        case .batting:  return NSLocalizedString("btn_batting",  comment: "")
        }
    }
}
