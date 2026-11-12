import AppKit
import UniformTypeIdentifiers
import HealthCore

/// AI(챗봇 등)에 붙여 넣거나 올려서 물어보기 좋은 Markdown 요약 만들기
enum MarkdownExport {
    struct Options {
        /// 이름·생년월일 대신 "본인"·나이만 적기
        var hideIdentity = true
    }

    static func make(_ people: [Person], options: Options = .init(), today: Date = .now) -> String {
        var md: [String] = []
        md.append("# 건강검진 기록")
        md.append("")
        md.append("- 내보낸 날: \(day(today)) (건강하면됐지 앱)")
        md.append("- 판정(정상·주의·이상)과 참고치는 앱에 들어 있는 일반 기준(성별·나이 반영)으로 계산한 것이며, 의료진의 진단이 아닙니다.")
        md.append("- 표의 빈칸(—)은 그 검진에서 하지 않았거나 기록하지 않은 항목입니다.")
        md.append("")
        for (i, p) in people.enumerated() {
            md += person(p, index: i, count: people.count, options: options)
        }
        md.append("---")
        md.append("")
        md.append("## AI에게 물어볼 때 예시")
        md.append("")
        md.append("- 위 기록에서 가장 신경 써야 할 항목과 그 이유를 알려 주세요.")
        md.append("- 해마다 나빠지고 있는 수치가 있나요? 어떤 생활 습관을 바꾸면 좋을까요?")
        md.append("- 다음 검진이나 진료 때 의사에게 물어볼 질문을 정리해 주세요.")
        md.append("- 소견 메모에 나온 의학 용어를 쉽게 풀어 설명해 주세요.")
        md.append("")
        return md.joined(separator: "\n")
    }

    // MARK: - 구성원 한 명

    private static func person(_ p: Person, index: Int, count: Int, options: Options) -> [String] {
        let evaluator = Evaluator()
        let catalog = evaluator.catalog
        let checkups = p.sortedCheckups
        var md: [String] = []

        let title = options.hideIdentity ? (count > 1 ? "구성원 \(index + 1)" : "본인") : p.name
        md.append("## \(title) (\(p.sex.nameKo), \(p.age)세)")
        md.append("")

        // 기본 정보
        md.append("### 기본 정보")
        md.append("")
        md.append("- 성별: \(p.sex.nameKo)")
        if options.hideIdentity {
            md.append("- 나이: \(p.age)세")
        } else {
            md.append("- 나이: \(p.age)세 (생년월일 \(day(p.birthDate)))")
        }
        md.append("- 흡연: \(p.smoking.nameKo)")
        md.append("- 음주: \(p.drinking.nameKo)")
        md.append("- 운동: \(p.exercise.nameKo)")
        let conds = p.conditions.map(\.nameKo).sorted()
        md.append("- 진단받은 질환: \(conds.isEmpty ? "없음" : conds.joined(separator: ", "))")
        let family = p.familyHistory.map { f in
            "\(f.relation.nameKo) \(f.condition.nameKo)" + (f.onsetAge.map { " (\($0)세 발병)" } ?? "")
        }
        md.append("- 가족력: \(family.isEmpty ? "없음" : family.joined(separator: ", "))")
        if !p.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            md.append("- 메모: \(oneLine(p.memo))")
        }
        md.append("")

        guard let last = checkups.last else {
            md.append("검진 기록이 없습니다.")
            md.append("")
            return md
        }

        // 최근 상태: 최근 검진 기준, 이번에 없는 항목은 마지막 값으로
        let snap = p.snapshot(at: last, evaluator: evaluator)
        let flagged = snap.results
            .filter { ($0.judgment?.level ?? .normal) != .normal }
            .sorted { ($0.judgment?.level ?? .normal) > ($1.judgment?.level ?? .normal) }
        md.append("### 최근 상태 요약 (\(day(last.date)) 검진 기준)")
        md.append("")
        if flagged.isEmpty {
            md.append("- 주의·이상 항목이 없습니다.")
        } else {
            for r in flagged {
                guard let j = r.judgment else { continue }
                var line = "- **\(r.item.name)**: \(r.item.displayWithUnit(r.result.value)) → \(j.level.nameKo)"
                if j.label != j.level.nameKo { line += " · \(j.label)" }
                if !j.reference.isEmpty { line += ", 참고치 \(j.reference)" }
                if let prev = snap.previous[r.item.code], let pc = prev.checkup {
                    line += ", 직전 \(r.item.display(prev.value)) (\(day(pc.date)))"
                }
                if let from = r.carriedFrom { line += " — 이번 검진에 없어 \(day(from)) 값 사용" }
                md.append(line)
                if !r.result.note.isEmpty { md.append("  - 소견: \(oneLine(r.result.note))") }
            }
        }
        let normalCount = snap.results.count - flagged.count
        md.append("- 그 밖의 \(normalCount)개 항목은 정상 범위입니다.")
        md.append("")

        // 검진 목록
        md.append("### 검진 목록")
        md.append("")
        md.append("| 검진일 | 종류 | 기관 | 메모 |")
        md.append("|---|---|---|---|")
        for c in checkups {
            md.append("| \(day(c.date)) | \(c.type.nameKo) | \(cell(c.institution)) | \(cell(c.memo)) |")
        }
        md.append("")

        // 항목별 결과 표 (기록이 있는 항목만)
        md.append("### 항목별 결과")
        md.append("")
        md.append("값 뒤 괄호는 그 검진 당시 나이 기준 판정입니다. 괄호가 없으면 정상입니다.")
        md.append("")
        let recorded = p.recordedCodes
        let nowCtx = p.context(at: .now)
        let contexts = checkups.map { p.context(at: $0.date) }
        for cat in ItemCategory.allCases {
            let items = catalog.items(in: cat, sex: p.sex).filter { recorded.contains($0.code) }
            guard !items.isEmpty else { continue }
            md.append("#### \(cat.nameKo)")
            md.append("")
            md.append("| 항목 | 단위 | 참고치 | " + checkups.map { day($0.date) }.joined(separator: " | ") + " |")
            md.append("|---|---|---|" + String(repeating: "---|", count: checkups.count))
            for item in items {
                let ref = evaluator.referenceText(code: item.code, context: nowCtx) ?? ""
                var row = "| \(item.name) | \(item.unit ?? "") | \(cell(ref)) |"
                for (i, c) in checkups.enumerated() {
                    guard let r = c.result(item.code) else { row += " — |"; continue }
                    var v = item.display(r.value)
                    if let j = evaluator.judge(code: item.code, value: r.value, context: contexts[i]), j.level != .normal {
                        v += " (\(j.level.nameKo))"
                    }
                    row += " \(cell(v)) |"
                }
                md.append(row)
            }
            md.append("")
        }

        // 소견 메모
        var order: [String: Int] = [:]
        for (i, item) in catalog.items.enumerated() { order[item.code] = i }
        var notes: [(Checkup, TestResult)] = []
        for c in checkups {
            let withNote = c.results.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let sorted = withNote.sorted { (order[$0.code] ?? 0) < (order[$1.code] ?? 0) }
            notes += sorted.map { (c, $0) }
        }
        if !notes.isEmpty {
            md.append("### 검사 소견 (결과지 원문 메모)")
            md.append("")
            for (c, r) in notes {
                let name = catalog.item(r.code)?.name ?? r.code
                md.append("- \(day(c.date)) **\(name)**: \(oneLine(r.note))")
            }
            md.append("")
        }
        return md
    }

    // MARK: - 도움 함수

    private static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private static func oneLine(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).filter { !$0.isEmpty }.joined(separator: " / ")
    }

    /// 표 칸 안에 넣을 글: 줄바꿈·세로선 정리
    private static func cell(_ s: String) -> String {
        oneLine(s).replacingOccurrences(of: "|", with: "\\|")
    }

    // MARK: - 파일 메뉴에서 실행

    static func run() {
        let people = HealthStore.shared.people.sorted { $0.createdAt < $1.createdAt }
        guard !people.isEmpty else {
            let a = NSAlert(); a.messageText = "내보낼 기록이 없습니다."; a.runModal()
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "건강검진-기록-AI용-\(day(.now)).md"
        panel.message = "ChatGPT·Claude 같은 AI에 올리거나 붙여 넣어 물어볼 수 있는 Markdown 파일로 저장합니다."

        // 누구의 기록을 내보낼지, 이름을 숨길지 고르는 칸
        let popup = NSPopUpButton()
        popup.addItems(withTitles: people.map(\.name))
        if people.count > 1 { popup.addItem(withTitle: "모든 구성원") }
        let hide = NSButton(checkboxWithTitle: "이름·생년월일 빼고 나이만 적기", target: nil, action: nil)
        hide.state = .on
        let row = NSStackView(views: [NSTextField(labelWithString: "구성원:"), popup, hide])
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        panel.accessoryView = row

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let idx = popup.indexOfSelectedItem
        let chosen = idx < people.count ? [people[idx]] : people
        let text = make(chosen, options: .init(hideIdentity: hide.state == .on))
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            let a = NSAlert()
            a.messageText = "AI용 기록을 저장했습니다"
            a.informativeText = "\(url.lastPathComponent)\n\n파일을 AI 대화창에 올리거나 내용을 복사해 붙여 넣은 뒤 질문하면 됩니다. 건강 정보가 들어 있으니 어디에 올릴지 주의하세요."
            a.addButton(withTitle: "확인")
            a.addButton(withTitle: "Finder에서 보기")
            if a.runModal() == .alertSecondButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            let a = NSAlert(); a.messageText = "저장하지 못했습니다"; a.informativeText = error.localizedDescription; a.runModal()
        }
    }
}
