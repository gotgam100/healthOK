import AppKit
import UniformTypeIdentifiers

/// 기록 내보내기·가져오기 (다른 맥으로 옮길 때)
enum BackupActions {
    static func exportAll() {
        let store = HealthStore.shared
        guard !store.people.isEmpty else {
            alert("내보낼 기록이 없습니다.", "")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "건강하면됐지-기록-\(Date().formatted(.iso8601.year().month().day())).json"
        panel.message = "모든 구성원의 기록을 파일 하나로 저장합니다. 다른 맥의 건강하면됐지에서 [파일 › 기록 가져오기]로 열면 됩니다."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportData(store.people).write(to: url, options: .atomic)
            let n = store.people.reduce(0) { $0 + $1.checkups.count }
            alert("내보냈습니다", "구성원 \(store.people.count)명, 검진 \(n)건을 \(url.lastPathComponent)에 저장했습니다.\n건강 정보가 들어 있으니 보관에 주의하세요.")
        } catch {
            alert("내보내지 못했습니다", error.localizedDescription)
        }
    }

    static func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "건강하면됐지에서 내보낸 기록 파일을 고르세요. 기존 기록은 바꾸지 않고 빠진 것만 채웁니다."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let summary = try HealthStore.shared.importBackup(Data(contentsOf: url))
            alert("가져왔습니다", summary)
        } catch {
            alert("가져오지 못했습니다", error.localizedDescription)
        }
    }

    private static func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }
}
