import AppKit

#if DEBUG
/// 디버그용: 메뉴바 구성을 표준 출력에 찍음 (HEALTHCHECKUP_DUMP_MENU=1)
enum MenuDump {
    static func scheduleIfRequested() {
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
