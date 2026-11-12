import Foundation
import HealthCore

/// 검진 기록 JSON 가져오기.
///
/// 형식:
/// ```json
/// { "checkups": [
///   { "date": "2024-11-22", "institution": "○○병원", "type": "national",
///     "results": { "HEIGHT": 185.5, "HBSAG": { "value": 0, "note": "0.475" }, "UPRO": "음성" } }
/// ] }
/// ```
/// - 값은 숫자, 선택지 이름(문자열), 또는 `{ "value": 숫자, "note": "메모" }`.
/// - 날짜가 2일 이내인 기존 검진이 있으면 같은 검진으로 보고, **비어 있는 항목만** 채움 (기존 값은 바꾸지 않음).
enum CheckupImporter {
    struct Report {
        var createdCheckups: [Date] = []
        var mergedCheckups: [Date] = []
        var added = 0
        var skippedSame = 0
        /// 기존 값과 달라서 건너뛴 항목
        var conflicts: [String] = []
        var unknown: [String] = []

        var summary: String {
            var lines: [String] = []
            if !createdCheckups.isEmpty {
                lines.append("새 검진 \(createdCheckups.count)건: " + createdCheckups.map(\.ymd).joined(separator: ", "))
            }
            if !mergedCheckups.isEmpty {
                lines.append("기존 검진에 합침 \(mergedCheckups.count)건: " + mergedCheckups.map(\.ymd).joined(separator: ", "))
            }
            lines.append("추가한 값 \(added)개, 이미 같은 값 \(skippedSame)개")
            if !conflicts.isEmpty {
                lines.append("기존 값과 달라 그대로 둔 항목:\n  " + conflicts.joined(separator: "\n  "))
            }
            if !unknown.isEmpty { lines.append("알 수 없는 항목: " + unknown.joined(separator: ", ")) }
            return lines.joined(separator: "\n")
        }
    }

    private struct File: Decodable {
        let checkups: [Entry]
    }
    private struct Entry: Decodable {
        let date: String
        let institution: String?
        let type: String?
        let memo: String?
        let results: [String: Value]
    }
    private enum Value: Decodable {
        case number(Double, note: String?)
        case label(String, note: String?)

        private enum Keys: String, CodingKey { case value, note }

        init(from decoder: Decoder) throws {
            if let c = try? decoder.singleValueContainer() {
                if let d = try? c.decode(Double.self) { self = .number(d, note: nil); return }
                if let s = try? c.decode(String.self) { self = .label(s, note: nil); return }
            }
            let k = try decoder.container(keyedBy: Keys.self)
            let note = try k.decodeIfPresent(String.self, forKey: .note)
            if let d = try? k.decode(Double.self, forKey: .value) { self = .number(d, note: note); return }
            self = .label(try k.decode(String.self, forKey: .value), note: note)
        }
    }

    static func importJSON(_ data: Data, into person: Person, context: HealthStore) throws -> Report {
        let file = try JSONDecoder().decode(File.self, from: data)
        let catalog = Catalog.shared
        var report = Report()
        let cal = Calendar(identifier: .gregorian)

        for entry in file.checkups {
            let parts = entry.date.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3,
                  let date = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
            else { throw CocoaError(.coderInvalidValue, userInfo: [NSDebugDescriptionErrorKey: "날짜 형식 오류: \(entry.date)"]) }

            // 2일 이내 기존 검진이면 합침
            let existing = person.checkups.first { abs($0.date.timeIntervalSince(date)) <= 2 * 86_400 }
            let checkup: Checkup
            if let existing {
                checkup = existing
                report.mergedCheckups.append(existing.date)
                if checkup.institution.isEmpty, let i = entry.institution { checkup.institution = i }
            } else {
                checkup = Checkup(date: date, institution: entry.institution ?? "",
                                  type: entry.type.flatMap(CheckupType.init(rawValue:)) ?? .national)
                checkup.memo = entry.memo ?? ""
                context.insert(checkup)
                checkup.person = person
                report.createdCheckups.append(date)
            }

            for (code, raw) in entry.results.sorted(by: { $0.key < $1.key }) {
                guard let item = catalog.item(code) else { report.unknown.append(code); continue }
                let value: Double, note: String?
                switch raw {
                case let .number(d, n): value = d; note = n
                case let .label(s, n):
                    guard let opt = item.resolvedOptions.first(where: { $0.label == s || $0.label.hasPrefix(s) }) else {
                        report.unknown.append("\(code)=\(s)"); continue
                    }
                    value = Double(opt.value); note = n
                }
                if let r = checkup.result(code) {
                    if abs(r.value - value) < 0.0001 {
                        report.skippedSame += 1
                        if r.note.isEmpty, let note { r.note = note }
                    } else {
                        report.conflicts.append("\(checkup.date.ymd) \(item.name): 저장된 값 \(item.display(r.value)), 가져온 값 \(item.display(value))")
                    }
                    continue
                }
                let r = TestResult(code: code, value: value, note: note ?? "")
                context.insert(r)
                r.checkup = checkup
                report.added += 1
            }
        }
        try context.save()
        return report
    }
}
