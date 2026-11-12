import SwiftUI
import HealthCore

enum AppSection: String, Hashable, CaseIterable, Identifiable {
    case summary, trends, records, profile
    var id: String { rawValue }
    var title: String {
        switch self {
        case .summary: "요약"
        case .trends: "추이 그래프"
        case .records: "검진 기록"
        case .profile: "프로필"
        }
    }
    var symbol: String {
        switch self {
        case .summary: "square.grid.2x2"
        case .trends: "chart.xyaxis.line"
        case .records: "tablecells"
        case .profile: "person.text.rectangle"
        }
    }
}

struct ContentView: View {
    @ObservedObject var store = HealthStore.shared
    @ObservedObject var context = HealthStore.shared
    private var people: [Person] { context.people.sorted { $0.createdAt < $1.createdAt } }
    @AppStorage("selectedPersonID") private var selectedID = ""
    @State private var section: AppSection? = .summary
    @State private var showNewPerson = false

    private var selected: Person? {
        people.first { $0.uid.uuidString == selectedID } ?? people.first
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                Section("구성원") {
                    ForEach(people) { p in
                        Button {
                            selectedID = p.uid.uuidString
                        } label: {
                            HStack {
                                Image(systemName: p.uid == selected?.uid ? "person.fill" : "person")
                                Text(p.name.isEmpty ? "이름 없음" : p.name)
                                Spacer()
                                Text("\(p.sex == .male ? "남" : "여") · \(p.age)세")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .fontWeight(p.uid == selected?.uid ? .semibold : .regular)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showNewPerson = true
                    } label: {
                        Label("구성원 추가", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                if selected != nil {
                    Section("보기") {
                        ForEach(AppSection.allCases) { s in
                            Label(s.title, systemImage: s.symbol).tag(s)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            if let person = selected {
                switch section ?? .summary {
                case .summary: SummaryView(person: person)
                case .trends: TrendsView(person: person)
                case .records: RecordsView(person: person)
                case .profile: ProfileView(person: person, onDeleted: { selectedID = "" })
                }
            } else {
                welcome
            }
        }
        .task { applyDebugLaunchOptions() }
        .sheet(isPresented: $showNewPerson) {
            NewPersonSheet { person in
                selectedID = person.uid.uuidString
                section = .profile
            }
        }
    }

    /// 개발 확인용: HEALTHCHECKUP_SEED=1 이면 샘플 데이터, HEALTHCHECKUP_SECTION / _PERSON 으로 시작 화면 지정
    private func applyDebugLaunchOptions() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["HEALTHCHECKUP_SEED"] == "1", people.isEmpty {
            SampleData.insert(into: context)
        }
        if let s = env["HEALTHCHECKUP_SECTION"], let sec = AppSection(rawValue: s) { section = sec }
        if let i = env["HEALTHCHECKUP_PERSON"].flatMap(Int.init), people.indices.contains(i) {
            selectedID = people[i].uid.uuidString
        }
        // HEALTHCHECKUP_EXPORT_MD=/경로/out.md → 모든 구성원을 AI용 Markdown으로 저장
        if let path = env["HEALTHCHECKUP_EXPORT_MD"] {
            try? MarkdownExport.make(people).write(toFile: path, atomically: true, encoding: .utf8)
        }
        // HEALTHCHECKUP_IMPORT=/경로/file.json → 선택된 구성원에 가져오기, 결과는 같은 경로 .report.txt
        if let path = env["HEALTHCHECKUP_IMPORT"] {
            let out = URL(fileURLWithPath: path + ".report.txt")
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let summary: String
                if (try? BackupFile.decode(data)) != nil {
                    summary = try context.importBackup(data)          // 내보낸 기록 파일
                } else if let person = selected {
                    summary = try CheckupImporter.importJSON(data, into: person, context: context).summary
                } else {
                    summary = "구성원이 없습니다"
                }
                try? summary.write(to: out, atomically: true, encoding: .utf8)
            } catch {
                try? "오류: \(error)".write(to: out, atomically: true, encoding: .utf8)
            }
        }
        // HEALTHCHECKUP_WINDOW=1100x800 → 창 크기 지정
        if let w = env["HEALTHCHECKUP_WINDOW"]?.split(separator: "x").compactMap({ Double($0) }), w.count == 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NSApp.windows.first(where: { $0.isVisible && $0.frame.width > 400 })?
                    .setFrame(NSRect(x: 80, y: 80, width: w[0], height: w[1]), display: true)
            }
        }
        #endif
    }

    private var welcome: some View {
        EmptyState {
            Label("건강검진 기록을 시작하세요", systemImage: "heart.text.square")
        } description: {
            Text("구성원을 추가하고 검진 결과를 입력하면 판정과 변화를 보여드립니다.\n모든 데이터는 이 맥 안에만 저장됩니다.")
        } actions: {
            Button("구성원 추가") { showNewPerson = true }
                .buttonStyle(.borderedProminent)
            Button("다른 맥에서 내보낸 기록 가져오기…") { BackupActions.importFile() }
            Button("샘플 데이터로 둘러보기") {
                let first = SampleData.insert(into: context)
                selectedID = first.uid.uuidString
                section = .summary
            }
        }
    }
}

struct NewPersonSheet: View {
    @ObservedObject var store = HealthStore.shared
    @ObservedObject var context = HealthStore.shared
    @Environment(\.dismiss) private var dismiss
    var onCreate: (Person) -> Void

    @State private var name = ""
    @State private var sex: Sex = .male
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -40, to: .now) ?? .now

    var body: some View {
        Form {
            TextField("이름", text: $name)
            Picker("성별", selection: $sex) {
                ForEach(Sex.allCases) { Text($0.nameKo).tag($0) }
            }
            .pickerStyle(.segmented)
            DatePicker("생년월일", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("추가") {
                    let p = Person(name: name.trimmingCharacters(in: .whitespaces), sex: sex, birthDate: birthDate)
                    context.insert(p)
                    try? context.save()
                    onCreate(p)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("구성원 추가")
    }
}
