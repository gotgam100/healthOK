import Foundation

/// 하나의 판정 구간. 기본은 min 이상, max 미만.
public struct Band: Codable, Sendable, Hashable {
    public let level: Level
    public let label: String?
    public let min: Double?
    public let max: Double?
    /// min 포함 여부 (기본 true)
    public let minInclusive: Bool?
    /// max 포함 여부 (기본 false)
    public let maxInclusive: Bool?

    public init(level: Level, label: String? = nil, min: Double? = nil, max: Double? = nil,
                minInclusive: Bool? = nil, maxInclusive: Bool? = nil) {
        self.level = level
        self.label = label
        self.min = min
        self.max = max
        self.minInclusive = minInclusive
        self.maxInclusive = maxInclusive
    }

    public func contains(_ v: Double) -> Bool {
        if let min {
            if minInclusive ?? true { if v < min { return false } } else if v <= min { return false }
        }
        if let max {
            if maxInclusive ?? false { if v > max { return false } } else if v >= max { return false }
        }
        return true
    }
}

/// 항목별 기준치 규칙. 성별·나이 조건이 있으면 해당하는 사람에게만 적용.
public struct ReferenceRule: Codable, Sendable, Hashable {
    public let item: String
    public let sex: Sex?
    public let ageMin: Int?
    public let ageMax: Int?
    /// 낮은 값 → 높은 값 순서
    public let bands: [Band]
    /// 이 규칙이 적용될 때 함께 보여줄 설명
    public let note: String?
    public let source: String

    public func applies(sex s: Sex, age: Int) -> Bool {
        if let sex, sex != s { return false }
        if let ageMin, age < ageMin { return false }
        if let ageMax, age > ageMax { return false }
        return true
    }

    /// 조건이 많을수록 우선
    var specificity: Int {
        (sex == nil ? 0 : 1) + (ageMin == nil && ageMax == nil ? 0 : 1)
    }
}
