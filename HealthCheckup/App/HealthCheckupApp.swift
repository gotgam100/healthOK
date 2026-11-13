import SwiftUI

@main
struct HealthCheckupApp: App {
    init() {
        FocusReleaser.install()
        MenuCleaner.install()
        UpdateChecker.start()
        #if DEBUG
        MenuDump.scheduleIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup("건강하면됐지") {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("업데이트 확인…") { UpdateChecker.checkManually() }
            }
            // 창은 하나만 쓰므로 '새 윈도우' 대신 기록 메뉴만
            CommandGroup(replacing: .newItem) {
                Button("기록 내보내기…") { BackupActions.exportAll() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("AI용 Markdown으로 내보내기…") { MarkdownExport.run() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("기록 가져오기…") { BackupActions.importFile() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button("건강하면됐지 웹페이지 (GitHub)") { NSWorkspace.shared.open(UpdateChecker.repoPage) }
                Button("최신 버전 내려받기 페이지") { NSWorkspace.shared.open(UpdateChecker.releasesPage) }
            }
        }
    }
}
