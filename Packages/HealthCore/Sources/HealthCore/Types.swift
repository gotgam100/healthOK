import Foundation

// MARK: - 사람 관련

public enum Sex: String, Codable, CaseIterable, Sendable, Identifiable {
    case male, female
    public var id: String { rawValue }
    public var nameKo: String { self == .male ? "남성" : "여성" }
}

public enum Smoking: String, Codable, CaseIterable, Sendable, Identifiable {
    case never, former, current
    public var id: String { rawValue }
    public var nameKo: String {
        switch self {
        case .never: "비흡연"
        case .former: "과거 흡연"
        case .current: "현재 흡연"
        }
    }
}

public enum Drinking: String, Codable, CaseIterable, Sendable, Identifiable {
    case none, sometimes, often
    public var id: String { rawValue }
    public var nameKo: String {
        switch self {
        case .none: "마시지 않음"
        case .sometimes: "가끔 (월 1–4회)"
        case .often: "자주 (주 2회 이상)"
        }
    }
}

public enum Exercise: String, Codable, CaseIterable, Sendable, Identifiable {
    case none, sometimes, regular
    public var id: String { rawValue }
    public var nameKo: String {
        switch self {
        case .none: "거의 안 함"
        case .sometimes: "가끔"
        case .regular: "규칙적 (주 3회 이상)"
        }
    }
}

/// 본인이 진단받은 질환 (판정·목표치 조정에 사용)
public enum Condition: String, Codable, CaseIterable, Sendable, Identifiable {
    case hypertension, diabetes, dyslipidemia, coronaryDisease, stroke
    case kidneyDisease, liverDisease, thyroidDisease, cancer
    public var id: String { rawValue }
    public var nameKo: String {
        switch self {
        case .hypertension: "고혈압"
        case .diabetes: "당뇨병"
        case .dyslipidemia: "이상지질혈증"
        case .coronaryDisease: "관상동맥질환 (협심증·심근경색)"
        case .stroke: "뇌졸중"
        case .kidneyDisease: "만성 신장병"
        case .liverDisease: "간질환"
        case .thyroidDisease: "갑상선 질환"
        case .cancer: "암 (치료 이력)"
        }
    }
}

/// 가족력 질환
public enum FamilyCondition: String, Codable, CaseIterable, Sendable, Identifiable {
    case diabetes, hypertension, earlyHeartDisease, stroke
    case colonCancer, stomachCancer, liverCancer, lungCancer
    case breastCancer, ovarianCancer, thyroidCancer, prostateCancer
    case osteoporosis
    public var id: String { rawValue }
    public var nameKo: String {
        switch self {
        case .diabetes: "당뇨병"
        case .hypertension: "고혈압"
        case .earlyHeartDisease: "심근경색·협심증"
        case .stroke: "뇌졸중"
        case .colonCancer: "대장암"
        case .stomachCancer: "위암"
        case .liverCancer: "간암"
        case .lungCancer: "폐암"
        case .breastCancer: "유방암"
        case .ovarianCancer: "난소암"
        case .thyroidCancer: "갑상선암"
        case .prostateCancer: "전립선암"
        case .osteoporosis: "골다공증"
        }
    }
}

public enum Relation: String, Codable, CaseIterable, Sendable, Identifiable {
    case father, mother, sibling, child, grandparent, other
    public var id: String { rawValue }
    public var nameKo: String {
        switch self {
        case .father: "아버지"
        case .mother: "어머니"
        case .sibling: "형제자매"
        case .child: "자녀"
        case .grandparent: "조부모"
        case .other: "기타 친척"
        }
    }
    /// 1차 가족(부모·형제자매·자녀) 여부
    public var isFirstDegree: Bool { [.father, .mother, .sibling, .child].contains(self) }
}

// MARK: - 판정

public enum Level: String, Codable, CaseIterable, Sendable, Comparable {
    case normal, borderline, abnormal

    public var rank: Int {
        switch self {
        case .normal: 0
        case .borderline: 1
        case .abnormal: 2
        }
    }
    public static func < (a: Level, b: Level) -> Bool { a.rank < b.rank }

    public var nameKo: String {
        switch self {
        case .normal: "정상"
        case .borderline: "주의"
        case .abnormal: "이상"
        }
    }
}

// MARK: - 검사 항목

public enum ItemKind: String, Codable, Sendable {
    /// 숫자 수치 (혈당, 콜레스테롤 등)
    case numeric
    /// 정해진 선택지 (음성/양성, 정상/추적관찰/이상 소견 등)
    case ordinal
}

public enum ItemCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    // 순서: 기본 검진표(계측 → 혈압 → 지질 → 신장 → 간 → 혈액·당뇨 → 영상 → 간염) 다음 추가 항목
    case body, eyeEar, bloodPressure, lipid, kidney, liver, blood, diabetes
    case imaging, hepatitis, thyroid, inflammation, tumorMarker, bone
    case endoscopy, womens, mens
    public var id: String { rawValue }
    public var nameKo: String {
        switch self {
        case .body: "신체 계측"
        case .bloodPressure: "혈압"
        case .diabetes: "당뇨"
        case .lipid: "이상지질혈증"
        case .liver: "간 기능"
        case .kidney: "신장 기능·소변"
        case .blood: "혈액"
        case .thyroid: "갑상선"
        case .hepatitis: "간염"
        case .inflammation: "염증·영양"
        case .tumorMarker: "종양표지자"
        case .bone: "골밀도"
        case .eyeEar: "눈·귀"
        case .imaging: "영상·기능 검사"
        case .endoscopy: "내시경·대장"
        case .womens: "여성 검진"
        case .mens: "전립선"
        }
    }
}

/// 전신 인포그래픽의 부위
public enum Organ: String, Codable, CaseIterable, Sendable, Identifiable {
    case brainVessel, eye, ear, thyroid, lung, heart, liver, stomach
    case pancreas, kidney, colon, blood, bone, body, prostate, breastUterus
    public var id: String { rawValue }
    public var nameKo: String {
        switch self {
        case .brainVessel: "뇌·혈관"
        case .eye: "눈"
        case .ear: "귀"
        case .thyroid: "갑상선"
        case .lung: "폐"
        case .heart: "심장"
        case .liver: "간"
        case .stomach: "위·식도"
        case .pancreas: "췌장·혈당"
        case .kidney: "신장"
        case .colon: "대장"
        case .blood: "혈액"
        case .bone: "뼈·관절"
        case .body: "체형"
        case .prostate: "전립선"
        case .breastUterus: "유방·자궁"
        }
    }
    /// 특정 성별에만 해당하는 부위
    public var sex: Sex? {
        switch self {
        case .prostate: .male
        case .breastUterus: .female
        default: nil
        }
    }
}

public struct OrdinalOption: Codable, Sendable, Hashable, Identifiable {
    public let value: Int
    public let label: String
    public let level: Level
    public var id: Int { value }
    public init(value: Int, label: String, level: Level) {
        self.value = value
        self.label = label
        self.level = level
    }
}

public struct TestItem: Codable, Sendable, Hashable, Identifiable {
    public let code: String
    public let name: String
    public let unit: String?
    public let category: ItemCategory
    public let organs: [Organ]
    public let kind: ItemKind
    /// 표시할 소수점 자리수
    public let decimals: Int?
    /// 특정 성별 전용 항목
    public let sex: Sex?
    /// 기본 항목 (매번 입력하는 최소 검진 항목)
    public let basic: Bool?
    /// 종합검진에서 주로 하는 항목 (국가검진 기본 항목이 아님)
    public let comprehensive: Bool?
    /// 미리 정의된 선택지 묶음 이름 (finding, negPos, antibody, urine, hearing)
    public let preset: String?
    public let options: [OrdinalOption]?
    /// 결과지 가져오기 때 쓰는 다른 이름들
    public let aliases: [String]?

    public var id: String { code }
    public var isComprehensive: Bool { comprehensive ?? false }
    public var isBasic: Bool { basic ?? false }
    public var fractionDigits: Int { decimals ?? 0 }

    /// 실제 선택지 (preset이 있으면 펼친 결과)
    public var resolvedOptions: [OrdinalOption] {
        if let options { return options }
        if let preset, let list = OrdinalPresets.all[preset] { return list }
        return []
    }

    public func appliesTo(_ s: Sex) -> Bool { sex == nil || sex == s }
}

public enum OrdinalPresets {
    public static let all: [String: [OrdinalOption]] = [
        "finding": [
            .init(value: 0, label: "정상", level: .normal),
            .init(value: 1, label: "추적 관찰", level: .borderline),
            .init(value: 2, label: "이상 소견", level: .abnormal),
        ],
        "negPos": [
            .init(value: 0, label: "음성", level: .normal),
            .init(value: 1, label: "양성", level: .abnormal),
        ],
        "antibody": [
            .init(value: 0, label: "음성 (항체 없음)", level: .borderline),
            .init(value: 1, label: "양성 (항체 있음)", level: .normal),
        ],
        "urine": [
            .init(value: 0, label: "음성", level: .normal),
            .init(value: 1, label: "약양성 (±)", level: .borderline),
            .init(value: 2, label: "양성 (1+)", level: .abnormal),
            .init(value: 3, label: "양성 (2+)", level: .abnormal),
            .init(value: 4, label: "양성 (3+ 이상)", level: .abnormal),
        ],
        "hearing": [
            .init(value: 0, label: "정상", level: .normal),
            .init(value: 1, label: "비정상", level: .abnormal),
        ],
    ]
}
