import AppKit

#if DEBUG
/// 디버그용: 메뉴바 구성을 표준 출력에 찍음 (HEALTHCHECKUP_DUMP_MENU=1)
enum MenuDump {
    static func scheduleIfRequested() {
        // HEALTHCHECKUP_SHOW_ABOUT=1: 앱 정보 창 띄우기
        if ProcessInfo.processInfo.environment["HEALTHCHECKUP_SHOW_ABOUT"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { NSApp.orderFrontStandardAboutPanel(nil) }
        }
        guard ProcessInfo.processInfo.environment["HEALTHCHECKUP_DUMP_MENU"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            NSApp.mainMenu?.items.forEach { top in
                print("[\(top.title)]")
                top.submenu?.items.forEach { i in
                    print(i.isSeparatorItem ? "  ---" : "  \(i.title)\(i.isHidden ? " (hidden)" : "")\(i.isAlternate ? " (alt)" : "") \(i.action.map(NSStringFromSelector) ?? "-") \(i.identifier?.rawValue ?? "")")
                }
            }
            fflush(stdout)
        }
    }
}
#endif
