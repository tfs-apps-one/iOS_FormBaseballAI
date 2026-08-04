// SkeletonRenderer.swift — Renders a static skeleton-comparison image to UIImage.
// Mirrors: tfsapps.formbaseballai.camera.SkeletonBitmapRenderer
//
// Produces a 540×720 PNG showing:
//   🟢 GREEN  — user's actual pose
//   🔵 CYAN   — coach's ideal form (corrected endpoints)
//   Reference axes, angle labels, legend, phase badge.

import UIKit
import MLKitPoseDetectionCommon

enum SkeletonRenderer {

    // MARK: – Bitmap dimensions
    private static let bmpW: CGFloat = 540
    private static let bmpH: CGFloat = 720

    // MARK: – Skeleton connections
    private static let connections: [(PoseLandmarkType, PoseLandmarkType)] = [
        (.leftShoulder,  .rightShoulder),
        (.leftShoulder,  .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip,       .rightHip),
        (.leftShoulder,  .leftElbow),
        (.leftElbow,     .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow,    .rightWrist),
        (.leftHip,       .leftKnee),
        (.leftKnee,      .leftAnkle),
        (.rightHip,      .rightKnee),
        (.rightKnee,     .rightAnkle),
        (.leftShoulder,  .nose),
        (.rightShoulder, .nose)
    ]

    // MARK: – Public entry point

    /// Renders skeleton comparison and saves to a temp file. Returns the file path.
    static func render(capturePose: CapturePose, mode: FormMode,
                        phaseNumber: Int, phaseScore: Float) -> String? {
        let size = CGSize(width: bmpW, height: bmpH)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let context = ctx.cgContext
            draw(in: context, capturePose: capturePose, mode: mode,
                 phaseNumber: phaseNumber, phaseScore: phaseScore, size: size)
        }

        guard let data = image.pngData() else { return nil }
        // One file per phase so all 8 renders can coexist and be viewed independently.
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("phase_\(phaseNumber)_frame.png")
        try? data.write(to: url)
        return url.path
    }

    // MARK: – Drawing

    private static func draw(in ctx: CGContext, capturePose cp: CapturePose,
                              mode: FormMode, phaseNumber: Int, phaseScore: Float,
                              size: CGSize) {
        let sx = size.width  / CGFloat(cp.imageWidth)
        let sy = size.height / CGFloat(cp.imageHeight)
        let coach = CoachModel.forMode(mode)

        // Background
        UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        // Reference axes
        drawAxes(ctx: ctx, cp: cp, sx: sx, sy: sy, height: size.height)

        // Coach skeleton (behind user)
        drawCoachSkeleton(ctx: ctx, cp: cp, coach: coach, sx: sx, sy: sy)

        // User skeleton
        drawUserSkeleton(ctx: ctx, cp: cp, sx: sx, sy: sy)

        // Angle labels
        drawAngleLabels(ctx: ctx, cp: cp, sx: sx, sy: sy)

        // Phase badge
        drawPhaseBadge(phaseNumber: phaseNumber, phaseScore: phaseScore)

        // Legend
        drawLegend(size: size)
    }

    // MARK: – Reference axes

    private static func drawAxes(ctx: CGContext, cp: CapturePose,
                                   sx: CGFloat, sy: CGFloat, height: CGFloat) {
        // Vertical dashed axis through shoulder midpoint
        if let ls = scaled(cp, .leftShoulder,  sx, sy),
           let rs = scaled(cp, .rightShoulder, sx, sy) {
            let midX = (ls.x + rs.x) / 2
            let dashPaint = UIColor.cyan.withAlphaComponent(0.7)
            dashPaint.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: midX, y: 0))
            path.addLine(to: CGPoint(x: midX, y: height))
            path.lineWidth = 2
            let dashes: [CGFloat] = [14, 10]
            path.setLineDash(dashes, count: 2, phase: 0)
            path.stroke()

            // Shoulder horizontal
            let solidColor = UIColor.cyan.withAlphaComponent(0.63)
            solidColor.setStroke()
            let shLine = UIBezierPath()
            shLine.move(to: CGPoint(x: ls.x - 30, y: ls.y))
            shLine.addLine(to: CGPoint(x: rs.x + 30, y: rs.y))
            shLine.lineWidth = 2
            shLine.stroke()
        }

        // Hip horizontal
        if let lh = scaled(cp, .leftHip, sx, sy),
           let rh = scaled(cp, .rightHip, sx, sy) {
            UIColor.cyan.withAlphaComponent(0.63).setStroke()
            let line = UIBezierPath()
            line.move(to: CGPoint(x: lh.x - 30, y: lh.y))
            line.addLine(to: CGPoint(x: rh.x + 30, y: rh.y))
            line.lineWidth = 2
            line.stroke()
        }
    }

    // MARK: – User skeleton

    private static func drawUserSkeleton(ctx: CGContext, cp: CapturePose,
                                          sx: CGFloat, sy: CGFloat) {
        let boneColor = UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1) // #00E676
        boneColor.setStroke()

        for (typeA, typeB) in connections {
            guard let p1 = scaled(cp, typeA, sx, sy),
                  let p2 = scaled(cp, typeB, sx, sy) else { continue }
            let path = UIBezierPath()
            path.move(to: p1)
            path.addLine(to: p2)
            path.lineWidth = 6
            path.lineCapStyle = .round
            path.stroke()
        }

        UIColor.white.setFill()
        for (i, _) in allPoseLandmarkTypes.enumerated() {
            guard i < cp.x.count, !cp.x[i].isNaN else { continue }
            let pt = CGPoint(x: CGFloat(cp.x[i]) * sx, y: CGFloat(cp.y[i]) * sy)
            UIBezierPath(arcCenter: pt, radius: 9, startAngle: 0, endAngle: .pi * 2,
                         clockwise: true).fill()
        }
    }

    // MARK: – Coach skeleton

    private static func drawCoachSkeleton(ctx: CGContext, cp: CapturePose,
                                           coach: CoachModel, sx: CGFloat, sy: CGFloat) {
        let boneColor = UIColor(red: 0.149, green: 0.776, blue: 0.855, alpha: 0.863) // #26C6DA
        boneColor.setStroke()

        let lS = scaled(cp, .leftShoulder,  sx, sy)
        let rS = scaled(cp, .rightShoulder, sx, sy)
        let lH = scaled(cp, .leftHip,       sx, sy)
        let rH = scaled(cp, .rightHip,      sx, sy)
        let nose = scaled(cp, .nose,         sx, sy)

        // Torso (anchored)
        coachLine(lS, rS, boneColor)
        coachLine(lS, lH, boneColor)
        coachLine(rS, rH, boneColor)
        coachLine(lH, rH, boneColor)
        coachLine(lS, nose, boneColor)
        coachLine(rS, nose, boneColor)

        // Right arm
        let rE  = scaled(cp, .rightElbow, sx, sy)
        let rW  = scaled(cp, .rightWrist, sx, sy)
        let crW = coachEndpoint(a: rS, b: rE, cActual: rW, idealDeg: coach.rightElbowIdeal)
        coachLine(rS, rE, boneColor)
        coachLine(rE, crW, boneColor)
        if let p = crW { UIBezierPath(arcCenter: p, radius: 13, startAngle: 0, endAngle: .pi * 2,
                                      clockwise: true).fill() }

        // Left arm
        let lE  = scaled(cp, .leftElbow, sx, sy)
        let lW  = scaled(cp, .leftWrist, sx, sy)
        let clW = coachEndpoint(a: lS, b: lE, cActual: lW, idealDeg: coach.leftElbowIdeal)
        coachLine(lS, lE, boneColor)
        coachLine(lE, clW, boneColor)
        if let p = clW { UIBezierPath(arcCenter: p, radius: 13, startAngle: 0, endAngle: .pi * 2,
                                      clockwise: true).fill() }

        // Lead leg (left)
        let lK  = scaled(cp, .leftKnee,  sx, sy)
        let lA  = scaled(cp, .leftAnkle, sx, sy)
        let clA = coachEndpoint(a: lH, b: lK, cActual: lA, idealDeg: coach.leadKneeIdeal)
        coachLine(lH, lK, boneColor)
        coachLine(lK, clA, boneColor)
        if let p = clA { UIBezierPath(arcCenter: p, radius: 13, startAngle: 0, endAngle: .pi * 2,
                                      clockwise: true).fill() }

        // Trail leg (right, no correction)
        let rK  = scaled(cp, .rightKnee,  sx, sy)
        let rA  = scaled(cp, .rightAnkle, sx, sy)
        coachLine(rH, rK, boneColor)
        coachLine(rK, rA, boneColor)
    }

    private static func coachLine(_ a: CGPoint?, _ b: CGPoint?, _ color: UIColor) {
        guard let a, let b else { return }
        color.setStroke()
        let p = UIBezierPath()
        p.move(to: a); p.addLine(to: b)
        p.lineWidth = 5; p.lineCapStyle = .round; p.stroke()
    }

    // MARK: – Angle labels

    private static func drawAngleLabels(ctx: CGContext, cp: CapturePose,
                                         sx: CGFloat, sy: CGFloat) {
        let arcColor  = UIColor(red: 1, green: 0.596, blue: 0, alpha: 1) // #FF9800
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor(red: 1, green: 0.922, blue: 0.231, alpha: 1) // #FFEB3B
        ]

        // Right elbow
        drawJointLabel(cp: cp, sx: sx, sy: sy,
                       a: .rightShoulder, b: .rightElbow, c: .rightWrist,
                       name: NSLocalizedString("label_right_elbow", comment: ""),
                       onRight: true, arcColor: arcColor, textAttrs: textAttrs)

        // Left elbow
        drawJointLabel(cp: cp, sx: sx, sy: sy,
                       a: .leftShoulder, b: .leftElbow, c: .leftWrist,
                       name: NSLocalizedString("label_left_elbow", comment: ""),
                       onRight: false, arcColor: arcColor, textAttrs: textAttrs)

        // Shoulder tilt
        if let ls = scaled(cp, .leftShoulder, sx, sy),
           let rs = scaled(cp, .rightShoulder, sx, sy) {
            let ang = atan2(rs.y - ls.y, rs.x - ls.x) * 180 / .pi
            let text = String(format: "%@ %.1f°",
                              NSLocalizedString("label_shoulder_level", comment: ""), ang)
            drawFloatingLabel(text: text, x: rs.x + 12, y: rs.y - 52, textAttrs: textAttrs)
        }

        // Hip tilt
        if let lh = scaled(cp, .leftHip, sx, sy),
           let rh = scaled(cp, .rightHip, sx, sy) {
            let ang = atan2(rh.y - lh.y, rh.x - lh.x) * 180 / .pi
            let text = String(format: "%@ %.1f°",
                              NSLocalizedString("label_hip_level", comment: ""), ang)
            drawFloatingLabel(text: text, x: lh.x - 200, y: lh.y + 36, textAttrs: textAttrs)
        }
    }

    private static func drawJointLabel(cp: CapturePose, sx: CGFloat, sy: CGFloat,
                                        a typeA: PoseLandmarkType,
                                        b typeB: PoseLandmarkType,
                                        c typeC: PoseLandmarkType,
                                        name: String, onRight: Bool,
                                        arcColor: UIColor,
                                        textAttrs: [NSAttributedString.Key: Any]) {
        guard let a = scaled(cp, typeA, sx, sy),
              let b = scaled(cp, typeB, sx, sy),
              let c = scaled(cp, typeC, sx, sy) else { return }

        let angle = angleBetween(a, b, c)
        let text  = String(format: "%@ %.0f°", name, angle)

        // Draw arc at joint
        let r: CGFloat = 28
        let startDeg   = atan2(a.y - b.y, a.x - b.x) * 180 / .pi
        arcColor.setStroke()
        let arc = UIBezierPath(arcCenter: b, radius: r,
                               startAngle: startDeg * .pi / 180,
                               endAngle: (startDeg + min(angle, 160)) * .pi / 180,
                               clockwise: true)
        arc.lineWidth = 3; arc.stroke()

        let lx = onRight ? b.x + 18 : b.x - 240
        drawFloatingLabel(text: text, x: lx, y: b.y - 10, textAttrs: textAttrs)
    }

    private static func drawFloatingLabel(text: String, x: CGFloat, y: CGFloat,
                                           textAttrs: [NSAttributedString.Key: Any]) {
        let ns   = text as NSString
        let size = ns.size(withAttributes: textAttrs)
        let pad: CGFloat = 10
        let bgRect = CGRect(x: x - pad, y: y - size.height,
                            width: size.width + pad * 2, height: size.height + pad)
        UIColor.black.withAlphaComponent(0.8).setFill()
        UIBezierPath(roundedRect: bgRect, cornerRadius: 8).fill()
        ns.draw(at: CGPoint(x: x, y: y - size.height), withAttributes: textAttrs)
    }

    // MARK: – Phase badge

    private static func drawPhaseBadge(phaseNumber: Int, phaseScore: Float) {
        let color = scoreColor(phaseScore)
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 38),
            .foregroundColor: UIColor.black
        ]
        let line1 = "Phase \(phaseNumber)" as NSString
        let line2 = String(format: "Score %.0f", phaseScore) as NSString
        let s1    = line1.size(withAttributes: textAttrs)
        let s2    = line2.size(withAttributes: textAttrs)
        let pad: CGFloat = 14
        let boxW  = max(s1.width, s2.width) + pad * 2
        let boxH  = 38 * 2 + pad * 3
        color.withAlphaComponent(0.863).setFill()
        UIBezierPath(roundedRect: CGRect(x: 16, y: 16, width: boxW, height: boxH),
                     cornerRadius: 12).fill()
        line1.draw(at: CGPoint(x: 16 + pad, y: 16 + pad), withAttributes: textAttrs)
        line2.draw(at: CGPoint(x: 16 + pad, y: 16 + pad * 2 + 38), withAttributes: textAttrs)
    }

    // MARK: – Legend

    private static func drawLegend(size: CGSize) {
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 30),
            .foregroundColor: UIColor.white
        ]
        let youStr:   NSString = "You"
        let coachStr: NSString = "Coach"
        let s1 = youStr.size(withAttributes: textAttrs)
        let s2 = coachStr.size(withAttributes: textAttrs)
        let lineLen: CGFloat = 36, pad: CGFloat = 12, rowH: CGFloat = 30 + 10
        let boxW = pad + lineLen + 8 + max(s1.width, s2.width) + pad
        let boxH = pad + rowH + rowH + pad
        let right: CGFloat = size.width - 16
        let top: CGFloat   = 24
        let left           = right - boxW

        UIColor.black.withAlphaComponent(0.8).setFill()
        UIBezierPath(roundedRect: CGRect(x: left, y: top, width: boxW, height: boxH),
                     cornerRadius: 10).fill()

        let r1y = top + pad + 30
        UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1).setStroke()
        let gl = UIBezierPath(); gl.move(to: CGPoint(x: left + pad, y: r1y - 15))
        gl.addLine(to: CGPoint(x: left + pad + lineLen, y: r1y - 15))
        gl.lineWidth = 4; gl.lineCapStyle = .round; gl.stroke()
        youStr.draw(at: CGPoint(x: left + pad + lineLen + 8, y: r1y - 30), withAttributes: textAttrs)

        let r2y = r1y + rowH
        UIColor(red: 0.149, green: 0.776, blue: 0.855, alpha: 1).setStroke()
        let cl = UIBezierPath(); cl.move(to: CGPoint(x: left + pad, y: r2y - 15))
        cl.addLine(to: CGPoint(x: left + pad + lineLen, y: r2y - 15))
        cl.lineWidth = 4; cl.lineCapStyle = .round; cl.stroke()
        let cAttrs = textAttrs.merging([.foregroundColor: UIColor(red: 0.149, green: 0.776, blue: 0.855, alpha: 1)]) { $1 }
        coachStr.draw(at: CGPoint(x: left + pad + lineLen + 8, y: r2y - 30), withAttributes: cAttrs)
    }

    // MARK: – Geometry helpers

    private static func scaled(_ cp: CapturePose, _ type: PoseLandmarkType,
                                 _ sx: CGFloat, _ sy: CGFloat) -> CGPoint? {
        guard let p = cp.point(type) else { return nil }
        return CGPoint(x: p.x * sx, y: p.y * sy)
    }

    static func angleBetween(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        let bax = a.x - b.x, bay = a.y - b.y
        let bcx = c.x - b.x, bcy = c.y - b.y
        let dot   = bax * bcx + bay * bcy
        let magBA = sqrt(bax * bax + bay * bay)
        let magBC = sqrt(bcx * bcx + bcy * bcy)
        guard magBA > 1e-6, magBC > 1e-6 else { return 0 }
        return acos(max(-1, min(1, dot / (magBA * magBC)))) * 180 / .pi
    }

    /// Computes ideal endpoint C so that angle at B = idealDeg.
    static func coachEndpoint(a: CGPoint?, b: CGPoint?,
                               cActual: CGPoint?, idealDeg: Float) -> CGPoint? {
        guard let a, let b else { return nil }
        let abAngle = atan2(b.y - a.y, b.x - a.x)
        let bcLen:       CGFloat
        let actualBCAngle: CGFloat
        if let c = cActual {
            let dx = c.x - b.x, dy = c.y - b.y
            bcLen        = sqrt(dx * dx + dy * dy)
            actualBCAngle = atan2(dy, dx)
        } else {
            let dx = b.x - a.x, dy = b.y - a.y
            bcLen        = sqrt(dx * dx + dy * dy)
            actualBCAngle = abAngle + .pi * 0.75
        }
        let baAngle  = abAngle + .pi
        let idealRad = CGFloat(idealDeg) * .pi / 180
        let c1 = baAngle + idealRad
        let c2 = baAngle - idealRad
        let chosen = angDiff(c1, actualBCAngle) <= angDiff(c2, actualBCAngle) ? c1 : c2
        return CGPoint(x: b.x + bcLen * cos(chosen), y: b.y + bcLen * sin(chosen))
    }

    private static func angDiff(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let d = abs(a - b).truncatingRemainder(dividingBy: .pi * 2)
        return d > .pi ? .pi * 2 - d : d
    }

    static func scoreColor(_ score: Float) -> UIColor {
        if score >= 70 { return UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1) }
        if score >= 45 { return UIColor(red: 1, green: 0.792, blue: 0.157, alpha: 1) }
        return UIColor(red: 0.937, green: 0.325, blue: 0.314, alpha: 1)
    }
}
