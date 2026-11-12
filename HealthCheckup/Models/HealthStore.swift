import Foundation
import AppKit
import Combine
import HealthCore

/// 모든 기록을 JSON 파일 하나에 저장하는 저장소.
/// 저장 파일과 내보내기 파일의 형식이 같아서, 파일만 옮기면 다른 맥에서도 그대로 열림.
final class HealthStore: ObservableObject {
    static let shared = HealthStore()
    /// 불러오기가 끝난 뒤에만 값이 있음 (불러오는 동안 생긴 변경은 저장 예약하지 않음)
    private(set) static var active: HealthStore?

    @Published private(set) var people: [Person] = []
    let url: URL
    /// 시작할 때 생긴 문제 (이전 데이터 옮기기 실패 등). 화면에서 알려줌.
    @Published var startupMessage: String?

    private var saveScheduled = false
    private var backedUp = false

    private init() {
        // 테스트할 때는 HEALTHCHECKUP_STORE 환경변수로 다른 파일을 쓸 수 있음
        if let custom = ProcessInfo.processInfo.environment["HEALTHCHECKUP_STORE"] {
            url = URL(fileURLWithPath: custom)
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("HealthCheckup", isDirectory: true)
            url = dir.appendingPathComponent("health.json")
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        load()
        Self.active = self
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { try? HealthStore.shared.save() }
        }
    }

    // MARK: 불러오기

    private func load() {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let file = try BackupFile.decode(Data(contentsOf: url))
                people = file.people.map { $0.makePerson() }
            } catch {
                // 파일을 못 읽으면 덮어쓰지 않도록 옆에 복사해 두고 알림
                let broken = url.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: url, to: broken)
                startupMessage = "저장 파일을 읽지 못했습니다. 원본은 \(broken.lastPathComponent)로 보관했습니다.\n\(error.localizedDescription)"
            }
            return
        }
        // 이전 버전(SwiftData) 저장소가 있으면 한 번만 옮겨옴. 원본은 지우지 않음.
        let legacy = url.deletingLastPathComponent().appendingPathComponent("health.store")
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        if #available(macOS 14, *) {
            do {
                let dtos = try LegacyStore.read(storeURL: legacy)
                people = dtos.map { $0.makePerson() }
                try write()
            } catch {
                startupMessage = "이전 버전의 기록을 옮기지 못했습니다: \(error.localizedDescription)"
            }
        }
    }

    // MARK: 저장

    /// 값이 바뀌면 화면을 갱신하고 잠시 뒤 저장
    func markDirty() {
        objectWillChange.send()
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            saveScheduled = false
            try? write()
        }
    }

    /// 바로 저장 (SwiftData 시절 코드와 같은 이름)
    func save() throws {
        saveScheduled = false
        try write()
    }

    private func write() throws {
        // 이번 실행에서 처음 저장할 때 직전 파일을 .bak으로 남김
        if !backedUp, FileManager.default.fileExists(atPath: url.path) {
            let bak = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: bak)
            try? FileManager.default.copyItem(at: url, to: bak)
            backedUp = true
        }
        try BackupFile(people: people.map(PersonDTO.init)).encoded().write(to: url, options: .atomic)
    }

    // MARK: 추가·삭제 (화면 코드는 예전 modelContext처럼 씀)

    func insert(_ record: Record) {
        if let p = record as? Person, !people.contains(where: { $0 === p }) { people.append(p) }
        markDirty()
    }

    func delete(_ record: Record) {
        switch record {
        case let p as Person: people.removeAll { $0 === p }
        case let c as Checkup: c.person = nil
        case let r as TestResult: r.checkup = nil
        case let e as FamilyHistoryEntry: e.person = nil
        default: break
        }
        markDirty()
    }

    // MARK: 내보내기·가져오기

    func exportData(_ people: [Person]) throws -> Data {
        try BackupFile(people: people.map(PersonDTO.init)).encoded()
    }

    /// 다른 맥에서 내보낸 파일을 합침. 같은 사람(같은 ID, 또는 같은 이름·생년월일)이면
    /// 빠진 검진·값만 채우고 기존 값은 바꾸지 않음. 처음 보는 사람은 새로 추가.
    func importBackup(_ data: Data) throws -> String {
        let file = try BackupFile.decode(data)
        var lines: [String] = []
        let cal = Calendar.current
        for dto in file.people {
            let match = people.first { $0.uid == dto.id }
                ?? people.first { $0.name == dto.name && cal.isDate($0.birthDate, inSameDayAs: dto.birthDate) }
            guard let person = match else {
                let p = dto.makePerson()
                people.append(p)
                let n = p.checkups.reduce(0) { $0 + $1.results.count }
                lines.append("\(p.name): 새 구성원으로 추가 (검진 \(p.checkups.count)건, 값 \(n)개)")
                continue
            }
            var newCheckups = 0, added = 0, conflicts: [String] = []
            for fh in dto.familyHistory ?? [] where !person.familyHistory.contains(where: {
                $0.conditionRaw == fh.condition && $0.relationRaw == fh.relation }) {
                fh.makeEntry().person = person
            }
            for c in dto.checkups {
                let existing = person.checkups.first { $0.id == c.id }
                    ?? person.checkups.first { abs($0.date.timeIntervalSince(c.date)) <= 2 * 86_400 }
                guard let target = existing else {
                    c.makeCheckup().person = person
                    newCheckups += 1
                    continue
                }
                if target.institution.isEmpty, let i = c.institution { target.institution = i }
                for r in c.results {
                    if let old = target.result(r.code) {
                        if abs(old.value - r.value) > 0.0001 {
                            let name = Catalog.shared.item(r.code)?.name ?? r.code
                            conflicts.append("\(target.date.ymd) \(name)")
                        } else if old.note.isEmpty, let n = r.note, !n.isEmpty {
                            old.note = n
                        }
                    } else {
                        TestResult(code: r.code, value: r.value, note: r.note ?? "").checkup = target
                        added += 1
                    }
                }
            }
            var line = "\(person.name): 새 검진 \(newCheckups)건, 기존 검진에 채운 값 \(added)개"
            if !conflicts.isEmpty { line += "\n  값이 달라 그대로 둔 항목: " + conflicts.joined(separator: ", ") }
            lines.append(line)
        }
        markDirty()
        try save()
        return lines.isEmpty ? "가져올 구성원이 없습니다." : lines.joined(separator: "\n")
    }
}

// MARK: - 파일 형식

/// 저장·내보내기 공통 형식 (사람이 읽을 수 있는 JSON)
nonisolated struct BackupFile: Codable {
    var format = "건강하면됐지"
    var version = 1
    var savedAt = Date()
    var people: [PersonDTO]

    init(people: [PersonDTO]) { self.people = people }

    func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return try e.encode(self)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        let file = try d.decode(BackupFile.self, from: data)
        guard file.format == "건강하면됐지" else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "건강하면됐지 기록 파일이 아닙니다."])
        }
        return file
    }
}

nonisolated struct PersonDTO: Codable {
    var id: UUID
    var name: String
    var sex: String
    var birthDate: Date
    var createdAt: Date?
    var smoking: String?
    var drinking: String?
    var exercise: String?
    var conditions: [String]?
    var memo: String?
    var shownCodes: [String]?
    var hiddenCodes: [String]?
    var familyHistory: [FamilyDTO]?
    var checkups: [CheckupDTO]
}

nonisolated struct FamilyDTO: Codable {
    var condition: String
    var relation: String
    var onsetAge: Int?
}

nonisolated struct CheckupDTO: Codable {
    var id: UUID
    var date: Date
    var institution: String?
    var type: String?
    var memo: String?
    var results: [ResultDTO]
}

nonisolated struct ResultDTO: Codable {
    var code: String
    var value: Double
    var note: String?
}

extension PersonDTO {
    init(_ p: Person) {
        self.init(id: p.uid, name: p.name, sex: p.sexRaw, birthDate: p.birthDate, createdAt: p.createdAt,
                  smoking: p.smokingRaw, drinking: p.drinkingRaw, exercise: p.exerciseRaw,
                  conditions: p.conditionsRaw, memo: p.memo,
                  shownCodes: p.shownCodes, hiddenCodes: p.hiddenCodes,
                  familyHistory: p.familyHistory.map {
                      FamilyDTO(condition: $0.conditionRaw, relation: $0.relationRaw, onsetAge: $0.onsetAge)
                  },
                  checkups: p.sortedCheckups.map(CheckupDTO.init))
    }

    func makePerson() -> Person {
        let p = Person(name: name, sex: Sex(rawValue: sex) ?? .male, birthDate: birthDate)
        p.uid = id
        p.createdAt = createdAt ?? Date()
        if let smoking { p.smokingRaw = smoking }
        if let drinking { p.drinkingRaw = drinking }
        if let exercise { p.exerciseRaw = exercise }
        p.conditionsRaw = conditions ?? []
        p.memo = memo ?? ""
        p.shownCodes = shownCodes ?? []
        p.hiddenCodes = hiddenCodes ?? []
        p.familyHistory = (familyHistory ?? []).map { $0.makeEntry() }
        p.checkups = checkups.map { $0.makeCheckup() }
        return p
    }
}

extension FamilyDTO {
    func makeEntry() -> FamilyHistoryEntry {
        FamilyHistoryEntry(condition: FamilyCondition(rawValue: condition) ?? .diabetes,
                           relation: Relation(rawValue: relation) ?? .father, onsetAge: onsetAge)
    }
}

extension CheckupDTO {
    init(_ c: Checkup) {
        self.init(id: c.id, date: c.date, institution: c.institution, type: c.typeRaw, memo: c.memo,
                  results: c.results.sorted { $0.code < $1.code }.map {
                      ResultDTO(code: $0.code, value: $0.value, note: $0.note.isEmpty ? nil : $0.note)
                  })
    }

    func makeCheckup() -> Checkup {
        let c = Checkup(date: date, institution: institution ?? "",
                        type: type.flatMap(CheckupType.init(rawValue:)) ?? .national)
        c.id = id
        c.memo = memo ?? ""
        c.results = results.map { TestResult(code: $0.code, value: $0.value, note: $0.note ?? "") }
        return c
    }
}
