import SwiftUI
import HealthCore

// MARK: - 판정 표시 스타일

extension Level {
    var color: Color {
        switch self {
        case .normal: .green
        case .borderline: .orange
        case .abnormal: .red
        }
    }
    var symbol: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .borderline: "exclamationmark.triangle.fill"
        case .abnormal: "xmark.octagon.fill"
        }
    }
}

struct LevelBadge: View {
    let judgment: Judgment?
    var compact = false

    var body: some View {
        if let j = judgment {
            Label(compact ? j.level.nameKo : j.label, systemImage: j.level.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(j.level.color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(j.level.color.opacity(0.12), in: Capsule())
                .lineLimit(1)
        } else {
            Text("기준 없음").font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - 값 표시

extension TestItem {
    func display(_ value: Double) -> String {
        switch kind {
        case .ordinal:
            resolvedOptions.first { $0.value == Int(value.rounded()) }?.label ?? "—"
        case .numeric:
            // 기본 자리수로 반올림하면 값이 달라지는 경우(예: HDL 47.2) 소수 2자리까지 더 보여줌
            Formatting.number(value, digits: (fractionDigits...max(fractionDigits, 2)).first {
                let p = pow(10, Double($0))
                return abs((value * p).rounded() / p - value) < 1e-9
            } ?? fractionDigits)
        }
    }

    /// 붙여넣은 글자를 저장값으로 바꿈. 숫자 항목은 "47.2 mg/dL"·"1,234"처럼 단위·쉼표가 섞여도 됨.
    func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        switch kind {
        case .ordinal:
            let opts = resolvedOptions
            if let o = opts.first(where: { $0.label == t }) ?? opts.first(where: { $0.label.hasPrefix(t) || t.hasPrefix($0.label) }) {
                return Double(o.value)
            }
            return nil
        case .numeric:
            let cleaned = t.replacingOccurrences(of: ",", with: "")
            guard let r = cleaned.range(of: #"-?\d+(\.\d+)?"#, options: .regularExpression) else { return nil }
            return Double(cleaned[r])
        }
    }

    func displayWithUnit(_ value: Double) -> String {
        guard kind == .numeric, let unit, !unit.isEmpty else { return display(value) }
        return "\(display(value)) \(unit)"
    }
}

extension Date {
    var ymd: String { formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)) }
    var yearString: String { formatted(.dateTime.year()) }
}

// MARK: - 판정 묶음

nonisolated struct JudgedResult: Identifiable {
    let item: TestItem
    let result: TestResult
    let judgment: Judgment?
    /// 이번 검진에 없어 이전 검진 값을 가져왔으면 그 검진일
    var carriedFrom: Date? = nil
    var id: String { item.code }
}

/// 어떤 검진 시점의 상태: 이번에 빠진 항목은 가장 최근 값으로 채워 판정
nonisolated struct Snapshot {
    let results: [JudgedResult]
    /// 항목별로 그 값 바로 전에 측정한 값 (비교용)
    let previous: [String: TestResult]
}

extension Person {
    func snapshot(at checkup: Checkup, evaluator: Evaluator = Evaluator()) -> Snapshot {
        let catalog = evaluator.catalog
        let upTo = sortedCheckups.prefix { $0.date <= checkup.date && $0 !== checkup } + [checkup]
        var latest: [String: (TestResult, Checkup)] = [:]
        var previous: [String: TestResult] = [:]
        for c in upTo {
            for r in c.results {
                if let old = latest[r.code] { previous[r.code] = old.0 }
                latest[r.code] = (r, c)
            }
        }
        let results = latest.compactMap { code, pair -> JudgedResult? in
            let (r, c) = pair
            let ctx = context(at: c.date)
            guard let item = catalog.item(code), item.appliesTo(ctx.sex) else { return nil }
            return JudgedResult(item: item, result: r,
                                judgment: evaluator.judge(code: code, value: r.value, context: ctx),
                                carriedFrom: c === checkup ? nil : c.date)
        }
        .sorted { (catalog.items.firstIndex(of: $0.item) ?? 0) < (catalog.items.firstIndex(of: $1.item) ?? 0) }
        return Snapshot(results: results, previous: previous)
    }
}

extension Checkup {
    /// 이 검진의 모든 결과를 검진 당시 나이 기준으로 판정
    func judged(evaluator: Evaluator = Evaluator()) -> [JudgedResult] {
        guard let person else { return [] }
        let ctx = person.context(at: date)
        let catalog = evaluator.catalog
        return results.compactMap { r in
            guard let item = catalog.item(r.code), item.appliesTo(ctx.sex) else { return nil }
            return JudgedResult(item: item, result: r,
                                judgment: evaluator.judge(code: r.code, value: r.value, context: ctx))
        }
        .sorted { lhs, rhs in
            let li = catalog.items.firstIndex(of: lhs.item) ?? 0
            let ri = catalog.items.firstIndex(of: rhs.item) ?? 0
            return li < ri
        }
    }
}

extension Organ {
    /// 임시 아이콘 (3단계에서 인체 그림으로 대체)
    var symbol: String {
        switch self {
        case .brainVessel: "brain.head.profile"
        case .eye: "eye"
        case .ear: "ear"
        case .thyroid: "staroflife"
        case .lung: "lungs"
        case .heart: "heart"
        case .liver: "cross.vial"
        case .stomach: "fork.knife"
        case .pancreas: "drop.triangle"
        case .kidney: "testtube.2"
        case .colon: "circle.dashed"
        case .blood: "drop"
        case .bone: "figure.walk"
        case .body: "figure.stand"
        case .prostate: "person"
        case .breastUterus: "person.crop.circle"
        }
    }
}

// MARK: - 빈 화면 안내 (macOS 13에는 EmptyState가 없어서 직접 만듦)

struct EmptyState<L: View, D: View, A: View>: View {
    @ViewBuilder var label: () -> L
    @ViewBuilder var description: () -> D
    @ViewBuilder var actions: () -> A

    var body: some View {
        VStack(spacing: 12) {
            label()
                .labelStyle(EmptyStateLabelStyle())
            description()
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) { actions() }
                .padding(.top, 6)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension EmptyState {
    init(@ViewBuilder label: @escaping () -> L, @ViewBuilder description: @escaping () -> D)
    where A == EmptyView {
        self.init(label: label, description: description, actions: { EmptyView() })
    }
    init(@ViewBuilder label: @escaping () -> L, @ViewBuilder actions: @escaping () -> A)
    where D == EmptyView {
        self.init(label: label, description: { EmptyView() }, actions: actions)
    }
}

extension EmptyState where L == Label<Text, Image>, A == EmptyView, D == Text {
    init(_ title: String, systemImage: String, description: Text) {
        self.init(label: { Label(title, systemImage: systemImage) }, description: { description }, actions: { EmptyView() })
    }
}

private struct EmptyStateLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 10) {
            configuration.icon
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            configuration.title
                .font(.title2.bold())
        }
    }
}

extension Color {
    /// 카드 배경 (macOS 14의 .background.secondary 대신, 밝은·어두운 모드 모두 은은하게)
    static let panel = Color.primary.opacity(0.05)
}
