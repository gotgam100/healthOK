import SwiftUI
import Charts
import HealthCore

/// 연도별 추이: 항목별 작은 그래프 모아보기 → 누르면 상세 그래프
struct TrendsView: View {
    @ObservedObject var store = HealthStore.shared
    let person: Person
    @State private var category: ItemCategory?
    @State private var onlyAttention = false
    @State private var selectedCode: String?

    var body: some View {
        let all = TrendBuilder.series(for: person)
        Group {
            if all.isEmpty {
                EmptyState("검진 기록이 없습니다", systemImage: "chart.xyaxis.line",
                                       description: Text("검진 결과를 입력하면 해마다 어떻게 바뀌는지 보여드립니다."))
            } else if let code = selectedCode, let s = all.first(where: { $0.id == code }) {
                TrendDetailView(series: s,
                                related: all.filter { $0.item.category == s.item.category && $0.id != s.id },
                                onSelect: { selectedCode = $0 })
            } else {
                overview(all)
            }
        }
        .navigationTitle("\(person.name) · 추이")
        .toolbar {
            if selectedCode != nil {
                ToolbarItem(placement: .navigation) {
                    Button { selectedCode = nil } label: { Label("모든 항목", systemImage: "chevron.left") }
                        .help("모든 항목 보기")
                }
            } else if !all.isEmpty {
                ToolbarItem {
                    Picker("분류", selection: $category) {
                        Text("모든 분류").tag(ItemCategory?.none)
                        Divider()
                        ForEach(ItemCategory.allCases.filter { c in all.contains { $0.item.category == c } }) { c in
                            Text(c.nameKo).tag(Optional(c))
                        }
                    }
                }
                ToolbarItem {
                    Toggle(isOn: $onlyAttention) { Label("주의·이상만", systemImage: "exclamationmark.triangle") }
                        .help("한 번이라도 주의·이상이 나온 항목만 보기")
                }
            }
        }
        .onChange(of: person.uid) { _ in selectedCode = nil }
        .task {
            #if DEBUG
            if let c = ProcessInfo.processInfo.environment["HEALTHCHECKUP_TREND"] { selectedCode = c }
            #endif
        }
    }

    private func overview(_ all: [TrendSeries]) -> some View {
        let recorded = person.recordedCodes
        let hiddenCount = all.filter { !person.isVisible($0.item, recorded: recorded) }.count
        let filtered = all.filter { s in
            person.isVisible(s.item, recorded: recorded)
                && (category == nil || s.item.category == category)
                && (!onlyAttention || (s.worstLevel ?? .normal) != .normal)
        }
        let groups = ItemCategory.allCases.compactMap { c -> (ItemCategory, [TrendSeries])? in
            let list = filtered.filter { $0.item.category == c }
            return list.isEmpty ? nil : (c, list)
        }
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("항목을 누르면 큰 그래프로 볼 수 있습니다. 배경 띠는 정상·주의·이상 구간입니다."
                     + (hiddenCount > 0 ? " 숨긴 항목 \(hiddenCount)개는 검진 기록 → 항목 표시에서 켤 수 있습니다." : ""))
                    .font(.callout).foregroundStyle(.secondary)
                if groups.isEmpty {
                    Text("조건에 맞는 항목이 없습니다.").foregroundStyle(.secondary)
                }
                ForEach(groups, id: \.0) { cat, list in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(cat.nameKo).font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                            ForEach(list) { s in
                                Button { selectedCode = s.id } label: { TrendCard(series: s) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - 모아보기 카드

private struct TrendCard: View {
    @ObservedObject var store = HealthStore.shared
    let series: TrendSeries
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(series.item.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                if let d = series.direction {
                    Label(d, systemImage: d == "나빠지는 중" ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(d == "나빠지는 중" ? Color.orange : Color.green)
                }
            }
            if let last = series.latest {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(series.item.display(last.value))
                        .font(.title3.weight(.semibold))
                    if let u = series.item.unit, series.item.kind == .numeric {
                        Text(u).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if last.judgment != nil { LevelBadge(judgment: last.judgment) }
                }
            }
            if series.item.kind == .numeric {
                TrendChart(series: series, compact: true)
                    .frame(height: 84)
            } else {
                StatusStrip(series: series)
                    .frame(height: 84, alignment: .center)
            }
        }
        .padding(12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(hovering ? 0.6 : 0)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering = $0 }
    }
}

/// 선택형 항목(음성/양성, 소견)은 연도별 상태 칩으로
private struct StatusStrip: View {
    @ObservedObject var store = HealthStore.shared
    let series: TrendSeries
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(series.points) { p in
                    VStack(spacing: 4) {
                        Image(systemName: p.judgment?.level.symbol ?? "circle.dashed")
                            .foregroundStyle(p.judgment?.level.color ?? .secondary)
                        Text(series.item.display(p.value)).font(.caption2).lineLimit(1)
                        Text(p.date.yearString).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background((p.judgment?.level.color ?? .gray).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .help(p.note.isEmpty ? p.date.ymd : "\(p.date.ymd) · \(p.note)")
                }
            }
        }
    }
}

// MARK: - 그래프

struct TrendChart: View {
    @ObservedObject var store = HealthStore.shared
    let series: TrendSeries
    var compact = false
    @State private var hoverDate: Date?

    private var hovered: TrendSeries.Point? {
        guard let hoverDate else { return nil }
        return series.points.min {
            abs($0.date.timeIntervalSince(hoverDate)) < abs($1.date.timeIntervalSince(hoverDate))
        }
    }

    /// 양 끝 점에서는 말풍선이 그래프 밖으로 나가지 않도록 안쪽으로 붙임
    private func tooltipAlignment(_ p: TrendSeries.Point) -> Alignment {
        guard series.points.count > 1 else { return .center }
        if p.id == series.points.first?.id { return .leading }
        if p.id == series.points.last?.id { return .trailing }
        return .center
    }

    var body: some View {
        Chart {
            // 기준 띠 (판정 색, 옅게)
            ForEach(series.bands) { b in
                RectangleMark(xStart: .value("시작", b.x0), xEnd: .value("끝", b.x1),
                              yStart: .value("하한", b.y0), yEnd: .value("상한", b.y1))
                    .foregroundStyle(b.level.color.opacity(b.level == .normal ? 0.10 : 0.13))
            }
            // 선
            ForEach(series.points) { p in
                LineMark(x: .value("검진일", p.date), y: .value(series.item.name, p.value))
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            // 점 (판정 색 + 바탕색 테두리)
            ForEach(series.points) { p in
                PointMark(x: .value("검진일", p.date), y: .value(series.item.name, p.value))
                    .symbol {
                        Circle()
                            .fill(p.judgment?.level.color ?? .gray)
                            .frame(width: compact ? 8 : 11, height: compact ? 8 : 11)
                            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                    }
            }
            // 마지막 값만 직접 표시 (보이지 않는 점에 글자를 붙임)
            if !compact, hovered == nil, let last = series.latest {
                PointMark(x: .value("검진일", last.date), y: .value(series.item.name, last.value))
                    .symbolSize(0)
                    .annotation(position: .top, spacing: 10) {
                        Text(series.item.display(last.value))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
            }
            // 마우스 위치
            if !compact, let h = hovered {
                RuleMark(x: .value("선택", h.date))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: tooltipAlignment(h), spacing: 0) {
                        Tooltip(item: series.item, point: h)
                    }
            }
        }
        .chartXScale(domain: series.xDomain)
        .chartYScale(domain: series.yDomain)
        .chartOverlay { proxy in
            GeometryReader { geo in
                // 가로축 날짜: 각 점 바로 아래에 직접 그림
                xLabels(proxy: proxy, plot: geo[proxy.plotAreaFrame])
                // 마우스 위치의 날짜 찾기 (macOS 13에서도 되는 방식)
                if !compact {
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let loc):
                                let x = loc.x - geo[proxy.plotAreaFrame].origin.x
                                hoverDate = proxy.value(atX: x, as: Date.self)
                            case .ended:
                                hoverDate = nil
                            }
                        }
                }
            }
        }
        .chartXAxis {
            // 차트가 자동으로 붙이는 날짜 글씨는 점과 어긋나고 마지막 연도를 지우기도 해서 쓰지 않음.
            // 날짜는 chartOverlay에서 점 바로 아래에 직접 그림 (xLabels).
            if compact {
                AxisMarks(values: series.points.map(\.date)) { _ in }
            } else {
                AxisMarks(values: series.points.map(\.date)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.25))
                }
            }
        }
        .chartYAxis {
            if compact {
                AxisMarks { _ in }
            } else {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.25))
                    AxisValueLabel()
                }
            }
        }
        .padding(.bottom, labelHeight + 4)   // 날짜 글씨 자리
        .allowsHitTesting(!compact)
    }

    // MARK: 가로축 날짜

    private var labelHeight: CGFloat { compact ? 12 : 16 }
    /// 글씨 폭 (겹침 판단용 어림값)
    private var labelWidth: CGFloat { compact ? 24 : 60 }

    private func labelText(_ d: Date) -> String {
        compact ? d.formatted(.dateTime.year(.twoDigits)) : d.formatted(.dateTime.year().month(.twoDigits))
    }

    /// 점마다 그 바로 아래에 날짜. 너무 붙어 겹치면 최근 것을 남기고 앞의 것을 뺌.
    @ViewBuilder
    private func xLabels(proxy: ChartProxy, plot: CGRect) -> some View {
        let xs: [(Date, CGFloat)] = series.points.compactMap { p in
            proxy.position(forX: p.date).map { (p.date, plot.minX + $0) }
        }
        let kept = Self.keepNonOverlapping(xs.map(\.1), minGap: labelWidth + 4)
        ForEach(Array(xs.enumerated()), id: \.offset) { i, e in
            if kept.contains(i) {
                Text(labelText(e.0))
                    .font(compact ? .system(size: 9) : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .position(x: e.1, y: plot.maxY + 4 + labelHeight / 2)
            }
        }
    }

    /// 뒤(최근)에서부터 앞으로 가며, 이미 남긴 글씨와 충분히 떨어진 것만 남김
    static func keepNonOverlapping(_ xs: [CGFloat], minGap: CGFloat) -> Set<Int> {
        var kept: Set<Int> = []
        var lastX: CGFloat?
        for i in xs.indices.reversed() {
            if let lastX, lastX - xs[i] < minGap { continue }
            kept.insert(i)
            lastX = xs[i]
        }
        return kept
    }
}

private struct Tooltip: View {
    @ObservedObject var store = HealthStore.shared
    let item: TestItem
    let point: TrendSeries.Point
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(point.date.ymd).font(.caption).foregroundStyle(.secondary)
            Text(item.displayWithUnit(point.value)).font(.callout.weight(.semibold))
            if let j = point.judgment {
                Label(j.label, systemImage: j.level.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(j.level.color)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
    }
}

// MARK: - 상세

private struct TrendDetailView: View {
    @ObservedObject var store = HealthStore.shared
    let series: TrendSeries
    let related: [TrendSeries]
    var onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 머리말
                VStack(alignment: .leading, spacing: 6) {
                    Text(series.item.name).font(.title2.bold())
                    HStack(spacing: 10) {
                        if let last = series.latest {
                            Text("최근 \(series.item.displayWithUnit(last.value))").font(.headline)
                            LevelBadge(judgment: last.judgment)
                        }
                        if let d = series.direction {
                            Text("· \(d)").foregroundStyle(.secondary)
                        }
                    }
                    if !series.reference.isEmpty {
                        Text("정상 범위: \(series.reference)\(series.item.unit.map { " \($0)" } ?? "")"
                             + (series.source.map { "  ·  기준: \($0)" } ?? ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                // 큰 그래프
                VStack(alignment: .leading, spacing: 10) {
                    if series.item.kind == .numeric {
                        TrendChart(series: series)
                            .frame(height: 340)
                        BandLegend()
                    } else {
                        StatusStrip(series: series)
                    }
                }
                .padding(16)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))

                // 값 표 (그래프를 보지 않아도 모든 값 확인)
                VStack(alignment: .leading, spacing: 0) {
                    Text("검진별 값").font(.headline).padding(.bottom, 8)
                    ForEach(series.points.reversed()) { p in
                        HStack(spacing: 12) {
                            Text(p.date.ymd).monospacedDigit().frame(width: 110, alignment: .leading)
                            Text(series.item.displayWithUnit(p.value))
                                .monospacedDigit().fontWeight(.semibold)
                                .frame(width: 150, alignment: .leading)
                            LevelBadge(judgment: p.judgment)
                            if let n = p.judgment?.notes.first {
                                Text(n).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            if !p.note.isEmpty {
                                Text(p.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 7)
                        Divider()
                    }
                }

                // 같은 분류의 다른 항목 (작은 그래프로 나란히)
                if !related.isEmpty {
                    Text("같은 분류의 다른 항목 · \(series.item.category.nameKo)").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                        ForEach(related) { s in
                            Button { onSelect(s.id) } label: { TrendCard(series: s) }
                                .buttonStyle(.plain)
                        }
                    }
                }

                Text("판정은 각 검진 당시 나이 기준입니다. 이 정보는 참고용이며 의학적 진단이 아닙니다.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
        }
    }
}

private struct BandLegend: View {
    @ObservedObject var store = HealthStore.shared
    var body: some View {
        HStack(spacing: 16) {
            ForEach([Level.normal, .borderline, .abnormal], id: \.self) { l in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(l.color.opacity(0.25)).frame(width: 18, height: 12)
                    Image(systemName: l.symbol).foregroundStyle(l.color).font(.caption)
                    Text("\(l.nameKo) 구간").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("점에 마우스를 올리면 값과 판정이 보입니다.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
