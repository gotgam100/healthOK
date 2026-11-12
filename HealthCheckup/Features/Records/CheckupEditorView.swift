import SwiftUI
import HealthCore

/// 검진 한 건 입력·편집
struct CheckupEditorView: View {
    @ObservedObject var store = HealthStore.shared
    let person: Person
    let checkup: Checkup?
    /// 열자마자 이동할 항목 (표에서 '입력창 이동'으로 연 경우)
    var focusCode: String? = nil

    @ObservedObject var context = HealthStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var institution = ""
    @State private var type: CheckupType = .national
    @State private var memo = ""
    /// 숫자 항목 입력 문자열
    @State private var texts: [String: String] = [:]
    /// 선택형 항목 선택값
    @State private var choices: [String: Int] = [:]
    @State private var notes: [String: String] = [:]
    @State private var search = ""
    /// 표시 설정에서 끈 항목도 잠깐 보기
    @State private var showHidden = false
    @State private var showVisibility = false
    /// 메모창을 연 항목 코드
    @State private var noteEditing: String?
    @State private var loaded = false
    @State private var confirmDelete = false
    /// 잠깐 강조 표시 중인 항목
    @State private var highlighted: String?
    @FocusState private var focusedField: String?

    private let evaluator = Evaluator()
    private let catalog = Catalog.shared

    private var ctx: PersonContext { person.context(at: date) }

    /// 값 입력 열: 숫자칸+단위, 선택 상자 모두 같은 폭이라 판정·메모 버튼이 한 줄로 맞음
    private static let valueWidth: CGFloat = 200
    private static let fieldWidth: CGFloat = 110

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
            Form {
                Section("기본 정보") {
                    DatePicker("검진일", selection: $date, in: ...Date.now, displayedComponents: .date)
                    TextField("검진 기관", text: $institution, prompt: Text("예: ○○병원 건강증진센터"))
                    Picker("종류", selection: $type) {
                        ForEach(CheckupType.allCases) { Text($0.nameKo).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("메모", text: $memo, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    HStack {
                        TextField("항목 검색", text: $search, prompt: Text("항목 이름으로 찾기 (예: 혈당, LDL)"))
                            .textFieldStyle(.roundedBorder)
                        Toggle("숨긴 항목도 보기", isOn: $showHidden)
                            .help("항목 표시에서 끈 항목까지 모두 보기")
                        Button { showVisibility = true } label: { Label("항목 표시…", systemImage: "checklist") }
                            .help("보일 항목을 켜고 끄기")
                    }
                    Text("검진 당시 \(person.sex.nameKo) \(ctx.age)세 기준으로 판정합니다. 값이 있는 항목은 항상 보이고, 비워 둔 항목은 저장되지 않습니다. \(hiddenCount > 0 && !showHidden ? "숨긴 항목 \(hiddenCount)개." : "")")
                        .font(.caption).foregroundStyle(.secondary)
                }

                ForEach(ItemCategory.allCases) { cat in
                    let items = visibleItems(in: cat)
                    if !items.isEmpty {
                        Section(cat.nameKo) {
                            ForEach(items) { item in
                                row(item)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .onAppear { jump(proxy) }
            }

            Divider()
            HStack {
                if checkup != nil {
                    Button("삭제", role: .destructive) { confirmDelete = true }
                }
                Spacer()
                Text("\(filledCount)개 항목 입력됨").foregroundStyle(.secondary).font(.callout)
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("저장") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(minWidth: 680, idealWidth: 720, minHeight: 600, idealHeight: 760)
        .onAppear {
            load()
            #if DEBUG
            if let q = ProcessInfo.processInfo.environment["HEALTHCHECKUP_EDITOR_SEARCH"] { search = q }
            if let c = ProcessInfo.processInfo.environment["HEALTHCHECKUP_OPEN_NOTE"] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { noteEditing = c }
            }
            #endif
        }
        .onChange(of: type) { new in
            if new == .comprehensive, checkup == nil { showHidden = true }
        }
        .sheet(isPresented: $showVisibility) { ItemVisibilitySheet(person: person) }
        .confirmationDialog("이 검진 기록을 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) {
                if let checkup { context.delete(checkup); try? context.save() }
                dismiss()
            }
        } message: {
            Text("입력한 모든 결과가 함께 삭제되며 되돌릴 수 없습니다.")
        }
    }

    // MARK: - 항목 행

    @ViewBuilder
    private func row(_ item: TestItem) -> some View {
        switch item.kind {
        case .numeric:
            let binding = Binding(get: { texts[item.code] ?? "" }, set: { texts[item.code] = $0 })
            HStack {
                nameLabel(item)
                if item.code == "BMI" && (texts["BMI"] ?? "").isEmpty, autoBMI != nil {
                    Text("자동 계산: \(Formatting.number(autoBMI!, digits: 1))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    // 참고치는 이름 아래에 보이므로 칸 안에는 넣지 않음 (긴 글이 칸을 밀어냄)
                    TextField("", text: binding)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: item.code)
                        .frame(width: Self.fieldWidth)
                    Text(item.unit ?? "").font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: Self.valueWidth, alignment: .leading)
                badge(for: item)
                noteButton(item)
            }
            .modifier(RowHighlight(on: highlighted == item.code))
            .id(item.code)
            notePreview(item)
        case .ordinal:
            let binding = Binding(get: { choices[item.code] ?? -1 }, set: { choices[item.code] = $0 })
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    nameLabel(item)
                    Spacer()
                    HStack(spacing: 0) {
                        Picker("", selection: binding) {
                            Text("—").tag(-1)
                            ForEach(item.resolvedOptions) { Text($0.label).tag($0.value) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Spacer(minLength: 0)
                    }
                    .frame(width: Self.valueWidth, alignment: .leading)
                    badge(for: item)
                    noteButton(item)
                }
                notePreview(item)
            }
            .modifier(RowHighlight(on: highlighted == item.code))
            .id(item.code)
        }
    }

    /// 항목 이름 + 그 아래 작은 참고치 (검진 당시 나이·성별 기준)
    private func nameLabel(_ item: TestItem) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.name)
            if let ref = referenceLine(item) {
                Text(ref)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(ref)
            }
        }
    }

    private func referenceLine(_ item: TestItem) -> String? {
        guard let ref = evaluator.referenceText(code: item.code, context: ctx), !ref.isEmpty else { return nil }
        if item.kind == .numeric, let unit = item.unit, !unit.isEmpty, ref != "정상" {
            return "참고치 \(ref) \(unit)"
        }
        return "참고치 \(ref)"
    }

    /// 소견 메모창 열기 버튼 (메모가 있으면 채워진 아이콘)
    private func noteButton(_ item: TestItem) -> some View {
        let has = !(notes[item.code] ?? "").isEmpty
        return Button { noteEditing = item.code } label: {
            Image(systemName: has ? "note.text" : "square.and.pencil")
                .foregroundStyle(has ? Color.accentColor : .secondary)
        }
        .buttonStyle(.borderless)
        .frame(width: 22)
        .help(has ? "소견 보기·고치기" : "소견 메모 쓰기")
        .popover(isPresented: Binding(get: { noteEditing == item.code },
                                      set: { if !$0 { noteEditing = nil } }), arrowEdge: .trailing) {
            NoteEditor(title: "\(item.name) 소견",
                       hint: value(for: item) == nil ? "결과값을 입력(선택)해야 소견이 함께 저장됩니다." : nil,
                       text: Binding(get: { notes[item.code] ?? "" }, set: { notes[item.code] = $0 }),
                       onDone: { noteEditing = nil })
        }
    }

    @ViewBuilder
    private func notePreview(_ item: TestItem) -> some View {
        if let n = notes[item.code], !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button { noteEditing = item.code } label: {
                Label(n, systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func badge(for item: TestItem) -> some View {
        let judgment = value(for: item).flatMap {
            evaluator.judge(code: item.code, value: $0, context: ctx)
        }
        return LevelBadge(judgment: judgment, compact: true)
            .opacity(judgment == nil ? 0 : 1)
            .help(judgment.map { "\($0.label) · 정상 \($0.reference)" } ?? "")
            .frame(width: 64, alignment: .leading)
    }


    /// 지정된 항목으로 스크롤하고 잠깐 강조, 숫자 칸이면 커서도 넣음
    private func jump(_ proxy: ScrollViewProxy) {
        var code = focusCode
        #if DEBUG
        if code == nil { code = ProcessInfo.processInfo.environment["HEALTHCHECKUP_EDITOR_FOCUS"] }
        #endif
        guard let code, let item = catalog.item(code) else { return }
        // 표시 설정에서 꺼 둔 항목이면 숨긴 항목도 보이게
        if value(for: item) == nil && !person.isVisible(item, recorded: recorded) { showHidden = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(code, anchor: .center) }
            highlighted = code
            if item.kind == .numeric { focusedField = code }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.6)) { if highlighted == code { highlighted = nil } }
            }
        }
    }

    // MARK: - 값 처리

    private func visibleItems(in cat: ItemCategory) -> [TestItem] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return catalog.items(in: cat, sex: person.sex).filter { item in
            let hasValue = value(for: item) != nil
            if !q.isEmpty {
                let names = [item.name, item.code] + (item.aliases ?? [])
                return names.contains { $0.lowercased().contains(q) }
            }
            return hasValue || showHidden || person.isVisible(item, recorded: recorded)
        }
    }

    private var recorded: Set<String> { person.recordedCodes }

    private var hiddenCount: Int {
        catalog.items(for: person.sex).filter { !person.isVisible($0, recorded: recorded) && value(for: $0) == nil }.count
    }

    private static func parse(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return t.isEmpty ? nil : Double(t)
    }

    private func value(for item: TestItem) -> Double? {
        switch item.kind {
        case .numeric:
            if item.code == "BMI", (texts["BMI"] ?? "").isEmpty { return autoBMI }
            return Self.parse(texts[item.code] ?? "")
        case .ordinal:
            let v = choices[item.code] ?? -1
            return v >= 0 ? Double(v) : nil
        }
    }

    private var autoBMI: Double? {
        guard let h = Self.parse(texts["HEIGHT"] ?? ""), let w = Self.parse(texts["WEIGHT"] ?? ""), h > 50 else { return nil }
        let m = h / 100
        return (w / (m * m) * 10).rounded() / 10
    }

    private var filledCount: Int {
        catalog.items(for: person.sex).filter { value(for: $0) != nil }.count
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let c = checkup {
            date = c.date
            institution = c.institution
            type = c.type
            memo = c.memo
            for r in c.results {
                guard let item = catalog.item(r.code) else { continue }
                switch item.kind {
                case .numeric: texts[r.code] = item.display(r.value)
                case .ordinal: choices[r.code] = Int(r.value.rounded())
                }
                if !r.note.isEmpty { notes[r.code] = r.note }
            }
        } else {
            // 새 검진: 지난번 검진 기관·종류를 기본값으로
            if let last = person.sortedCheckups.last {
                institution = last.institution
                type = last.type
            }
            showHidden = type == .comprehensive
        }
    }

    private func save() {
        let target: Checkup
        if let checkup {
            target = checkup
        } else {
            target = Checkup(date: date)
            context.insert(target)
            target.person = person
        }
        target.date = date
        target.institution = institution.trimmingCharacters(in: .whitespaces)
        target.type = type
        target.memo = memo

        for item in catalog.items(for: person.sex) {
            let existing = target.result(item.code)
            let note = (notes[item.code] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let v = value(for: item) {
                if let existing {
                    existing.value = v
                    existing.note = note
                } else {
                    let r = TestResult(code: item.code, value: v, note: note)
                    context.insert(r)
                    r.checkup = target
                }
            } else if let existing {
                context.delete(existing)
            }
        }
        try? context.save()
        dismiss()
    }
}

/// '입력창 이동'으로 찾아온 행을 잠깐 강조
private struct RowHighlight: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(on ? 0.18 : 0))
                    .padding(.horizontal, -6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor.opacity(on ? 0.8 : 0), lineWidth: 1.5)
                    .padding(.horizontal, -6)
            )
    }
}
