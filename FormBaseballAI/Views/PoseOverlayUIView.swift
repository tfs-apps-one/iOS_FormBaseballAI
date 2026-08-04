// PoseOverlayUIView.swift — AR overlay drawing two skeletons over the camera preview.
// Mirrors: tfsapps.formbaseballai.camera.PoseOverlayView
//
//   🟢 GREEN  = user's actual detected pose (ML Kit landmarks)
//   🔵 CYAN   = coach's ideal form (corrected wrist/ankle endpoints)
//   Reference axes, angle arc labels, legend.

import UIKit
import MLKitPoseDetectionCommon
import MLKitVision

final class PoseOverlayUIView: UIView {

    // MARK: – State

    private var pose:        Pose?
    private var imageWidth:  Int = 1
    private var imageHeight: Int = 1
    private var coachModel   = CoachModel.forMode(.pitching)
    private var mode: FormMode = .pitching

    // MARK: – Public API

    func setMode(_ mode: FormMode) {
        self.mode       = mode
        self.coachModel = CoachModel.forMode(mode)
        setNeedsDisplay()
    }

    func setPose(_ pose: Pose, imageWidth: Int, imageHeight: Int) {
        self.pose        = pose
        self.imageWidth  = max(imageWidth,  1)
        self.imageHeight = max(imageHeight, 1)
        setNeedsDisplay()
    }

    func clearPose() {
        self.pose = nil
        setNeedsDisplay()
    }

    // MARK: – Drawing

    override func draw(_ rect: CGRect) {
        guard let pose, !pose.landmarks.isEmpty else { return }

        let vw = bounds.width, vh = bounds.height
        let sx = vw / CGFloat(imageWidth)
        let sy = vh / CGFloat(imageHeight)

        // 1. Reference axes
        drawVerticalAxis(sx: sx, sy: sy, vh: vh)
        drawHorizontalRefLines(sx: sx, sy: sy)

        // 2. Coach skeleton (behind user)
        drawCoachSkeleton(sx: sx, sy: sy)

        // 3. User skeleton
        drawUserSkeleton(sx: sx, sy: sy)

        // 4. Angle labels
        drawAngleLabels(sx: sx, sy: sy)

        // 5. Legend
        drawLegend(vw: vw)
    }

    // MARK: – Reference axes

    private func drawVerticalAxis(sx: CGFloat, sy: CGFloat, vh: CGFloat) {
        guard let mid = midPoint(.leftShoulder, .rightShoulder, sx: sx, sy: sy) else { return }
        let path = UIBezierPath()
        path.move(to: CGPoint(x: mid.x, y: 0))
        path.addLine(to: CGPoint(x: mid.x, y: vh))
        path.lineWidth = 1.5
        path.setLineDash([10, 8], count: 2, phase: 0)
        UIColor.cyan.withAlphaComponent(0.6).setStroke()
        path.stroke()
    }

    private func drawHorizontalRefLines(sx: CGFloat, sy: CGFloat) {
        let solidColor = UIColor.cyan.withAlphaComponent(0.55)
        solidColor.setStroke()

        if let ls = scaledLM(.leftShoulder, sx: sx, sy: sy),
           let rs = scaledLM(.rightShoulder, sx: sx, sy: sy) {
            let p = UIBezierPath()
            p.move(to: CGPoint(x: ls.x - 20, y: ls.y))
            p.addLine(to: CGPoint(x: rs.x + 20, y: rs.y))
            p.lineWidth = 1.5; p.stroke()
        }
        if let lh = scaledLM(.leftHip, sx: sx, sy: sy),
           let rh = scaledLM(.rightHip, sx: sx, sy: sy) {
            let p = UIBezierPath()
            p.move(to: CGPoint(x: lh.x - 20, y: lh.y))
            p.addLine(to: CGPoint(x: rh.x + 20, y: rh.y))
            p.lineWidth = 1.5; p.stroke()
        }
    }

    // MARK: – User skeleton

    private static let connections: [(PoseLandmarkType, PoseLandmarkType)] = [
        (.leftShoulder, .rightShoulder), (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),    (.leftHip, .rightHip),
        (.leftShoulder, .leftElbow),    (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),  (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee),          (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),        (.rightKnee, .rightAnkle),
        (.leftShoulder, .nose),         (.rightShoulder, .nose)
    ]

    private let minConf: Float = 0.4

    private func drawUserSkeleton(sx: CGFloat, sy: CGFloat) {
        let boneColor = UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1)
        boneColor.setStroke()

        for (typeA, typeB) in Self.connections {
            guard let p1 = scaledLM(typeA, sx: sx, sy: sy),
                  let p2 = scaledLM(typeB, sx: sx, sy: sy) else { continue }
            let path = UIBezierPath()
            path.move(to: p1); path.addLine(to: p2)
            path.lineWidth = 3; path.lineCapStyle = .round; path.stroke()
        }

        // Draw joint dots
        UIColor.white.setFill()
        for type in allPoseLandmarkTypes {
            guard let p = scaledLM(type, sx: sx, sy: sy) else { continue }
            UIBezierPath(arcCenter: p, radius: 4, startAngle: 0, endAngle: .pi * 2,
                         clockwise: true).fill()
        }
    }

    // MARK: – Coach skeleton

    private func drawCoachSkeleton(sx: CGFloat, sy: CGFloat) {
        let cyanColor = UIColor(red: 0.149, green: 0.776, blue: 0.855, alpha: 0.863)

        let lS   = scaledLM(.leftShoulder,  sx: sx, sy: sy)
        let rS   = scaledLM(.rightShoulder, sx: sx, sy: sy)
        let lH   = scaledLM(.leftHip,       sx: sx, sy: sy)
        let rH   = scaledLM(.rightHip,      sx: sx, sy: sy)
        let nose = scaledLM(.nose,          sx: sx, sy: sy)

        drawCoachLine(lS, rS, color: cyanColor)
        drawCoachLine(lS, lH, color: cyanColor)
        drawCoachLine(rS, rH, color: cyanColor)
        drawCoachLine(lH, rH, color: cyanColor)
        drawCoachLine(lS, nose, color: cyanColor)
        drawCoachLine(rS, nose, color: cyanColor)

        let rE  = scaledLM(.rightElbow, sx: sx, sy: sy)
        let rW  = scaledLM(.rightWrist, sx: sx, sy: sy)
        let crW = SkeletonRenderer.coachEndpoint(a: rS, b: rE, cActual: rW, idealDeg: coachModel.rightElbowIdeal)
        drawCoachLine(rS, rE, color: cyanColor)
        drawCoachLine(rE, crW, color: cyanColor)
        if let p = crW { cyanColor.setFill()
            UIBezierPath(arcCenter: p, radius: 6, startAngle: 0, endAngle: .pi*2, clockwise: true).fill() }

        let lE  = scaledLM(.leftElbow, sx: sx, sy: sy)
        let lW  = scaledLM(.leftWrist, sx: sx, sy: sy)
        let clW = SkeletonRenderer.coachEndpoint(a: lS, b: lE, cActual: lW, idealDeg: coachModel.leftElbowIdeal)
        drawCoachLine(lS, lE, color: cyanColor)
        drawCoachLine(lE, clW, color: cyanColor)
        if let p = clW { cyanColor.setFill()
            UIBezierPath(arcCenter: p, radius: 6, startAngle: 0, endAngle: .pi*2, clockwise: true).fill() }

        let lK  = scaledLM(.leftKnee,  sx: sx, sy: sy)
        let lA  = scaledLM(.leftAnkle, sx: sx, sy: sy)
        let clA = SkeletonRenderer.coachEndpoint(a: lH, b: lK, cActual: lA, idealDeg: coachModel.leadKneeIdeal)
        drawCoachLine(lH, lK, color: cyanColor)
        drawCoachLine(lK, clA, color: cyanColor)
        if let p = clA { cyanColor.setFill()
            UIBezierPath(arcCenter: p, radius: 6, startAngle: 0, endAngle: .pi*2, clockwise: true).fill() }

        let rK  = scaledLM(.rightKnee,  sx: sx, sy: sy)
        let rA  = scaledLM(.rightAnkle, sx: sx, sy: sy)
        drawCoachLine(rH, rK, color: cyanColor)
        drawCoachLine(rK, rA, color: cyanColor)
    }

    private func drawCoachLine(_ a: CGPoint?, _ b: CGPoint?, color: UIColor) {
        guard let a, let b else { return }
        color.setStroke()
        let p = UIBezierPath(); p.move(to: a); p.addLine(to: b)
        p.lineWidth = 2; p.lineCapStyle = .round; p.stroke()
    }

    // MARK: – Angle labels

    private func drawAngleLabels(sx: CGFloat, sy: CGFloat) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor(red: 1, green: 0.922, blue: 0.231, alpha: 1)
        ]
        let arcColor = UIColor(red: 1, green: 0.596, blue: 0, alpha: 1)

        drawJointAngleLabel(a: .rightShoulder, b: .rightElbow, c: .rightWrist,
                            name: NSLocalizedString("label_right_elbow", comment: ""),
                            onRight: true, sx: sx, sy: sy,
                            arcColor: arcColor, textAttrs: labelAttrs)
        drawJointAngleLabel(a: .leftShoulder, b: .leftElbow, c: .leftWrist,
                            name: NSLocalizedString("label_left_elbow", comment: ""),
                            onRight: false, sx: sx, sy: sy,
                            arcColor: arcColor, textAttrs: labelAttrs)

        if let ls = scaledLM(.leftShoulder, sx: sx, sy: sy),
           let rs = scaledLM(.rightShoulder, sx: sx, sy: sy) {
            let ang = atan2(rs.y - ls.y, rs.x - ls.x) * 180 / .pi
            drawFloatingLabel(text: String(format: "%@ %.1f°",
                                           NSLocalizedString("label_shoulder_level", comment: ""), ang),
                               x: rs.x + 8, y: rs.y - 24, attrs: labelAttrs)
        }
        if let lh = scaledLM(.leftHip, sx: sx, sy: sy),
           let rh = scaledLM(.rightHip, sx: sx, sy: sy) {
            let ang = atan2(rh.y - lh.y, rh.x - lh.x) * 180 / .pi
            drawFloatingLabel(text: String(format: "%@ %.1f°",
                                           NSLocalizedString("label_hip_level", comment: ""), ang),
                               x: lh.x - 160, y: lh.y + 18, attrs: labelAttrs)
        }
    }

    private func drawJointAngleLabel(a typeA: PoseLandmarkType,
                                      b typeB: PoseLandmarkType,
                                      c typeC: PoseLandmarkType,
                                      name: String, onRight: Bool,
                                      sx: CGFloat, sy: CGFloat,
                                      arcColor: UIColor,
                                      textAttrs: [NSAttributedString.Key: Any]) {
        guard let a = scaledLM(typeA, sx: sx, sy: sy),
              let b = scaledLM(typeB, sx: sx, sy: sy),
              let c = scaledLM(typeC, sx: sx, sy: sy) else { return }

        let angle   = SkeletonRenderer.angleBetween(a, b, c)
        let text    = String(format: "%@ %.0f°", name, angle)
        let r: CGFloat = 16
        let startDeg   = atan2(a.y - b.y, a.x - b.x) * 180 / .pi
        arcColor.setStroke()
        let arc = UIBezierPath(arcCenter: b, radius: r,
                               startAngle: startDeg * .pi / 180,
                               endAngle: (startDeg + min(angle, 160)) * .pi / 180,
                               clockwise: true)
        arc.lineWidth = 2; arc.stroke()

        let lx = onRight ? b.x + 10 : b.x - 180
        drawFloatingLabel(text: text, x: lx, y: b.y - 6, attrs: textAttrs)
    }

    private func drawFloatingLabel(text: String, x: CGFloat, y: CGFloat,
                                    attrs: [NSAttributedString.Key: Any]) {
        let ns   = text as NSString
        let size = ns.size(withAttributes: attrs)
        let pad: CGFloat = 5
        let bg = CGRect(x: x - pad, y: y - size.height, width: size.width + pad * 2, height: size.height + pad)
        UIColor.black.withAlphaComponent(0.75).setFill()
        UIBezierPath(roundedRect: bg, cornerRadius: 5).fill()
        ns.draw(at: CGPoint(x: x, y: y - size.height), withAttributes: attrs)
    }

    // MARK: – Legend

    private func drawLegend(vw: CGFloat) {
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.white
        ]
        let youLabel   = NSLocalizedString("legend_you",   comment: "") as NSString
        let coachLabel = NSLocalizedString("legend_coach", comment: "") as NSString
        let s1 = youLabel.size(withAttributes: textAttrs)
        let s2 = coachLabel.size(withAttributes: textAttrs)
        let lineLen: CGFloat = 20, pad: CGFloat = 8, rowH: CGFloat = 22
        let boxW  = pad + lineLen + 6 + max(s1.width, s2.width) + pad
        let boxH  = pad + rowH + rowH + pad
        let right = vw - 12, top: CGFloat = 16
        let left  = right - boxW

        UIColor.black.withAlphaComponent(0.75).setFill()
        UIBezierPath(roundedRect: CGRect(x: left, y: top, width: boxW, height: boxH),
                     cornerRadius: 8).fill()

        let r1y = top + pad + rowH * 0.75
        UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1).setStroke()
        let gl = UIBezierPath(); gl.move(to: CGPoint(x: left + pad, y: r1y))
        gl.addLine(to: CGPoint(x: left + pad + lineLen, y: r1y))
        gl.lineWidth = 3; gl.lineCapStyle = .round; gl.stroke()
        youLabel.draw(at: CGPoint(x: left + pad + lineLen + 6, y: r1y - s1.height * 0.5), withAttributes: textAttrs)

        let r2y = r1y + rowH
        UIColor(red: 0.149, green: 0.776, blue: 0.855, alpha: 1).setStroke()
        let cl = UIBezierPath(); cl.move(to: CGPoint(x: left + pad, y: r2y))
        cl.addLine(to: CGPoint(x: left + pad + lineLen, y: r2y))
        cl.lineWidth = 3; cl.lineCapStyle = .round; cl.stroke()
        let cAttrs = textAttrs.merging([.foregroundColor: UIColor(red: 0.149, green: 0.776, blue: 0.855, alpha: 1)]) { $1 }
        coachLabel.draw(at: CGPoint(x: left + pad + lineLen + 6, y: r2y - s2.height * 0.5), withAttributes: cAttrs)
    }

    // MARK: – Helpers

    private func scaledLM(_ type: PoseLandmarkType, sx: CGFloat, sy: CGFloat) -> CGPoint? {
        guard let pose else { return nil }
        let lm = pose.landmark(ofType: type)
        guard lm.inFrameLikelihood >= minConf else { return nil }
        return CGPoint(x: lm.position.x * sx, y: lm.position.y * sy)
    }

    private func midPoint(_ typeA: PoseLandmarkType, _ typeB: PoseLandmarkType,
                           sx: CGFloat, sy: CGFloat) -> CGPoint? {
        guard let a = scaledLM(typeA, sx: sx, sy: sy),
              let b = scaledLM(typeB, sx: sx, sy: sy) else { return nil }
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
