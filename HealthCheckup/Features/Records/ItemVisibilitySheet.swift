import SwiftUI
import HealthCore

/// 구성원별 항목 표시 켜기/끄기. 끈 항목도 데이터는 그대로이며 언제든 다시 켤 수 있음.
struct ItemVisibilitySheet: View {
    @ObservedObject var store = HealthStore.shared
    @ObservedObject var person: Person
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private let catalog = Catalog.shared

    var body: some View {
        let recorded = person.recordedCodes
        let all = catalog.items(for: person.sex)
        let visibleCount = all.filter { person.isVisible($0, recorded: recorded) }.count

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("항목 표시").font(.title2.bold())
                Text("검진 기록 표·입력 화면·추이 그래프에 보일 항목을 고릅니다. 꺼도 기록은 지워지지 않습니다.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    TextField("항목 찾기", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                    Spacer()
                    Text("\(all.count)개 중 \(visibleCount)개 표시").font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(16)

            Divider()

            List {
                ForEach(ItemCategory.allCases) { cat in
                    let items = catalog.items(in: cat, sex: person.sex).filter(matches)
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { item in
                                Toggle(isOn: Binding(
                                    get: { person.isVisible(item, recorded: recorded) },
                                    set: { person.setVisible(item.code, $0) })) {
                                    HStack(spacing: 6) {
                                        Text(item.name)
                                        if item.isBasic { Tag(text: "기본") }
                                        if recorded.contains(item.code) { Tag(text: "기록 있음") }
                                        if item.isComprehensive { Tag(text: "종합검진") }
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        } header: {
                            HStack {
                                Text(cat.nameKo)
                                Spacer()
                                Button("모두 켜기") { items.forEach { person.setVisible($0.code, true) } }
                                Button("모두 끄기") { items.forEach { person.setVisible($0.code, false) } }
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.inset)

            Divider()
            HStack {
                Button("기본값으로 되돌리기") {
                    person.shownCodes = []
                    person.hiddenCodes = []
                }
                .help("기본 항목과 기록이 있는 항목만 표시")
                Button("모두 켜기") { all.forEach { person.setVisible($0.code, true) } }
                Spacer()
                Button("완료") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 520, height: 640)
    }

    private func matches(_ item: TestItem) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return ([item.name, item.code] + (item.aliases ?? [])).contains { $0.lowercased().contains(q) }
    }
}

private struct Tag: View {
    @ObservedObject var store = HealthStore.shared
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
    }
}

/// 소견·메모를 여러 줄로 적는 메모창 (팝오버 안에 띄움)
struct NoteEditor: View {
    @ObservedObject var store = HealthStore.shared
    let title: String
    var hint: String? = nil
    @Binding var text: String
    var onDone: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: "note.text").font(.headline)
                Spacer()
            }
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                .frame(minHeight: 160)
                .focused($focused)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("결과지 소견을 적어 주세요 (예: 경도 지방간, 용종 1개 제거 후 조직검사 선종)")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .allowsHitTesting(false)
                    }
                }
            if let hint {
                Text(hint).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("지우기", role: .destructive) { text = "" }
                    .disabled(text.isEmpty)
                Spacer()
                Button("완료") { onDone() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(width: 420)
        .onAppear { focused = true }
    }
}
