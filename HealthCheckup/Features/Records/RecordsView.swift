import SwiftUI
import HealthCore

/// 연도(검진)를 열로, 항목을 행으로 보여주는 표
struct RecordsView: View {
    @ObservedObject var store = HealthStore.shared
    let person: Person
    @ObservedObject var context = HealthStore.shared
    @State private var editing: EditorTarget?
    @State private var showVisibility = false
    @State private var deleting: Checkup?
    @State private var importing = false
    @State private var importMessage: String?

    private let evaluator = Evaluator()
    private let catalog = Catalog.shared

    private let nameWidth: CGFloat = 220
    private let cellWidth: CGFloat = 118

    var body: some View {
        let checkups = person.sortedCheckups
        Group {
            if checkups.isEmpty {
                EmptyState {
                    Label("검진 기록이 없습니다", systemImage: "tablecells")
                } actions: {
                    Button("검진 추가") { editing = .new }.buttonStyle(.borderedProminent)
                }
            } else {
                table(checkups)
            }
        }
        .navigationTitle("\(person.name) · 검진 기록")
        .toolbar {
            ToolbarItem {
                Button { showVisibility = true } label: { Label("항목 표시", systemImage: "checklist") }
                    .help("표에 보일 항목 켜기/끄기")
            }
            ToolbarItem {
                Button { importing = true } label: { Label("가져오기", systemImage: "square.and.arrow.down") }
                    .help("기록 파일(JSON) 가져오기 — 기존 값은 바꾸지 않고 빈 항목만 채웁니다")
            }
            ToolbarItem {
                Button { editing = .new } label: { Label("검진 추가", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showVisibility) { ItemVisibilitySheet(person: person) }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["HEALTHCHECKUP_OPEN_VISIBILITY"] == "1" { showVisibility = true }
            #endif
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                if (try? BackupFile.decode(data)) != nil {
                    importMessage = try context.importBackup(data)   // 다른 맥에서 내보낸 기록
                } else {
                    importMessage = try CheckupImporter.importJSON(data, into: person, context: context).summary
                }
            } catch {
                importMessage = "가져오지 못했습니다: \(error.localizedDescription)"
            }
        }
        .alert("가져오기 결과", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("확인") { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
        .sheet(item: $editing) { target in
            CheckupEditorView(person: person, checkup: target.checkup, focusCode: target.focusCode)
        }
        .confirmationDialog("이 검진 기록을 삭제할까요?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            presenting: deleting
        ) { c in
            Button("\(c.date.ymd) 검진 삭제", role: .destructive) {
                context.delete(c)
                try? context.save()
            }
        } message: { _ in
            Text("입력한 모든 결과가 함께 삭제되며 되돌릴 수 없습니다.")
        }
    }

    private func table(_ checkups: [Checkup]) -> some View {
        let recorded = Set(checkups.flatMap { $0.results.map(\.code) })
        let latestCtx = person.context(at: .now)
        let contexts = checkups.map { person.context(at: $0.date) }

        return ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // 머리글
                GridRow {
                    Text("항목").font(.headline)
                        .frame(width: nameWidth, alignment: .leading)
                        .padding(.horizontal, 10)
                    ForEach(checkups) { c in
                        VStack(spacing: 4) {
                            Text(c.date.ymd).font(.subheadline.weight(.semibold))
                            Text([c.type.nameKo, c.institution].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            Button { editing = .existing(c) } label: {
                                Label("편집", systemImage: "pencil").font(.caption)
                            }
                            .controlSize(.small)
                            .help("이 검진 편집")
                        }
                        .frame(width: cellWidth)
                        .contextMenu {
                            Button("이 검진 편집") { editing = .existing(c) }
                            Button("삭제", role: .destructive) { deleting = c }
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(.bar)

                ForEach(ItemCategory.allCases) { cat in
                    let items = catalog.items(in: cat, sex: person.sex)
                        .filter { person.isVisible($0, recorded: recorded) }
                    if !items.isEmpty {
                        GridRow {
                            Text(cat.nameKo)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10).padding(.top, 14).padding(.bottom, 4)
                                .gridCellColumns(checkups.count + 1)
                        }
                        ForEach(items) { item in
                            GridRow {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name).lineLimit(1)
                                    if let ref = evaluator.referenceText(code: item.code, context: latestCtx),
                                       !ref.isEmpty, ref != "정상" {
                                        Text("정상 \(ref)\(item.unit.map { " \($0)" } ?? "")")
                                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                .frame(width: nameWidth, alignment: .leading)
                                .padding(.horizontal, 10)

                                ForEach(Array(checkups.enumerated()), id: \.element.id) { idx, c in
                                    cell(item: item, checkup: c, context: contexts[idx])
                                }
                            }
                            .padding(.vertical, 4)
                            Divider().gridCellUnsizedAxes(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 12)

            // 숨긴 항목 안내 (아예 사라지지 않도록 항상 되돌릴 길을 보여줌)
            let hidden = catalog.items(for: person.sex).filter { !person.isVisible($0, recorded: recorded) }
            HStack(spacing: 8) {
                Image(systemName: "eye.slash").foregroundStyle(.secondary)
                Text(hidden.isEmpty ? "모든 항목을 표시하고 있습니다."
                     : "숨긴 항목 \(hidden.count)개" + (hidden.contains { recorded.contains($0.code) } ? " (기록 있는 항목 포함)" : ""))
                    .foregroundStyle(.secondary)
                Button("항목 표시…") { showVisibility = true }
                    .buttonStyle(.link)
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func cell(item: TestItem, checkup: Checkup, context ctx: PersonContext) -> some View {
        if let r = checkup.result(item.code) {
            let j = evaluator.judge(code: item.code, value: r.value, context: ctx)
            ResultCell(item: item, result: r, judgment: j, width: cellWidth,
                       help: helpText(item: item, result: r, judgment: j),
                       openEditor: { editing = .item(checkup, item.code) })
        } else {
            EmptyCell(item: item, checkup: checkup, width: cellWidth,
                      openEditor: { editing = .item(checkup, item.code) })
        }
    }

    private func helpText(item: TestItem, result: TestResult, judgment: Judgment?) -> String {
        var lines = ["\(item.name): \(item.displayWithUnit(result.value))"]
        if let judgment {
            lines.append("판정: \(judgment.label)")
            if !judgment.reference.isEmpty { lines.append("정상: \(judgment.reference)") }
            lines += judgment.notes
            if let s = judgment.source { lines.append("기준: \(s)") }
        }
        if !result.note.isEmpty { lines.append("메모: \(result.note)") }
        return lines.joined(separator: "\n")
    }
}

/// 표의 값 칸. 누르면 소견 메모창이 열림.
private struct ResultCell: View {
    @ObservedObject var store = HealthStore.shared
    let item: TestItem
    @ObservedObject var result: TestResult
    let judgment: Judgment?
    let width: CGFloat
    let help: String
    /// 이 검진의 입력창을 열고 이 항목으로 이동
    let openEditor: () -> Void

    @ObservedObject var context = HealthStore.shared
    @State private var showNote = false
    @State private var draft = ""

    var body: some View {
        let j = judgment
        let hasNote = !result.note.isEmpty
        Button {
            draft = result.note
            showNote = true
        } label: {
            HStack(spacing: 4) {
                if let j, j.level != .normal {
                    Image(systemName: j.level.symbol).font(.caption2)
                }
                Text(item.display(result.value))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .foregroundStyle(j == nil ? Color.primary : (j?.level.color ?? .secondary))
            .font(.callout.weight(j?.level == .normal || j == nil ? .regular : .semibold))
            .frame(width: width - 10, height: 26)
            .background((j?.level.color ?? .clear).opacity(j?.level == .normal ? 0.06 : 0.14),
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .topTrailing) {
                if hasNote {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentColor)
                        .padding(3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: width)
        .help(help + (hasNote ? "" : "\n(눌러서 소견 메모 쓰기)"))
        .contextMenu {
            Button("값 복사") { Clipboard.copy(item.display(result.value)) }
            if item.kind == .numeric, let unit = item.unit, !unit.isEmpty {
                Button("단위 포함 복사") { Clipboard.copy(item.displayWithUnit(result.value)) }
            }
            Button("붙여넣기") {
                guard let v = Clipboard.read().flatMap(item.parse) else { NSSound.beep(); return }
                result.value = v
                try? context.save()
            }
            Divider()
            Button("입력창 이동") { openEditor() }
            Button("소견 메모…") { draft = result.note; showNote = true }
            Button("값 지우기", role: .destructive) {
                context.delete(result)
                try? context.save()
            }
        }
        .popover(isPresented: $showNote, arrowEdge: .bottom) {
            NoteEditor(title: "\(item.name) 소견", text: $draft) {
                result.note = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                try? context.save()
                showNote = false
            }
        }
    }
}

/// 값이 없는 칸. 우클릭으로 붙여넣으면 새 값이 생김.
private struct EmptyCell: View {
    @ObservedObject var store = HealthStore.shared
    let item: TestItem
    let checkup: Checkup
    let width: CGFloat
    let openEditor: () -> Void
    @ObservedObject var context = HealthStore.shared

    var body: some View {
        Text("—")
            .foregroundStyle(.quaternary)
            .frame(width: width - 10, height: 26)
            .contentShape(Rectangle())
            .frame(width: width)
            .contextMenu {
                Button("붙여넣기") {
                    guard let v = Clipboard.read().flatMap(item.parse) else { NSSound.beep(); return }
                    let r = TestResult(code: item.code, value: v)
                    checkup.results.append(r)
                    try? context.save()
                }
                Button("입력창 이동") { openEditor() }
            }
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    static func read() -> String? { NSPasteboard.general.string(forType: .string) }
}
