import Foundation

/// 판정에 필요한 사람 정보 (검진 당시 기준)
public struct PersonContext: Sendable, Hashable {
    public var sex: Sex
    public var age: Int
    public var conditions: Set<Condition>
    public var familyHistory: [FamilyHistory]
    public var smoking: Smoking

    public struct FamilyHistory: Sendable, Hashable {
        public var condition: FamilyCondition
        public var relation: Relation
        public var onsetAge: Int?
        public init(condition: FamilyCondition, relation: Relation, onsetAge: Int? = nil) {
            self.condition = condition
            self.relation = relation
            self.onsetAge = onsetAge
        }
    }

    public init(sex: Sex, age: Int, conditions: Set<Condition> = [],
                familyHistory: [FamilyHistory] = [], smoking: Smoking = .never) {
        self.sex = sex
        self.age = age
        self.conditions = conditions
        self.familyHistory = familyHistory
        self.smoking = smoking
    }

    /// 특정 날짜 기준 만 나이
    public static func age(birthDate: Date, at date: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        return max(0, cal.dateComponents([.year], from: birthDate, to: date).year ?? 0)
    }
}

/// 한 항목의 판정 결과
public struct Judgment: Sendable, Hashable {
    public let level: Level
    /// "공복혈당장애", "양성" 같은 구체적 표현
    public let label: String
    /// 정상 범위 설명 (예: "100 미만")
    public let reference: String
    /// 판정 이유·참고 설명
    public let notes: [String]
    public let source: String?
}

public struct Evaluator: Sendable {
    public let catalog: Catalog

    public init(catalog: Catalog = .shared) { self.catalog = catalog }

    public func judge(code: String, value: Double, context: PersonContext) -> Judgment? {
        guard let item = catalog.item(code) else { return nil }
        switch item.kind {
        case .ordinal:
            let options = item.resolvedOptions
            guard let opt = options.first(where: { $0.value == Int(value.rounded()) }) else { return nil }
            let normals = options.filter { $0.level == .normal }.map(\.label).joined(separator: ", ")
            return Judgment(level: opt.level, label: opt.label, reference: normals, notes: [], source: nil)

        case .numeric:
            guard let rule = catalog.rule(for: code, sex: context.sex, age: context.age),
                  let band = rule.bands.first(where: { $0.contains(value) }) else { return nil }
            return Judgment(level: band.level,
                            label: band.label ?? band.level.nameKo,
                            reference: Self.referenceText(rule: rule, digits: item.fractionDigits),
                            notes: rule.note.map { [$0] } ?? [],
                            source: rule.source)
        }
    }

    /// 사람에게 적용되는 정상 범위 설명 (값 없이도 표시용)
    public func referenceText(code: String, context: PersonContext) -> String? {
        guard let item = catalog.item(code) else { return nil }
        if item.kind == .ordinal {
            return item.resolvedOptions.filter { $0.level == .normal }.map(\.label).joined(separator: ", ")
        }
        guard let rule = catalog.rule(for: code, sex: context.sex, age: context.age) else { return nil }
        return Self.referenceText(rule: rule, digits: item.fractionDigits)
    }

    static func referenceText(rule: ReferenceRule, digits: Int) -> String {
        let normal = rule.bands.filter { $0.level == .normal }
        guard !normal.isEmpty else { return "" }
        // 연속된 정상 구간을 하나로 합침
        let lo = normal.first!
        let hi = normal.last!
        func f(_ v: Double) -> String { Formatting.number(v, digits: digits) }
        switch (lo.min, hi.max) {
        case let (min?, max?):
            return "\(f(min)) ~ \(f(max))"
        case let (nil, max?):
            return (hi.maxInclusive ?? false) ? "\(f(max)) 이하" : "\(f(max)) 미만"
        case let (min?, nil):
            return (lo.minInclusive ?? true) ? "\(f(min)) 이상" : "\(f(min)) 초과"
        case (nil, nil):
            return "전 범위"
        }
    }

    /// 부위별로 가장 나쁜 판정을 모음
    public func organLevels(_ judged: [(code: String, judgment: Judgment)]) -> [Organ: Level] {
        var result: [Organ: Level] = [:]
        for (code, j) in judged {
            guard let item = catalog.item(code) else { continue }
            for organ in item.organs {
                result[organ] = Swift.max(result[organ] ?? .normal, j.level)
            }
        }
        return result
    }
}

public enum Formatting {
    public static func number(_ v: Double, digits: Int) -> String {
        v.formatted(.number.precision(.fractionLength(digits)).grouping(.never))
    }
}
