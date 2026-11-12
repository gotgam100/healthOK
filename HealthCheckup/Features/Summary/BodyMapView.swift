import SwiftUI
import HealthCore

/// 전신 인포그래픽: 실루엣 안 장기 + 양옆 원형 배지 + 지시선. 색 = 판정 색.
struct BodyMapView: View {
    @ObservedObject var store = HealthStore.shared
    let sex: Sex
    let levels: [Organ: Level]
    @Binding var selected: Organ?
    /// 그릴 폭. 바깥에서 정해서 넘김 (안에서 크기를 재면 레이아웃이 무한 반복될 수 있음)
    let width: CGFloat

    @State private var hovered: Organ?

    private var layout: BodyLayout { BodyLayout(sex: sex) }

    static let designWidth: CGFloat = 840
    static func height(forWidth w: CGFloat) -> CGFloat { w * 1000 / designWidth }

    static func color(_ level: Level?) -> Color {
        level?.color ?? Color(white: 0.55)
    }

    var body: some View {
        let scale = width / Self.designWidth
        canvas
            // 1000×1000 설계 공간에서 양옆 여백 80씩 잘라 세로형으로 사용
            .offset(x: -80)
            .frame(width: Self.designWidth, height: 1000, alignment: .topLeading)
            .clipped()
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width, height: Self.height(forWidth: width), alignment: .topLeading)
    }

    private var canvas: some View {
        let slots = layout.slots
        return ZStack(alignment: .topLeading) {
            // 실루엣
            Canvas { ctx, size in
                for part in BodySilhouette(sex: sex).parts(in: CGRect(origin: .zero, size: size)) {
                    ctx.fill(part, with: .foreground)
                }
            }
            .foregroundStyle(Color.secondary)
            .opacity(0.28)
            .frame(width: 1000, height: 1000)

            // 지시선
            ForEach(slots, id: \.organ) { slot in
                let c = Self.color(levels[slot.organ])
                let active = isActive(slot.organ)
                Path { p in
                    p.move(to: edgePoint(from: slot.badge, toward: slot.anchor))
                    p.addLine(to: slot.anchor)
                }
                .stroke(c.opacity(active ? 1 : 0.7), lineWidth: active ? 5 : 3)
                Circle()
                    .fill(c)
                    .frame(width: 12, height: 12)
                    .position(slot.anchor)
            }
            .allowsHitTesting(false)

            // 몸 안 장기
            ForEach(BodyLayout.drawOrder.compactMap { o in slots.first { $0.organ == o } }, id: \.organ) { slot in
                organInBody(slot)
            }

            // 배지
            ForEach(slots, id: \.organ) { slot in
                OrganBadge(organ: slot.organ, level: levels[slot.organ],
                           isSelected: selected == slot.organ, isHovered: hovered == slot.organ)
                    .position(slot.badge)
                    .onHover { hovered = $0 ? slot.organ : (hovered == slot.organ ? nil : hovered) }
                    .onTapGesture { selected = slot.organ }
            }
        }
        .frame(width: 1000, height: 1000, alignment: .topLeading)
    }

    private func organInBody(_ slot: BodyLayout.Slot) -> some View {
        let c = Self.color(levels[slot.organ])
        let active = isActive(slot.organ)
        let shape = OrganGlyph(organ: slot.organ)
        return shape
            .fill(c.opacity(levels[slot.organ] == nil ? 0.55 : 0.92))
            .overlay(shape.stroke(Color.white.opacity(active ? 0.95 : 0), lineWidth: 3))
            .shadow(color: active ? c.opacity(0.8) : .clear, radius: active ? 10 : 0)
            .frame(width: slot.rect.width, height: slot.rect.height)
            .contentShape(shape)
            .position(x: slot.rect.midX, y: slot.rect.midY)
            .onHover { hovered = $0 ? slot.organ : (hovered == slot.organ ? nil : hovered) }
            .onTapGesture { selected = slot.organ }
    }

    private func isActive(_ organ: Organ) -> Bool { selected == organ || hovered == organ }

    /// 배지 원 테두리에서 시작하도록
    private func edgePoint(from c: CGPoint, toward a: CGPoint) -> CGPoint {
        let dx = a.x - c.x, dy = a.y - c.y
        let d = max(1, sqrt(dx * dx + dy * dy))
        let r = BodyLayout.badgeRadius
        return CGPoint(x: c.x + dx / d * r, y: c.y + dy / d * r)
    }
}

/// 원형 장기 배지 (흰 아이콘 + 이름·판정)
struct OrganBadge: View {
    @ObservedObject var store = HealthStore.shared
    let organ: Organ
    let level: Level?
    var isSelected = false
    var isHovered = false
    /// 설계 공간 기준 반지름
    var radius: CGFloat = BodyLayout.badgeRadius

    var body: some View {
        let c = BodyMapView.color(level)
        VStack(spacing: 6) {
            ZStack {
                if level == .abnormal {
                    // 이상 부위 강조 (움직이는 효과는 CPU를 계속 써서 고정 테두리로)
                    Circle()
                        .stroke(c.opacity(0.45), lineWidth: 6)
                        .frame(width: radius * 2 + 22, height: radius * 2 + 22)
                }
                Circle()
                    .fill(c.gradient)
                    .frame(width: radius * 2, height: radius * 2)
                    .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 5 : 0))
                    .shadow(color: .black.opacity(isHovered ? 0.3 : 0), radius: 8, y: 2)
                icon
                    .foregroundStyle(.white)
            }
            .scaleEffect(isHovered || isSelected ? 1.08 : 1)
            .animation(.spring(duration: 0.25), value: isHovered)
            .animation(.spring(duration: 0.25), value: isSelected)

            HStack(spacing: 6) {
                Text(organ.nameKo)
                Text(level?.nameKo ?? "기록 없음")
                    .foregroundStyle(level == nil ? .secondary : c)
            }
            .font(.system(size: 27, weight: .semibold))
            .fixedSize()
        }
        // 이름 글자가 아래로 붙어도 원의 중심이 position 좌표가 되도록
        .padding(.top, 40)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var icon: some View {
        let box = radius * 1.15
        switch organ {
        case .eye: Image(systemName: "eye.fill").font(.system(size: radius * 0.8))
        case .ear: Image(systemName: "ear.fill").font(.system(size: radius * 0.85))
        case .blood: Image(systemName: "drop.fill").font(.system(size: radius * 0.8))
        case .bone: Image(systemName: "figure.walk").font(.system(size: radius * 0.85))
        case .body: Image(systemName: "figure.arms.open").font(.system(size: radius * 0.85))
        default:
            OrganGlyph(organ: organ)
                .fill(.white)
                .frame(width: box * aspect.width, height: box * aspect.height)
        }
    }

    /// 배지 안 아이콘 비율
    private var aspect: CGSize {
        switch organ {
        case .brainVessel: CGSize(width: 1, height: 0.78)
        case .thyroid: CGSize(width: 1, height: 0.6)
        case .lung: CGSize(width: 1, height: 1)
        case .heart: CGSize(width: 0.95, height: 0.9)
        case .liver: CGSize(width: 1, height: 0.7)
        case .stomach: CGSize(width: 0.8, height: 1)
        case .pancreas: CGSize(width: 1, height: 0.3)
        case .kidney: CGSize(width: 1, height: 0.6)
        case .colon: CGSize(width: 0.95, height: 0.85)
        case .breastUterus: CGSize(width: 1, height: 0.75)
        case .prostate: CGSize(width: 0.7, height: 0.9)
        default: CGSize(width: 1, height: 1)
        }
    }
}

/// 몸 전체에 해당하는 부위 (혈액·뼈·체형) 작은 배지 줄
struct WholeBodyChips: View {
    @ObservedObject var store = HealthStore.shared
    let levels: [Organ: Level]
    @Binding var selected: Organ?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(BodyLayout.wholeBody) { organ in
                let level = levels[organ]
                let c = BodyMapView.color(level)
                Button { selected = organ } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(c.gradient)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: organ == .blood ? "drop.fill" : organ == .bone ? "figure.walk" : "figure.arms.open")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(organ.nameKo).font(.callout.weight(.semibold))
                            Text(level?.nameKo ?? "기록 없음").font(.caption).foregroundStyle(level == nil ? .secondary : c)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(c.opacity(0.1), in: Capsule())
                    .overlay(Capsule().strokeBorder(selected == organ ? c : c.opacity(0.3), lineWidth: selected == organ ? 2 : 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
