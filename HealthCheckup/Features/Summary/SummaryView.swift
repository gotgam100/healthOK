import SwiftUI
import HealthCore

/// 요약 대시보드: 전신 인포그래픽 + 부위 상세 + 확인 필요 항목
struct SummaryView: View {
    @ObservedObject var store = HealthStore.shared
    let person: Person
    @State private var selectedCheckupID: PersistentIdentifierBox?
    @State private var editing: EditorTarget?
    @State private var selectedOrgan: Organ?

    private let evaluator = Evaluator()

    private var checkups: [Checkup] { person.sortedCheckups }
    private var current: Checkup? {
        if let id = selectedCheckupID?.id, let c = checkups.first(where: { $0.id == id }) { return c }
        return checkups.last
    }

    var body: some View {
        Group {
            if let current {
                // 창 폭은 바깥에서 한 번만 읽음 (내용 크기가 폭에 다시 영향을 주지 않도록)
                GeometryReader { outer in
                    content(current, available: min(outer.size.width, 1240) - 48)
                }
            } else {
                EmptyState {
                    Label("검진 기록이 없습니다", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("\(person.name)님의 첫 검진 결과를 입력해 보세요.")
                } actions: {
                    Button("검진 추가") { editing = .new }.buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("\(person.name) · 요약")
        .toolbar {
            ToolbarItem {
                Button { editing = .new } label: { Label("검진 추가", systemImage: "plus") }
            }
        }
        .sheet(item: $editing) { target in
            CheckupEditorView(person: person, checkup: target.checkup, focusCode: target.focusCode)
        }
        .onChange(of: person.uid) { _ in
            selectedCheckupID = nil
            selectedOrgan = nil
        }
        .task {
            #if DEBUG
            let env = ProcessInfo.processInfo.environment
            if env["HEALTHCHECKUP_OPEN_EDITOR"] == "1", let current {
                editing = .existing(current)
            }
            if let i = env["HEALTHCHECKUP_CHECKUP"].flatMap(Int.init), checkups.indices.contains(i) {
                selectedCheckupID = PersistentIdentifierBox(id: checkups[i].id)
            }
            if let o = env["HEALTHCHECKUP_ORGAN"].flatMap(Organ.init(rawValue:)) { selectedOrgan = o }
            #endif
        }
    }

    private func content(_ checkup: Checkup, available: CGFloat) -> some View {
        // 이번 검진에 빠진 항목은 가장 최근 해의 값으로 판정 (정상으로 간주하지 않음)
        let snapshot = person.snapshot(at: checkup, evaluator: evaluator)
        let judged = snapshot.results
        let prevByCode = snapshot.previous
        let levels = evaluator.organLevels(judged.compactMap { j in j.judgment.map { (j.item.code, $0) } })
        let counts = Dictionary(grouping: judged.compactMap(\.judgment), by: \.level).mapValues(\.count)
        let attention = judged
            .filter { ($0.judgment?.level ?? .normal) != .normal }
            .sorted { ($0.judgment?.level.rank ?? 0) > ($1.judgment?.level.rank ?? 0) }
        let age = person.context(at: checkup.date).age
        // 선택이 없으면 가장 나쁜 부위를 기본으로
        let organ = selectedOrgan ?? levels.filter { $0.key.sex == nil || $0.key.sex == person.sex }
            .max { $0.value.rank < $1.value.rank }?.key

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 머리말
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(checkup.date.ymd) · \(checkup.type.nameKo)")
                            .font(.title2.bold())
                        Text([checkup.institution, "검진 당시 \(person.sex.nameKo) \(age)세"]
                            .filter { !$0.isEmpty }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("이 검진 편집") { editing = .existing(checkup) }
                }

                CheckupTimeline(checkups: checkups, current: checkup) { c in
                    selectedCheckupID = PersistentIdentifierBox(id: c.id)
                }

                HStack(spacing: 12) {
                    CountTile(level: .normal, count: counts[.normal] ?? 0)
                    CountTile(level: .borderline, count: counts[.borderline] ?? 0)
                    CountTile(level: .abnormal, count: counts[.abnormal] ?? 0)
                }

                // 전신 인포그래픽 + 부위 상세 (좁으면 상세를 아래로). 크기는 창 폭으로만 계산.
                let selection = Binding<Organ?>(get: { organ }, set: { selectedOrgan = $0 })
                let panelWidth: CGFloat = 300
                let wide = available >= 330 + 32 + 16 + panelWidth
                let mapWidth = max(260, min(wide ? available - panelWidth - 16 - 32 : available - 32, 600))
                let map = VStack(spacing: 12) {
                    BodyMapView(sex: person.sex, levels: levels, selected: selection, width: mapWidth)
                    WholeBodyChips(levels: levels, selected: selection)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                let organJudged = judged.filter { j in organ.map { j.item.organs.contains($0) } ?? false }
                // 이 부위에 해당하는 항목 전체 (표시 중인 항목 + 값이 있는 항목). 값이 없으면 '기록 없음'으로 보여줌
                let organItems: [TestItem] = organ.map { o in
                    let recorded = person.recordedCodes
                    let have = Set(organJudged.map(\.item.code))
                    return Catalog.shared.items(for: person.sex).filter {
                        $0.organs.contains(o) && (have.contains($0.code) || person.isVisible($0, recorded: recorded))
                    }
                } ?? []
                let panel = OrganDetailPanel(organ: organ, level: organ.flatMap { levels[$0] }, sex: person.sex,
                                             items: organJudged, allItems: organItems,
                                             previous: prevByCode)
                if wide {
                    HStack(alignment: .top, spacing: 16) {
                        map
                        panel.frame(width: panelWidth)
                    }
                } else {
                    VStack(spacing: 16) {
                        map
                        panel
                    }
                }

                // 확인이 필요한 항목
                Text("확인이 필요한 항목").font(.headline)
                if attention.isEmpty {
                    Label("모든 항목이 정상 범위입니다.", systemImage: "checkmark.seal")
                        .foregroundStyle(.green)
                } else {
                    VStack(spacing: 0) {
                        ForEach(attention) { j in
                            AttentionRow(judged: j, previous: prevByCode[j.item.code])
                            Divider()
                        }
                    }
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 10))
                }

                Text("이 판정은 일반적인 기준에 따른 참고 정보이며 의학적 진단이 아닙니다. 이상 소견은 의료진과 상담하세요.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 1240, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

/// 검진 연도 타임라인 (눌러서 다른 해 보기)
private struct CheckupTimeline: View {
    @ObservedObject var store = HealthStore.shared
    let checkups: [Checkup]
    let current: Checkup
    var onSelect: (Checkup) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(checkups.enumerated()), id: \.element.id) { i, c in
                    if i > 0 {
                        Rectangle().fill(.quaternary).frame(width: 24, height: 2)
                    }
                    let isCurrent = c === current
                    let worst = c.person?.snapshot(at: c).results.compactMap(\.judgment).map(\.level).max()
                    Button { onSelect(c) } label: {
                        HStack(spacing: 6) {
                            Circle().fill(worst?.color ?? .gray).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(c.date.yearString).font(.callout.weight(.semibold))
                                Text(c.type == .comprehensive ? "종합" : c.type == .national ? "일반" : "기타")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(isCurrent ? Color.accentColor.opacity(0.18) : Color.clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(isCurrent ? Color.accentColor : Color.secondary.opacity(0.3)))
                        .contentShape(Capsule())  // 캡슐 안 어디를 눌러도 선택
                    }
                    .buttonStyle(.plain)
                    .help(c.date.ymd)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// 선택한 부위의 검사 결과
private struct OrganDetailPanel: View {
    @ObservedObject var store = HealthStore.shared
    let organ: Organ?
    let level: Level?
    let sex: Sex
    let items: [JudgedResult]
    /// 값이 없는 항목까지 포함한 이 부위의 항목 (항목 사전 순서)
    let allItems: [TestItem]
    let previous: [String: TestResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let organ {
                HStack(spacing: 10) {
                    Circle().fill(BodyMapView.color(level).gradient).frame(width: 14, height: 14)
                    Text(organ.nameKo).font(.title3.bold())
                    Spacer()
                    if let level {
                        Text(level.nameKo)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(level.color)
                    }
                }
                if items.isEmpty {
                    Text("이 부위 관련 기록이 아직 없습니다.")
                        .foregroundStyle(.secondary)
                    let related = Catalog.shared.items(for: sex).filter { $0.organs.contains(organ) }.map(\.name)
                    if !related.isEmpty {
                        Text("관련 검사: " + related.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    let byCode = Dictionary(items.map { ($0.item.code, $0) }, uniquingKeysWith: { a, _ in a })
                    let carried = items.filter { $0.carriedFrom != nil }.count
                    let missing = allItems.filter { byCode[$0.code] == nil }.count
                    if carried > 0 || missing > 0 {
                        Text([carried > 0 ? "지난 검진 값 \(carried)개" : nil,
                              missing > 0 ? "기록 없음 \(missing)개" : nil]
                            .compactMap { $0 }.joined(separator: " · ") + " — 이번 검진 값만으로 판정한 것이 아닙니다")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    // 판정과 상관없이 항목 사전 순서로 고정 (검진마다 순서가 바뀌지 않게)
                    ForEach(allItems) { item in
                        if let j = byCode[item.code] {
                            DetailRow(judged: j, previous: previous[j.item.code])
                        } else {
                            MissingRow(item: item)
                        }
                        if item.id != allItems.last?.id { Divider() }
                    }
                }
            } else {
                Text("인체 그림에서 부위를 눌러 보세요.")
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DetailRow: View {
    @ObservedObject var store = HealthStore.shared
    let judged: JudgedResult
    let previous: TestResult?

    var body: some View {
        let carried = judged.carriedFrom
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(judged.item.name).font(.callout.weight(.medium))
                if let carried { PastTag(date: carried) }
                Spacer()
                Text(judged.item.displayWithUnit(judged.result.value))
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(judged.judgment?.level.color ?? .primary)
                    .opacity(carried == nil ? 1 : 0.55)
            }
            HStack {
                LevelBadge(judgment: judged.judgment)
                Spacer()
                if judged.item.kind == .numeric, let previous {
                    let diff = judged.result.value - previous.value
                    let word = carried == nil ? "지난번" : "그 전"
                    Text(abs(diff) < 0.0001 ? "\(word)과 같음"
                         : "\(word) \(judged.item.display(previous.value)) \(diff > 0 ? "▲" : "▼")")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if let ref = judged.judgment?.reference, !ref.isEmpty, judged.item.kind == .numeric {
                Text("정상 \(ref)").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(judged.judgment?.notes ?? [], id: \.self) { n in
                Text(n).font(.caption).foregroundStyle(.secondary)
            }
            if let carried {
                Label("이번 검진에 없어 \(carried.ymd) 검진 값을 보여 줍니다", systemImage: "clock.arrow.circlepath")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !judged.result.note.isEmpty {
                Text(judged.result.note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(carried == nil ? 0 : 6)
        .background(carried == nil ? Color.clear : Color.secondary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 6))
    }
}

/// 지난 검진 값임을 알리는 표
private struct PastTag: View {
    @ObservedObject var store = HealthStore.shared
    let date: Date
    var body: some View {
        Text(String(Calendar.current.component(.year, from: date)) + "년 값")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Color.accentColor.opacity(0.14), in: Capsule())
            .help("이번 검진에 없어 \(date.ymd) 검진 값을 사용")
    }
}

/// 이 부위 항목인데 지금까지 값이 한 번도 없는 경우
private struct MissingRow: View {
    @ObservedObject var store = HealthStore.shared
    let item: TestItem
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(item.name).font(.callout.weight(.medium)).foregroundStyle(.secondary)
            Spacer()
            Text("기록 없음").font(.callout).foregroundStyle(.tertiary)
        }
    }
}

/// Picker 태그용 (PersistentIdentifier를 Hashable 값으로 감쌈)
struct PersistentIdentifierBox: Hashable {
    let id: UUID
}

enum EditorTarget: Identifiable {
    case new
    case existing(Checkup)
    /// 검진을 열고 특정 항목 위치로 바로 이동
    case item(Checkup, String)
    var id: String {
        switch self {
        case .new: "new"
        case .existing(let c): "\(c.id.uuidString)"
        case .item(let c, let code): "\(c.id.uuidString)-\(code)"
        }
    }
    var checkup: Checkup? {
        switch self {
        case .new: nil
        case .existing(let c), .item(let c, _): c
        }
    }
    var focusCode: String? {
        if case .item(_, let code) = self { return code }
        return nil
    }
}

private struct CountTile: View {
    @ObservedObject var store = HealthStore.shared
    let level: Level
    let count: Int
    var body: some View {
        HStack {
            Image(systemName: level.symbol).font(.title2).foregroundStyle(level.color)
            VStack(alignment: .leading) {
                Text(level.nameKo).font(.subheadline).foregroundStyle(.secondary)
                Text("\(count)개").font(.title2.bold().monospacedDigit())
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(level.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AttentionRow: View {
    @ObservedObject var store = HealthStore.shared
    let judged: JudgedResult
    let previous: TestResult?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(judged.item.name).font(.body.weight(.medium))
                if let ref = judged.judgment?.reference, !ref.isEmpty {
                    Text("정상: \(ref)").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(judged.judgment?.notes ?? [], id: \.self) { n in
                    Text(n).font(.caption).foregroundStyle(.secondary)
                }
                CarriedNote(date: judged.carriedFrom)
                if !judged.result.note.isEmpty {
                    Text(judged.result.note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if judged.item.kind == .numeric, let previous {
                let diff = judged.result.value - previous.value
                if abs(diff) > 0.0001 {
                    Text("\(diff > 0 ? "▲" : "▼") \(judged.item.display(abs(diff)))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .help("이전 검진: \(judged.item.displayWithUnit(previous.value))")
                }
            }
            Text(judged.item.displayWithUnit(judged.result.value))
                .font(.body.monospacedDigit().weight(.semibold))
            LevelBadge(judgment: judged.judgment)
                .frame(minWidth: 110, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

/// 이번 검진에 없어 이전 값을 쓴 항목 표시
private struct CarriedNote: View {
    @ObservedObject var store = HealthStore.shared
    let date: Date?
    var body: some View {
        if let date {
            Label("\(date.ymd) 값 (이번 검진에 없음)", systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
