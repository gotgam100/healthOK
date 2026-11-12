import Foundation
import Testing
@testable import HealthCore

private let ev = Evaluator()
private let man40 = PersonContext(sex: .male, age: 40)
private let woman40 = PersonContext(sex: .female, age: 40)

private func level(_ code: String, _ v: Double, _ ctx: PersonContext = man40) -> Level? {
    ev.judge(code: code, value: v, context: ctx)?.level
}

// MARK: - 내장 데이터 무결성

@Test func catalogLoads() throws {
    let c = try Catalog.loadBundled()
    #expect(c.items.count > 50)
    #expect(Set(c.items.map(\.code)).count == c.items.count, "항목 코드가 중복되면 안 됩니다")
}

@Test func everyRuleReferencesNumericItem() {
    for rule in Catalog.shared.rules {
        let item = Catalog.shared.item(rule.item)
        #expect(item != nil, "규칙 \(rule.item)의 항목이 사전에 없습니다")
        #expect(item?.kind == .numeric, "\(rule.item)은 숫자 항목이어야 합니다")
    }
}

@Test func bandsAreOrderedAndContiguous() {
    for rule in Catalog.shared.rules {
        #expect(rule.bands.first?.min == nil, "\(rule.item): 첫 구간은 하한이 없어야 합니다")
        #expect(rule.bands.last?.max == nil, "\(rule.item): 마지막 구간은 상한이 없어야 합니다")
        for (a, b) in zip(rule.bands, rule.bands.dropFirst()) {
            #expect(a.max == b.min, "\(rule.item): 구간 사이에 빈틈이 있습니다 (\(String(describing: a.max)) / \(String(describing: b.min)))")
            // 경계값은 정확히 한 구간에만 속해야 함
            let edgeInA = a.maxInclusive ?? false
            let edgeInB = b.minInclusive ?? true
            #expect(edgeInA != edgeInB, "\(rule.item): 경계값 \(String(describing: a.max)) 포함 여부가 겹치거나 비어 있습니다")
        }
    }
}

@Test func everyNumericItemExceptHeightHasRule() {
    let ruleItems = Set(Catalog.shared.rules.map(\.item))
    let noRuleOK: Set<String> = ["HEIGHT", "WEIGHT"]
    for item in Catalog.shared.items where item.kind == .numeric && !noRuleOK.contains(item.code) {
        #expect(ruleItems.contains(item.code), "\(item.code)에 기준치 규칙이 없습니다")
    }
}

@Test func ordinalItemsHaveOptions() {
    for item in Catalog.shared.items where item.kind == .ordinal {
        #expect(!item.resolvedOptions.isEmpty, "\(item.code)에 선택지가 없습니다")
    }
}

// MARK: - 경계값

@Test func fastingGlucoseBoundaries() {
    #expect(level("FBS", 69) == .borderline)
    #expect(level("FBS", 70) == .normal)
    #expect(level("FBS", 99) == .normal)
    #expect(level("FBS", 100) == .borderline)
    #expect(level("FBS", 125) == .borderline)
    #expect(level("FBS", 126) == .abnormal)
    #expect(ev.judge(code: "FBS", value: 110, context: man40)?.label == "공복혈당장애")
}

@Test func bloodPressureBoundaries() {
    #expect(level("SBP", 119) == .normal)
    #expect(level("SBP", 120) == .borderline)
    #expect(level("SBP", 139) == .borderline)
    #expect(level("SBP", 140) == .abnormal)
    #expect(level("DBP", 79) == .normal)
    #expect(level("DBP", 90) == .abnormal)
}

@Test func inclusiveUpperBoundaries() {
    #expect(level("AST", 40) == .normal)
    #expect(level("AST", 40.5) == .borderline)
    #expect(level("AST", 50) == .borderline)
    #expect(level("AST", 51) == .abnormal)
}

// MARK: - 성별 차이

@Test func sexSpecificRules() {
    // 혈색소 12.5: 남성은 약간 낮음, 여성은 정상
    #expect(level("HB", 12.5, man40) == .borderline)
    #expect(level("HB", 12.5, woman40) == .normal)
    // 감마지티피 50: 남성 정상, 여성 이상
    #expect(level("GGT", 50, man40) == .normal)
    #expect(level("GGT", 50, woman40) == .abnormal)
    // 허리둘레 87: 남성 주의, 여성 이상
    #expect(level("WAIST", 87, man40) == .borderline)
    #expect(level("WAIST", 87, woman40) == .abnormal)
    // HDL 45: 남성 정상, 여성 주의
    #expect(level("HDL", 45, man40) == .normal)
    #expect(level("HDL", 45, woman40) == .borderline)
}

@Test func sexOnlyItems() {
    let c = Catalog.shared
    #expect(c.items(for: .female).contains { $0.code == "PSA" } == false)
    #expect(c.items(for: .male).contains { $0.code == "MAMMO" } == false)
    #expect(ev.judge(code: "PSA", value: 1, context: woman40) == nil)
}

// MARK: - 나이 차이

@Test func ageSpecificRules() {
    let man55 = PersonContext(sex: .male, age: 55)
    let man72 = PersonContext(sex: .male, age: 72)
    // PSA 3.0: 40대 기준 초과, 50대 정상
    #expect(level("PSA", 3.0, man40) == .borderline)
    #expect(level("PSA", 3.0, man55) == .normal)
    #expect(level("PSA", 6.0, man72) == .normal)
    // eGFR 75: 60세 미만은 경도 감소, 60세 이상은 정상
    #expect(level("EGFR", 75, man40) == .borderline)
    let j = ev.judge(code: "EGFR", value: 75, context: man72)
    #expect(j?.level == .normal)
    #expect(j?.notes.isEmpty == false)
}

@Test func ageCalculation() {
    let cal = Calendar(identifier: .gregorian)
    let birth = cal.date(from: DateComponents(year: 1984, month: 5, day: 10))!
    let before = cal.date(from: DateComponents(year: 2025, month: 5, day: 9))!
    let after = cal.date(from: DateComponents(year: 2025, month: 5, day: 10))!
    #expect(PersonContext.age(birthDate: birth, at: before) == 40)
    #expect(PersonContext.age(birthDate: birth, at: after) == 41)
}

// MARK: - 선택형 항목·표시

@Test func ordinalJudgment() {
    #expect(level("UPRO", 0) == .normal)
    #expect(level("UPRO", 1) == .borderline)
    #expect(level("UPRO", 3) == .abnormal)
    #expect(level("HBSAB", 0) == .borderline)
    #expect(ev.judge(code: "ABD_US", value: 1, context: man40)?.label == "추적 관찰")
}

@Test func referenceTexts() {
    #expect(ev.referenceText(code: "FBS", context: man40) == "70 ~ 100")
    #expect(ev.referenceText(code: "AST", context: man40) == "40 이하")
    #expect(ev.referenceText(code: "HDL", context: man40) == "40 이상")
    #expect(ev.referenceText(code: "HB", context: woman40) == "12.0 ~ 15.5")
}

@Test func organLevelsTakeWorst() {
    let judged: [(code: String, judgment: Judgment)] = [
        ("AST", ev.judge(code: "AST", value: 30, context: man40)!),
        ("ALT", ev.judge(code: "ALT", value: 60, context: man40)!),
        ("FBS", ev.judge(code: "FBS", value: 105, context: man40)!),
    ]
    let organs = ev.organLevels(judged)
    #expect(organs[.liver] == .abnormal)
    #expect(organs[.pancreas] == .borderline)
    #expect(organs[.kidney] == nil)
}

// MARK: - 기본 항목 (사용자 검진표 기준)

@Test func basicItemsMatchCheckupSheet() {
    let expected: Set<String> = [
        "HEIGHT", "WEIGHT", "WAIST", "BMI", "VIS_L", "VIS_R", "HEAR_L", "HEAR_R", "SBP", "DBP",
        "TC", "HDL", "TG", "LDL", "CR", "EGFR", "AST", "ALT", "GGT", "UPRO", "HB", "FBS",
        "CXR", "HBSAG", "HBSAB",
    ]
    let basic = Set(Catalog.shared.items.filter(\.isBasic).map(\.code))
    #expect(basic == expected)
    // 기본 항목은 남녀 공통이어야 함
    for code in expected { #expect(Catalog.shared.item(code)?.sex == nil) }
}

// MARK: - 전립선

@Test func prostateItems() {
    let c = Catalog.shared
    for code in ["PSA", "FPSA_RATIO", "PROSTATE_US", "PROSTATE_VOL", "IPSS"] {
        #expect(c.item(code)?.category == .mens)
        #expect(c.items(for: .female).contains { $0.code == code } == false)
    }
    #expect(level("FPSA_RATIO", 8, man40) == .abnormal)
    #expect(level("FPSA_RATIO", 10, man40) == .borderline)
    #expect(level("FPSA_RATIO", 25, man40) == .borderline)
    #expect(level("FPSA_RATIO", 30, man40) == .normal)
    #expect(level("PROSTATE_VOL", 30, man40) == .normal)
    #expect(level("PROSTATE_VOL", 35, man40) == .borderline)
    #expect(level("PROSTATE_VOL", 60, man40) == .abnormal)
    #expect(level("IPSS", 7, man40) == .normal)
    #expect(level("IPSS", 8, man40) == .borderline)
    #expect(level("IPSS", 20, man40) == .abnormal)
    #expect(level("PROSTATE_US", 0, man40) == .normal)
}
