import SwiftUI
import HealthCore

// 인체 인포그래픽용 단순 도형. 모든 좌표는 1000×1000 설계 공간 기준.

/// 장기 모양. 주어진 사각형 안에 0~1 비율 좌표로 그림.
nonisolated struct OrganGlyph: Shape {
    let organ: Organ

    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: r.minX + x * r.width, y: r.minY + y * r.height, width: w * r.width, height: h * r.height)
        }
        var path = Path()

        switch organ {
        case .brainVessel:
            // 좌우 반구 + 뇌간
            path.addEllipse(in: box(0, 0, 0.49, 0.88))
            path.addEllipse(in: box(0.51, 0, 0.49, 0.88))
            path.addRoundedRect(in: box(0.43, 0.70, 0.14, 0.30), cornerSize: CGSize(width: 0.05 * r.width, height: 0.05 * r.width))

        case .lung:
            // 기관 + 좌우 폐
            path.addRoundedRect(in: box(0.465, 0, 0.07, 0.34), cornerSize: CGSize(width: 0.02 * r.width, height: 0.02 * r.width))
            for mirror in [false, true] {
                func q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { p(mirror ? 1 - x : x, y) }
                var lobe = Path()
                lobe.move(to: q(0.40, 0.10))
                lobe.addQuadCurve(to: q(0.03, 0.82), control: q(0.04, 0.16))
                lobe.addQuadCurve(to: q(0.44, 0.96), control: q(0.05, 1.04))
                lobe.addLine(to: q(0.44, 0.32))
                lobe.closeSubpath()
                path.addPath(lobe)
            }

        case .heart:
            path.move(to: p(0.5, 0.98))
            path.addCurve(to: p(0.02, 0.32), control1: p(0.18, 0.75), control2: p(0.0, 0.55))
            path.addCurve(to: p(0.5, 0.22), control1: p(0.04, 0.0), control2: p(0.42, 0.0))
            path.addCurve(to: p(0.98, 0.32), control1: p(0.58, 0.0), control2: p(0.96, 0.0))
            path.addCurve(to: p(0.5, 0.98), control1: p(1.0, 0.55), control2: p(0.82, 0.75))
            path.closeSubpath()

        case .liver:
            path.move(to: p(0.02, 0.30))
            path.addCurve(to: p(0.70, 0.02), control1: p(0.15, 0.05), control2: p(0.45, 0.0))
            path.addCurve(to: p(1.0, 0.12), control1: p(0.85, 0.03), control2: p(0.98, 0.05))
            path.addCurve(to: p(0.55, 0.62), control1: p(1.0, 0.30), control2: p(0.75, 0.50))
            path.addCurve(to: p(0.15, 0.98), control1: p(0.35, 0.75), control2: p(0.25, 0.98))
            path.addCurve(to: p(0.02, 0.30), control1: p(0.0, 0.95), control2: p(-0.02, 0.55))
            path.closeSubpath()

        case .stomach:
            path.move(to: p(0.22, 0.0))
            path.addLine(to: p(0.42, 0.0))
            path.addCurve(to: p(0.96, 0.45), control1: p(0.46, 0.22), control2: p(0.96, 0.12))
            path.addCurve(to: p(0.45, 0.98), control1: p(0.96, 0.80), control2: p(0.72, 0.98))
            path.addCurve(to: p(0.0, 0.84), control1: p(0.22, 0.98), control2: p(0.0, 0.94))
            path.addCurve(to: p(0.30, 0.74), control1: p(0.04, 0.72), control2: p(0.18, 0.78))
            path.addCurve(to: p(0.55, 0.50), control1: p(0.46, 0.70), control2: p(0.58, 0.62))
            path.addCurve(to: p(0.22, 0.0), control1: p(0.50, 0.30), control2: p(0.22, 0.22))
            path.closeSubpath()

        case .pancreas:
            path.addEllipse(in: box(0.0, 0.0, 0.34, 1.0))
            path.addRoundedRect(in: box(0.2, 0.22, 0.8, 0.56), cornerSize: CGSize(width: 0.28 * r.height, height: 0.28 * r.height))

        case .kidney:
            // 콩 모양 두 개 (안쪽이 오목)
            for (x, notchX) in [(CGFloat(0.0), CGFloat(0.20)), (0.72, 0.72)] {
                let bean = Path(ellipseIn: box(x, 0, 0.28, 1))
                if #available(macOS 14, *) {
                    path.addPath(bean.subtracting(Path(ellipseIn: box(notchX, 0.36, 0.08, 0.28))))
                } else {
                    path.addPath(bean)   // macOS 13: 오목한 홈 없이 타원
                }
            }

        case .colon:
            var line = Path()
            line.move(to: p(0.12, 0.86))
            line.addLine(to: p(0.12, 0.10))
            line.addLine(to: p(0.88, 0.10))
            line.addLine(to: p(0.88, 0.78))
            line.addQuadCurve(to: p(0.55, 0.92), control: p(0.85, 0.98))
            line.addLine(to: p(0.52, 1.0))
            path.addPath(line.strokedPath(StrokeStyle(lineWidth: 0.15 * min(r.width, r.height) + 0.04 * r.width,
                                                      lineCap: .round, lineJoin: .round)))

        case .thyroid:
            path.addEllipse(in: box(0, 0, 0.44, 1))
            path.addEllipse(in: box(0.56, 0, 0.44, 1))
            path.addRect(box(0.3, 0.45, 0.4, 0.32))

        case .breastUterus:
            // 자궁 + 난관 + 난소
            path.move(to: p(0.32, 0.28))
            path.addLine(to: p(0.68, 0.28))
            path.addCurve(to: p(0.56, 0.75), control1: p(0.70, 0.55), control2: p(0.60, 0.70))
            path.addLine(to: p(0.56, 1.0))
            path.addLine(to: p(0.44, 1.0))
            path.addLine(to: p(0.44, 0.75))
            path.addCurve(to: p(0.32, 0.28), control1: p(0.40, 0.70), control2: p(0.30, 0.55))
            path.closeSubpath()
            for mirror in [false, true] {
                func q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { p(mirror ? 1 - x : x, y) }
                var tube = Path()
                tube.move(to: q(0.36, 0.33))
                tube.addQuadCurve(to: q(0.08, 0.22), control: q(0.20, 0.10))
                path.addPath(tube.strokedPath(StrokeStyle(lineWidth: 0.07 * r.width, lineCap: .round)))
                let ov = box(mirror ? 0.82 : 0.02, 0.30, 0.16, 0.24)
                path.addEllipse(in: ov)
            }

        case .prostate:
            // 방광 + 전립선
            path.addEllipse(in: box(0.08, 0, 0.84, 0.62))
            path.addEllipse(in: box(0.28, 0.6, 0.44, 0.40))

        case .eye:
            path.addEllipse(in: box(0, 0, 0.36, 1))
            path.addEllipse(in: box(0.64, 0, 0.36, 1))

        case .ear:
            path.addEllipse(in: box(0, 0, 0.12, 1))
            path.addEllipse(in: box(0.88, 0, 0.12, 1))

        case .blood, .bone, .body:
            path.addEllipse(in: r)
        }
        return path
    }
}

/// 단순한 전신 실루엣 (정면)
nonisolated struct BodySilhouette: Shape {
    let sex: Sex

    /// 겹치는 조각들. 각각 불투명하게 칠한 뒤 전체에 투명도를 주면 겹친 곳도 한 덩어리로 보임
    func parts(in r: CGRect) -> [Path] {
        let s = min(r.width, r.height) / 1000
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * s, y: r.minY + y * s) }
        let female = sex == .female
        let shoulder: CGFloat = female ? 100 : 118   // 몸 중심에서 어깨까지
        let waist: CGFloat = female ? 72 : 88
        let hip: CGFloat = female ? 108 : 96

        var parts = [Path(ellipseIn: CGRect(origin: p(448, 30), size: CGSize(width: 104 * s, height: 124 * s)))]
        parts.append(Path(roundedRect: CGRect(origin: p(477, 140), size: CGSize(width: 46 * s, height: 60 * s)),
                               cornerSize: CGSize(width: 12 * s, height: 12 * s)))
        // 몸통
        var torso = Path()
        torso.move(to: p(500, 186))
        torso.addLine(to: p(500 + shoulder - 30, 188))
        torso.addQuadCurve(to: p(500 + shoulder, 236), control: p(500 + shoulder - 2, 190))
        torso.addQuadCurve(to: p(500 + waist, 430), control: p(500 + shoulder - 6, 360))
        torso.addQuadCurve(to: p(500 + hip, 545), control: p(500 + waist - 4, 480))
        torso.addQuadCurve(to: p(500, 600), control: p(500 + hip - 10, 600))
        torso.addQuadCurve(to: p(500 - hip, 545), control: p(500 - hip + 10, 600))
        torso.addQuadCurve(to: p(500 - waist, 430), control: p(500 - waist + 4, 480))
        torso.addQuadCurve(to: p(500 - shoulder, 236), control: p(500 - shoulder + 6, 360))
        torso.addQuadCurve(to: p(500 - shoulder + 30, 188), control: p(500 - shoulder + 2, 190))
        torso.closeSubpath()
        parts.append(torso)

        // 팔·다리 (두꺼운 선을 도형으로 변환)
        for side in [-1.0, 1.0] as [CGFloat] {
            var arm = Path()
            arm.move(to: p(500 + side * (shoulder - 14), 232))
            arm.addQuadCurve(to: p(500 + side * (shoulder + 52), 560), control: p(500 + side * (shoulder + 40), 380))
            parts.append(arm.strokedPath(StrokeStyle(lineWidth: (female ? 34 : 42) * s, lineCap: .round)))
            parts.append(Path(ellipseIn: CGRect(origin: p(500 + side * (shoulder + 52) - 20, 552),
                                                     size: CGSize(width: 40 * s, height: 56 * s))))
            var leg = Path()
            leg.move(to: p(500 + side * 48, 560))
            leg.addQuadCurve(to: p(500 + side * 58, 955), control: p(500 + side * 66, 760))
            parts.append(leg.strokedPath(StrokeStyle(lineWidth: (female ? 72 : 76) * s, lineCap: .round)))
        }
        return parts
    }

    func path(in r: CGRect) -> Path {
        var path = Path()
        parts(in: r).forEach { path.addPath($0) }
        return path
    }
}

/// 장기별 위치·배지 배치
nonisolated struct BodyLayout {
    struct Slot {
        let organ: Organ
        /// 몸 안 장기 위치 (설계 공간)
        let rect: CGRect
        /// 지시선이 닿는 점
        let anchor: CGPoint
        /// 배지 중심
        let badge: CGPoint
    }

    static let badgeRadius: CGFloat = 46
    /// 몸 안에 그리지 않고 아래 줄 배지로만 보여주는 부위
    static let wholeBody: [Organ] = [.blood, .bone, .body]

    let slots: [Slot]

    init(sex: Sex) {
        let lx: CGFloat = 190, rx: CGFloat = 810
        let ys: [CGFloat] = [95, 255, 415, 575, 735, 895]
        let pelvic: Slot = sex == .female
            ? Slot(organ: .breastUterus, rect: CGRect(x: 456, y: 520, width: 88, height: 62),
                   anchor: CGPoint(x: 512, y: 560), badge: CGPoint(x: rx, y: ys[5]))
            : Slot(organ: .prostate, rect: CGRect(x: 482, y: 540, width: 36, height: 42),
                   anchor: CGPoint(x: 506, y: 572), badge: CGPoint(x: rx, y: ys[5]))
        slots = [
            // 왼쪽 열
            Slot(organ: .brainVessel, rect: CGRect(x: 458, y: 44, width: 84, height: 64),
                 anchor: CGPoint(x: 472, y: 72), badge: CGPoint(x: lx, y: ys[0])),
            Slot(organ: .thyroid, rect: CGRect(x: 482, y: 168, width: 36, height: 20),
                 anchor: CGPoint(x: 488, y: 178), badge: CGPoint(x: lx, y: ys[1])),
            Slot(organ: .lung, rect: CGRect(x: 418, y: 206, width: 164, height: 170),
                 anchor: CGPoint(x: 438, y: 300), badge: CGPoint(x: lx, y: ys[2])),
            Slot(organ: .liver, rect: CGRect(x: 420, y: 368, width: 104, height: 70),
                 anchor: CGPoint(x: 446, y: 395), badge: CGPoint(x: lx, y: ys[3])),
            Slot(organ: .kidney, rect: CGRect(x: 418, y: 424, width: 164, height: 52),
                 anchor: CGPoint(x: 440, y: 450), badge: CGPoint(x: lx, y: ys[4])),
            Slot(organ: .colon, rect: CGRect(x: 452, y: 474, width: 96, height: 90),
                 anchor: CGPoint(x: 463, y: 530), badge: CGPoint(x: lx, y: ys[5])),
            // 오른쪽 열
            Slot(organ: .eye, rect: CGRect(x: 475, y: 96, width: 50, height: 11),
                 anchor: CGPoint(x: 520, y: 101), badge: CGPoint(x: rx, y: ys[0])),
            Slot(organ: .ear, rect: CGRect(x: 441, y: 82, width: 118, height: 30),
                 anchor: CGPoint(x: 555, y: 97), badge: CGPoint(x: rx, y: ys[1])),
            Slot(organ: .heart, rect: CGRect(x: 488, y: 268, width: 64, height: 60),
                 anchor: CGPoint(x: 528, y: 300), badge: CGPoint(x: rx, y: ys[2])),
            Slot(organ: .stomach, rect: CGRect(x: 506, y: 372, width: 68, height: 84),
                 anchor: CGPoint(x: 556, y: 410), badge: CGPoint(x: rx, y: ys[3])),
            Slot(organ: .pancreas, rect: CGRect(x: 470, y: 444, width: 82, height: 18),
                 anchor: CGPoint(x: 540, y: 453), badge: CGPoint(x: rx, y: ys[4])),
            pelvic,
        ]
    }

    /// 몸 안에 그리는 순서 (뒤쪽 장기 먼저)
    static let drawOrder: [Organ] = [
        .brainVessel, .eye, .ear, .thyroid, .lung, .heart, .kidney, .colon,
        .liver, .stomach, .pancreas, .breastUterus, .prostate,
    ]
}
