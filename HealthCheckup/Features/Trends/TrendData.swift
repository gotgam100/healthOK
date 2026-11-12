import Foundation
import HealthCore

/// 한 항목의 여러 해 기록 + 그래프에 필요한 범위·기준 구간
struct TrendSeries: Identifiable {
    struct Point: Identifiable {
        let date: Date
        let value: Double
        let judgment: Judgment?
        let note: String
        var id: Date { date }
    }

    /// 배경 기준 띠 (검진마다 나이가 달라 기준이 바뀔 수 있어 검진 구간별로 만듦)
    struct BandRect: Identifiable {
        let id: Int
        let x0: Date, x1: Date
        let y0: Double, y1: Double
        let level: Level
    }

    let item: TestItem
    let points: [Point]
    let xDomain: ClosedRange<Date>
    let yDomain: ClosedRange<Double>
    let bands: [BandRect]
    /// 가장 최근 검진 기준 정상 범위 설명
    let reference: String
    let source: String?

    var id: String { item.code }
    var latest: Point? { points.last }
    var previous: Point? { points.count > 1 ? points[points.count - 2] : nil }
    var worstLevel: Level? { points.compactMap(\.judgment?.level).max() }

    /// 처음 대비 최근 변화 방향 설명 (나빠지는지 판단은 판정 단계로)
    var direction: String? {
        guard let first = points.first?.judgment?.level, let last = latest?.judgment?.level,
              points.count > 1 else { return nil }
        if last > first { return "나빠지는 중" }
        if last < first { return "좋아지는 중" }
        return nil
    }
}

enum TrendBuilder {
    /// 숫자·선택형 항목 중 기록이 있는 것만, 항목 사전 순서로
    static func series(for person: Person, evaluator: Evaluator = Evaluator()) -> [TrendSeries] {
        let checkups = person.sortedCheckups
        guard !checkups.isEmpty else { return [] }
        let catalog = evaluator.catalog
        let latestCtx = person.context(at: checkups.last!.date)

        return catalog.items(for: person.sex).compactMap { item in
            let entries: [(Checkup, TestResult)] = checkups.compactMap { c in c.result(item.code).map { (c, $0) } }
            guard !entries.isEmpty else { return nil }

            let points = entries.map { c, r in
                TrendSeries.Point(date: c.date, value: r.value,
                                  judgment: evaluator.judge(code: item.code, value: r.value,
                                                            context: person.context(at: c.date)),
                                  note: r.note)
            }

            // x 범위: 양 끝에 여유
            let first = points.first!.date, last = points.last!.date
            let span = last.timeIntervalSince(first)
            let pad = max(60 * 86_400, span * 0.06)
            let xDomain = first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)

            // 숫자 항목: y 범위와 기준 띠
            var yDomain: ClosedRange<Double> = 0...1
            var bands: [TrendSeries.BandRect] = []
            if item.kind == .numeric {
                let values = points.map(\.value)
                var lo = values.min()!, hi = values.max()!
                if let rule = catalog.rule(for: item.code, sex: latestCtx.sex, age: latestCtx.age) {
                    let normal = rule.bands.filter { $0.level == .normal }
                    if let nMin = normal.first?.min { lo = min(lo, nMin) }
                    if let nMax = normal.last?.max { hi = max(hi, nMax) }
                }
                let range = max(hi - lo, abs(hi) * 0.1, 0.1)
                lo -= range * 0.15
                hi += range * 0.15
                if values.allSatisfy({ $0 >= 0 }) { lo = max(lo, 0) }
                yDomain = lo...hi

                // 검진마다 해당 나이의 규칙으로 띠를 그림 (중간 지점에서 경계)
                var id = 0
                for (i, p) in points.enumerated() {
                    let x0 = i == 0 ? xDomain.lowerBound
                        : Date(timeIntervalSince1970: (points[i - 1].date.timeIntervalSince1970 + p.date.timeIntervalSince1970) / 2)
                    let x1 = i == points.count - 1 ? xDomain.upperBound
                        : Date(timeIntervalSince1970: (p.date.timeIntervalSince1970 + points[i + 1].date.timeIntervalSince1970) / 2)
                    let ctx = person.context(at: p.date)
                    guard let rule = catalog.rule(for: item.code, sex: ctx.sex, age: ctx.age) else { continue }
                    for b in rule.bands {
                        let y0 = max(b.min ?? lo, lo), y1 = min(b.max ?? hi, hi)
                        guard y1 > y0 else { continue }
                        bands.append(.init(id: id, x0: x0, x1: x1, y0: y0, y1: y1, level: b.level))
                        id += 1
                    }
                }
            }

            return TrendSeries(item: item, points: points, xDomain: xDomain, yDomain: yDomain, bands: bands,
                               reference: evaluator.referenceText(code: item.code, context: latestCtx) ?? "",
                               source: catalog.rule(for: item.code, sex: latestCtx.sex, age: latestCtx.age)?.source)
        }
    }
}
