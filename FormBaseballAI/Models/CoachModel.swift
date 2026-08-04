// CoachModel.swift — Ideal angle targets and tolerances for each FormMode.
// Mirrors: tfsapps.formbaseballai.model.CoachModel
//
// All values assume the user is standing FACING THE CAMERA (front view).
//  • Pitching: cocking phase — throwing elbow "L", both arms widest.
//  • Batting:  contact moment — bat roughly horizontal, hips rotated.
//
// References:
//   Pitching: ASMI (American Sports Medicine Institute) biomechanics.
//   Batting:  MLB swing-mechanics research / Driveline Baseball data.

import Foundation

struct CoachModel {

    // MARK: – Angle fields

    let rightElbowIdeal:       Float
    let rightElbowTolerance:   Float

    let leftElbowIdeal:        Float
    let leftElbowTolerance:    Float

    /// Tilt of the shoulder line from horizontal (degrees).
    let shoulderLevelIdeal:     Float
    let shoulderLevelTolerance: Float

    /// Tilt of the hip line from horizontal (degrees).
    let hipLevelIdeal:          Float
    let hipLevelTolerance:      Float

    /// Angle at the stride/lead knee; 180° = fully straight.
    let leadKneeIdeal:          Float
    let leadKneeTolerance:      Float

    // MARK: – Factory

    static func forMode(_ mode: FormMode) -> CoachModel {
        mode == .batting ? batting() : pitching()
    }

    // MARK: – Pitching (front-view, cocking phase)
    //
    //  Right elbow  : 85°  – throwing arm forms an "L"; ASMI optimal ~80-90°
    //  Left  elbow  : 100° – glove arm comfortably raised
    //  Shoulder tilt: 0°   – level during windup / cocking
    //  Hip tilt     : 0°   – level
    //  Lead knee    : 145° – slight flex at stride foot plant (~35° bend)
    private static func pitching() -> CoachModel {
        CoachModel(
            rightElbowIdeal: 85, rightElbowTolerance: 22,
            leftElbowIdeal: 100, leftElbowTolerance: 25,
            shoulderLevelIdeal: 0,  shoulderLevelTolerance: 18,
            hipLevelIdeal: 0,       hipLevelTolerance: 18,
            leadKneeIdeal: 145,     leadKneeTolerance: 25
        )
    }

    // MARK: – Batting (front-view, moment of contact)
    //
    //  Right elbow  : 90°   – back-arm "power L" at contact
    //  Left  elbow  : 155°  – front arm nearly extended at impact
    //  Shoulder tilt: -8°   – slight downward tilt toward strike zone
    //  Hip tilt     : 0°    – level
    //  Lead knee    : 158°  – front leg mostly extended on drive through
    private static func batting() -> CoachModel {
        CoachModel(
            rightElbowIdeal: 90,  rightElbowTolerance: 22,
            leftElbowIdeal: 155,  leftElbowTolerance: 25,
            shoulderLevelIdeal: -8, shoulderLevelTolerance: 18,
            hipLevelIdeal: 0,       hipLevelTolerance: 18,
            leadKneeIdeal: 158,     leadKneeTolerance: 22
        )
    }

    // MARK: – Indexed access (for scoring loop)

    func ideal(at index: Int) -> Float {
        switch index {
        case 0: return rightElbowIdeal
        case 1: return leftElbowIdeal
        case 2: return shoulderLevelIdeal
        case 3: return hipLevelIdeal
        case 4: return leadKneeIdeal
        default: return 0
        }
    }

    func tolerance(at index: Int) -> Float {
        switch index {
        case 0: return rightElbowTolerance
        case 1: return leftElbowTolerance
        case 2: return shoulderLevelTolerance
        case 3: return hipLevelTolerance
        case 4: return leadKneeTolerance
        default: return 15
        }
    }
}
