import Foundation
import SwiftData

/// 이전 버전(SwiftData, health.store)의 기록을 읽어 새 형식으로 옮김.
/// 원본을 건드리지 않도록 임시 복사본을 열어서 읽음. macOS 14 이상에서만 동작.
@available(macOS 14, *)
enum LegacyStore {
    static func read(storeURL: URL) throws -> [PersonDTO] {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("legacy-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        for suffix in ["", "-shm", "-wal"] {
            let src = URL(fileURLWithPath: storeURL.path + suffix)
            if fm.fileExists(atPath: src.path) {
                try fm.copyItem(at: src, to: tmp.appendingPathComponent("health.store" + suffix))
            }
        }

        let config = ModelConfiguration(url: tmp.appendingPathComponent("health.store"))
        let container = try ModelContainer(for: Person.self, FamilyHistoryEntry.self, Checkup.self, TestResult.self,
                                           configurations: config)
        let context = ModelContext(container)
        let people = try context.fetch(FetchDescriptor<Person>(sortBy: [SortDescriptor(\.createdAt)]))
        return people.map { p in
            PersonDTO(id: p.uid, name: p.name, sex: p.sexRaw, birthDate: p.birthDate, createdAt: p.createdAt,
                      smoking: p.smokingRaw, drinking: p.drinkingRaw, exercise: p.exerciseRaw,
                      conditions: p.conditionsRaw, memo: p.memo,
                      shownCodes: p.shownCodes, hiddenCodes: p.hiddenCodes,
                      familyHistory: p.familyHistory.map {
                          FamilyDTO(condition: $0.conditionRaw, relation: $0.relationRaw, onsetAge: $0.onsetAge)
                      },
                      checkups: p.checkups.sorted { $0.date < $1.date }.map { c in
                          CheckupDTO(id: UUID(), date: c.date, institution: c.institution, type: c.typeRaw,
                                     memo: c.memo,
                                     results: c.results.map { ResultDTO(code: $0.code, value: $0.value, note: $0.note) })
                      })
        }
    }

    // 이전 버전과 같은 이름·속성이어야 기존 파일을 그대로 읽을 수 있음

    @Model final class Person {
        var uid: UUID = UUID()
        var name: String = ""
        var sexRaw: String = ""
        var birthDate: Date = Date()
        var smokingRaw: String = ""
        var drinkingRaw: String = ""
        var exerciseRaw: String = ""
        var conditionsRaw: [String] = []
        var memo: String = ""
        var createdAt: Date = Date()
        var shownCodes: [String] = []
        var hiddenCodes: [String] = []
        @Relationship(deleteRule: .cascade, inverse: \Checkup.person)
        var checkups: [Checkup] = []
        @Relationship(deleteRule: .cascade, inverse: \FamilyHistoryEntry.person)
        var familyHistory: [FamilyHistoryEntry] = []
        init() {}
    }

    @Model final class FamilyHistoryEntry {
        var conditionRaw: String = ""
        var relationRaw: String = ""
        var onsetAge: Int?
        var person: Person?
        init() {}
    }

    @Model final class Checkup {
        var date: Date = Date()
        var institution: String = ""
        var typeRaw: String = ""
        var memo: String = ""
        var person: Person?
        @Relationship(deleteRule: .cascade, inverse: \TestResult.checkup)
        var results: [TestResult] = []
        init() {}
    }

    @Model final class TestResult {
        var code: String = ""
        var value: Double = 0
        var note: String = ""
        var checkup: Checkup?
        init() {}
    }
}
