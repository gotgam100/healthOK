import SwiftUI
import HealthCore

/// 구성원 정보 (성별·나이·가족력·기저질환·생활습관). 바꾸면 바로 저장됨.
struct ProfileView: View {
    @ObservedObject var store = HealthStore.shared
    @ObservedObject var person: Person
    var onDeleted: () -> Void

    @ObservedObject var context = HealthStore.shared
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section("기본 정보") {
                TextField("이름", text: $person.name)
                Picker("성별", selection: $person.sex) {
                    ForEach(Sex.allCases) { Text($0.nameKo).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("생년월일", selection: $person.birthDate, in: ...Date.now, displayedComponents: .date)
                LabeledContent("현재 나이", value: "만 \(person.age)세")
            }

            Section {
                Picker("흡연", selection: $person.smoking) {
                    ForEach(Smoking.allCases) { Text($0.nameKo).tag($0) }
                }
                Picker("음주", selection: $person.drinking) {
                    ForEach(Drinking.allCases) { Text($0.nameKo).tag($0) }
                }
                Picker("운동", selection: $person.exercise) {
                    ForEach(Exercise.allCases) { Text($0.nameKo).tag($0) }
                }
            } header: {
                Text("생활습관")
            } footer: {
                Text("흡연은 심혈관 위험도와 일부 종양표지자 해석에 반영됩니다.")
            }

            Section {
                ForEach(Condition.allCases) { c in
                    Toggle(c.nameKo, isOn: Binding(
                        get: { person.conditions.contains(c) },
                        set: { on in
                            var set = person.conditions
                            if on { set.insert(c) } else { set.remove(c) }
                            person.conditions = set
                        }))
                }
            } header: {
                Text("진단받은 질환")
            } footer: {
                Text("진단받은 질환이 있으면 목표 수치가 더 엄격해질 수 있습니다 (예: 당뇨병이 있으면 LDL 목표 100 미만).")
            }

            Section {
                if person.familyHistory.isEmpty {
                    Text("등록된 가족력이 없습니다.").foregroundStyle(.secondary)
                }
                ForEach(person.familyHistory) { entry in
                    FamilyHistoryRow(entry: entry) {
                        context.delete(entry)
                    }
                }
                Button {
                    let e = FamilyHistoryEntry(condition: .diabetes, relation: .father)
                    context.insert(e)
                    e.person = person
                } label: {
                    Label("가족력 추가", systemImage: "plus")
                }
            } header: {
                Text("가족력")
            } footer: {
                Text("부모·형제자매·자녀(1차 가족)의 발병 나이가 이르면 위험도 판단에 크게 반영됩니다. 예: 아버지 55세 미만·어머니 65세 미만 심근경색.")
            }

            Section("메모") {
                TextField("메모", text: $person.memo, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                Button("이 구성원 삭제", role: .destructive) { confirmDelete = true }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("\(person.name) · 프로필")
        .confirmationDialog("\(person.name)님의 모든 정보를 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) {
                context.delete(person)
                try? context.save()
                onDeleted()
            }
        } message: {
            Text("프로필과 모든 검진 기록(\(person.checkups.count)건)이 삭제되며 되돌릴 수 없습니다.")
        }
    }
}

private struct FamilyHistoryRow: View {
    @ObservedObject var store = HealthStore.shared
    @ObservedObject var entry: FamilyHistoryEntry
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Picker("관계", selection: $entry.relation) {
                ForEach(Relation.allCases) { Text($0.nameKo).tag($0) }
            }
            .labelsHidden()
            .frame(width: 120)
            Picker("질환", selection: $entry.condition) {
                ForEach(FamilyCondition.allCases) { Text($0.nameKo).tag($0) }
            }
            .labelsHidden()
            .frame(width: 160)
            TextField("발병 나이", value: $entry.onsetAge, format: .number, prompt: Text("발병 나이 (선택)"))
                .frame(width: 120)
                .textFieldStyle(.roundedBorder)
            Text("세").foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("삭제")
        }
    }
}
