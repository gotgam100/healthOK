import Foundation
import Combine
import HealthCore

// 기록 객체들은 JSON 파일(HealthStore)에 저장됨. macOS 13에서도 돌도록 SwiftData를 쓰지 않음.

/// 모든 기록 객체의 바탕. @Published 값이 바뀌면 화면을 갱신하고 저장을 예약함.
class Record: ObservableObject {
    private var watch: AnyCancellable?

    init() {
        watch = objectWillChange.sink { _ in
            HealthStore.active?.markDirty()   // 불러오는 중에는 nil
        }
    }
}

/// 가족 구성원 한 명
final class Person: Record, Identifiable {
    @Published var uid: UUID = UUID()
    @Published var name: String = ""
    @Published var sexRaw: String = Sex.male.rawValue
    @Published var birthDate: Date = Date()
    @Published var smokingRaw: String = Smoking.never.rawValue
    @Published var drinkingRaw: String = Drinking.none.rawValue
    @Published var exerciseRaw: String = Exercise.sometimes.rawValue
    @Published var conditionsRaw: [String] = []
    @Published var memo: String = ""
    @Published var createdAt: Date = Date()
    /// 항목 표시 설정: 직접 켠 항목 / 직접 끈 항목 (나머지는 기본 규칙)
    @Published var shownCodes: [String] = []
    @Published var hiddenCodes: [String] = []

    @Published private var checkupList: [Checkup] = []
    @Published private var familyList: [FamilyHistoryEntry] = []

    var id: UUID { uid }

    /// 배열에 넣으면 각 검진의 person이 자동으로 이 사람이 됨
    var checkups: [Checkup] {
        get { checkupList }
        set {
            checkupList = newValue
            newValue.forEach { $0.owner = self }
        }
    }
    var familyHistory: [FamilyHistoryEntry] {
        get { familyList }
        set {
            familyList = newValue
            newValue.forEach { $0.owner = self }
        }
    }

    init(name: String, sex: Sex, birthDate: Date) {
        super.init()
        self.name = name
        self.sexRaw = sex.rawValue
        self.birthDate = birthDate
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }
    var smoking: Smoking {
        get { Smoking(rawValue: smokingRaw) ?? .never }
        set { smokingRaw = newValue.rawValue }
    }
    var drinking: Drinking {
        get { Drinking(rawValue: drinkingRaw) ?? .none }
        set { drinkingRaw = newValue.rawValue }
    }
    var exercise: Exercise {
        get { Exercise(rawValue: exerciseRaw) ?? .sometimes }
        set { exerciseRaw = newValue.rawValue }
    }
    var conditions: Set<Condition> {
        get { Set(conditionsRaw.compactMap(Condition.init(rawValue:))) }
        set { conditionsRaw = newValue.map(\.rawValue).sorted() }
    }

    var age: Int { PersonContext.age(birthDate: birthDate, at: .now) }

    var sortedCheckups: [Checkup] { checkups.sorted { $0.date < $1.date } }

    /// 한 번이라도 기록된 항목 코드
    var recordedCodes: Set<String> { Set(checkups.flatMap { $0.results.map(\.code) }) }

    /// 기본 규칙: 기본 항목이거나 기록이 있으면 표시
    func isDefaultVisible(_ item: TestItem, recorded: Set<String>) -> Bool {
        item.isBasic || recorded.contains(item.code)
    }

    /// 표시 여부 (직접 켜고 끈 설정이 기본 규칙보다 우선)
    func isVisible(_ item: TestItem, recorded: Set<String>) -> Bool {
        if hiddenCodes.contains(item.code) { return false }
        if shownCodes.contains(item.code) { return true }
        return isDefaultVisible(item, recorded: recorded)
    }

    func setVisible(_ code: String, _ on: Bool) {
        shownCodes.removeAll { $0 == code }
        hiddenCodes.removeAll { $0 == code }
        if on { shownCodes.append(code) } else { hiddenCodes.append(code) }
    }

    /// 특정 날짜(검진일) 기준 판정용 정보
    func context(at date: Date) -> PersonContext {
        PersonContext(
            sex: sex,
            age: PersonContext.age(birthDate: birthDate, at: date),
            conditions: conditions,
            familyHistory: familyHistory.map {
                .init(condition: $0.condition, relation: $0.relation, onsetAge: $0.onsetAge)
            },
            smoking: smoking
        )
    }
}

final class FamilyHistoryEntry: Record, Identifiable {
    let id = UUID()
    @Published var conditionRaw: String = FamilyCondition.diabetes.rawValue
    @Published var relationRaw: String = Relation.father.rawValue
    @Published var onsetAge: Int?
    weak var owner: Person?

    init(condition: FamilyCondition, relation: Relation, onsetAge: Int? = nil) {
        super.init()
        self.conditionRaw = condition.rawValue
        self.relationRaw = relation.rawValue
        self.onsetAge = onsetAge
    }

    /// 값을 넣으면 그 사람의 가족력 목록으로 옮겨짐 (nil이면 목록에서 빠짐)
    var person: Person? {
        get { owner }
        set {
            guard owner !== newValue else { return }
            owner?.familyHistory.removeAll { $0 === self }
            owner = nil
            newValue?.familyHistory.append(self)
        }
    }

    var condition: FamilyCondition {
        get { FamilyCondition(rawValue: conditionRaw) ?? .diabetes }
        set { conditionRaw = newValue.rawValue }
    }
    var relation: Relation {
        get { Relation(rawValue: relationRaw) ?? .father }
        set { relationRaw = newValue.rawValue }
    }
}

enum CheckupType: String, CaseIterable, Identifiable {
    case national, comprehensive, other
    var id: String { rawValue }
    var nameKo: String {
        switch self {
        case .national: "일반검진"
        case .comprehensive: "종합검진"
        case .other: "기타"
        }
    }
}

/// 한 번의 검진
final class Checkup: Record, Identifiable {
    @Published var id: UUID = UUID()
    @Published var date: Date = Date()
    @Published var institution: String = ""
    @Published var typeRaw: String = CheckupType.national.rawValue
    @Published var memo: String = ""
    @Published private var resultList: [TestResult] = []
    weak var owner: Person?

    init(date: Date, institution: String = "", type: CheckupType = .national) {
        super.init()
        self.date = date
        self.institution = institution
        self.typeRaw = type.rawValue
    }

    var person: Person? {
        get { owner }
        set {
            guard owner !== newValue else { return }
            owner?.checkups.removeAll { $0 === self }
            owner = nil
            newValue?.checkups.append(self)
        }
    }

    var results: [TestResult] {
        get { resultList }
        set {
            resultList = newValue
            newValue.forEach { $0.owner = self }
        }
    }

    var type: CheckupType {
        get { CheckupType(rawValue: typeRaw) ?? .national }
        set { typeRaw = newValue.rawValue }
    }

    func result(_ code: String) -> TestResult? { results.first { $0.code == code } }
}

/// 검사 항목 하나의 결과값. 선택형 항목은 선택지 번호를 value에 저장.
final class TestResult: Record, Identifiable {
    let id = UUID()
    @Published var code: String = ""
    @Published var value: Double = 0
    /// 소견 원문 등 메모
    @Published var note: String = ""
    weak var owner: Checkup?

    init(code: String, value: Double, note: String = "") {
        super.init()
        self.code = code
        self.value = value
        self.note = note
    }

    var checkup: Checkup? {
        get { owner }
        set {
            guard owner !== newValue else { return }
            owner?.results.removeAll { $0 === self }
            owner = nil
            newValue?.results.append(self)
        }
    }
}
