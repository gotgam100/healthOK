import AppKit

/// macOS가 자동으로 붙이는, 이 앱에서 쓰지 않는 메뉴 항목을 치움
/// (편집: 글쓰기 도구·자동 완성·받아쓰기·이모지, 비어 있는 보기 메뉴)
enum MenuCleaner {
    private static let unusedIDs: Set<String> = [
        "__NSTextViewContextSubmenuIdentifierWritingTools",
        "_NSMenuItemAutoFillIdentifier",
    ]
    private static let unusedActions: Set<String> = [
        "startDictation:", "orderFrontCharacterPalette:", "showWritingTools:",
    ]

    static func install() {
        // 받아쓰기·이모지는 이 설정으로 아예 안 붙게 함
        UserDefaults.standard.register(defaults: [
            "NSDisabledDictationMenuItem": true,
            "NSDisabledCharacterPaletteMenuItem": true,
        ])
        NSWindow.allowsAutomaticWindowTabbing = false   // 보기 메뉴의 탭 항목 없애기

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { cleanSoon() }
        }
        // 시스템이 나중에 다시 붙이는 경우가 있어 항목이 추가될 때마다 정리
        nc.addObserver(forName: NSMenu.didAddItemNotification, object: nil, queue: .main) { n in
            guard let obj = n.object as AnyObject? else { return }
            let changed = ObjectIdentifier(obj)
            MainActor.assumeIsolated {
                guard let main = NSApp.mainMenu else { return }
                let watched = [main] + main.items.compactMap(\.submenu)
                guard watched.contains(where: { ObjectIdentifier($0) == changed }) else { return }
                cleanSoon()
            }
        }
    }

    private static var pending = false
    private static func cleanSoon() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.async {
            pending = false
            clean()
        }
    }

    static func clean() {
        guard let main = NSApp.mainMenu else { return }
        for top in main.items {
            guard let menu = top.submenu else { continue }
            for item in menu.items.reversed() where isUnused(item) {
                menu.removeItem(item)
            }
            tidySeparators(menu)
        }
        // 항목이 하나도 안 보이는 메뉴(보기)는 메뉴바에서 뺌
        for top in main.items.reversed() {
            guard let menu = top.submenu, top !== main.items.first else { continue }
            if !menu.items.contains(where: { !$0.isHidden && !$0.isSeparatorItem }) {
                main.removeItem(top)
            }
        }
    }

    private static func isUnused(_ item: NSMenuItem) -> Bool {
        if let id = item.identifier?.rawValue, unusedIDs.contains(id) { return true }
        if let a = item.action, unusedActions.contains(NSStringFromSelector(a)) { return true }
        return false
    }

    /// 맨 끝·연달아 있는 구분선 정리
    private static func tidySeparators(_ menu: NSMenu) {
        var prevSep = true
        for item in menu.items {
            if item.isSeparatorItem {
                if prevSep { menu.removeItem(item) } else { prevSep = true }
            } else if !item.isHidden {
                prevSep = false
            }
        }
        while let last = menu.items.last(where: { !$0.isHidden }), last.isSeparatorItem {
            menu.removeItem(last)
        }
    }
}
