import Foundation
import HealthCore

/// 둘러보기용 가상 데이터 (실제 인물 아님)
enum SampleData {
    @discardableResult
    static func insert(into context: HealthStore) -> Person {
        let cal = Calendar(identifier: .gregorian)
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

        // 1) 40대 남성: 대사 지표가 서서히 나빠지는 예
        let dad = Person(name: "샘플 아빠", sex: .male, birthDate: day(1984, 5, 10))
        dad.smoking = .former
        dad.drinking = .often
        dad.exercise = .sometimes
        context.insert(dad)
        for fh in [FamilyHistoryEntry(condition: .earlyHeartDisease, relation: .father, onsetAge: 52),
                   FamilyHistoryEntry(condition: .diabetes, relation: .mother, onsetAge: 61)] {
            context.insert(fh)
            fh.person = dad
        }

        let years = [2021, 2022, 2023, 2024, 2025]
        let types: [CheckupType] = [.national, .comprehensive, .national, .comprehensive, .comprehensive]
        // 시작값 → 끝값 사이를 해마다 채움
        let trend: [String: (Double, Double)] = [
            "HEIGHT": (174.2, 174.0), "WEIGHT": (74.5, 79.8), "WAIST": (85, 91.5),
            "SBP": (122, 136), "DBP": (78, 87), "FBS": (94, 108),
            "TC": (192, 231), "LDL": (118, 152), "HDL": (52, 43), "TG": (128, 196),
            "AST": (27, 39), "ALT": (31, 52), "GGT": (42, 71),
            "CR": (0.95, 1.04), "EGFR": (98, 89), "HB": (15.3, 15.0),
            "VIS_L": (1.0, 0.8), "VIS_R": (1.0, 0.9),
        ]
        let comprehensiveTrend: [String: (Double, Double)] = [
            "HBA1C": (5.4, 5.9), "BODYFAT": (21, 25.5), "URIC": (6.2, 7.4), "HSCRP": (0.6, 1.4),
            "TSH": (2.1, 2.4), "VITD": (18, 24), "AFP": (2.8, 3.1), "CEA": (1.9, 2.2),
            "CA199": (8, 9), "PSA": (0.7, 0.8), "WBC": (6.1, 6.6), "PLT": (238, 245), "BUN": (13, 15),
        ]
        for (i, y) in years.enumerated() {
            let t = Double(i) / Double(years.count - 1)
            let c = Checkup(date: day(y, 10, 15),
                            institution: types[i] == .national ? "○○내과의원" : "△△병원 건강증진센터",
                            type: types[i])
            context.insert(c)
            c.person = dad
            func add(_ code: String, _ v: Double, _ note: String = "") {
                let r = TestResult(code: code, value: v, note: note)
                context.insert(r)
                r.checkup = c
            }
            for (code, (a, b)) in trend { add(code, round(a + (b - a) * t, code)) }
            let h = 174.2 / 100, w = 74.5 + (79.8 - 74.5) * t
            add("BMI", (w / (h * h) * 10).rounded() / 10)
            add("UPRO", 0); add("HBSAG", 0); add("HEAR_L", 0); add("HEAR_R", 0)
            add("CXR", 0)
            if types[i] == .comprehensive {
                for (code, (a, b)) in comprehensiveTrend { add(code, round(a + (b - a) * t, code)) }
                add("HBSAB", 1); add("HCVAB", 0); add("ECG", 0)
                add("ABD_US", y >= 2024 ? 1 : 0, y >= 2024 ? "경도 지방간" : "")
                add("GASTRO", y == 2024 ? 1 : 0, y == 2024 ? "만성 표재성 위염" : "")
            }
            if y == 2025 { add("COLONO", 1, "용종 1개 제거 (조직검사: 선종)"); add("FOBT", 0) }
        }

        // 2) 60대 여성: 성별·나이에 따라 기준이 달라지는 예
        let mom = Person(name: "샘플 엄마", sex: .female, birthDate: day(1959, 3, 2))
        mom.conditions = [.hypertension]
        context.insert(mom)
        let fh = FamilyHistoryEntry(condition: .osteoporosis, relation: .mother)
        context.insert(fh)
        fh.person = mom
        let momData: [(Int, [String: Double])] = [
            (2023, ["HEIGHT": 158, "WEIGHT": 56, "BMI": 22.4, "WAIST": 82, "SBP": 132, "DBP": 82, "FBS": 98,
                    "TC": 214, "LDL": 128, "HDL": 58, "TG": 140, "AST": 24, "ALT": 19, "GGT": 22,
                    "CR": 0.78, "EGFR": 76, "HB": 12.4, "BMD_T": -1.8, "UPRO": 0, "MAMMO": 0, "PAP": 0]),
            (2025, ["HEIGHT": 157.6, "WEIGHT": 57, "BMI": 22.9, "WAIST": 83.5, "SBP": 128, "DBP": 80, "FBS": 101,
                    "TC": 205, "LDL": 121, "HDL": 61, "TG": 132, "AST": 26, "ALT": 21, "GGT": 24,
                    "CR": 0.81, "EGFR": 72, "HB": 12.1, "BMD_T": -2.3, "UPRO": 0, "MAMMO": 1, "PAP": 0,
                    "TSH": 4.9, "VITD": 21, "CA125": 12, "HBA1C": 5.8]),
        ]
        for (y, values) in momData {
            let c = Checkup(date: day(y, 6, 20), institution: "△△병원 건강증진센터", type: y == 2025 ? .comprehensive : .national)
            context.insert(c)
            c.person = mom
            for (code, v) in values {
                let r = TestResult(code: code, value: v, note: code == "MAMMO" && v > 0 ? "치밀유방, 6개월 후 추적 권유" : "")
                context.insert(r)
                r.checkup = c
            }
        }

        try? context.save()
        return dad
    }

    private static func round(_ v: Double, _ code: String) -> Double {
        let digits = Catalog.shared.item(code)?.fractionDigits ?? 0
        let p = pow(10, Double(digits))
        return (v * p).rounded() / p
    }
}
