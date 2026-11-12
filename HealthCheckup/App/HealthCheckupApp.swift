import SwiftUI

@main
struct HealthCheckupApp: App {
    init() { FocusReleaser.install() }

    var body: some Scene {
        WindowGroup("건강하면됐지") {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Divider()
                Button("기록 내보내기…") { BackupActions.exportAll() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("AI용 Markdown으로 내보내기…") { MarkdownExport.run() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("기록 가져오기…") { BackupActions.importFile() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
    }
}
