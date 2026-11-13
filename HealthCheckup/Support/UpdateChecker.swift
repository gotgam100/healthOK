import AppKit

/// GitHub Releases에 새 버전이 올라왔는지 확인. 기록 등 개인 정보는 보내지 않고, 공개된 최신 버전 정보만 받아 옴.
enum UpdateChecker {
    static let repo = "gotgam100/healthOK"
    static let releasesPage = URL(string: "https://github.com/\(repo)/releases/latest")!
    static let repoPage = URL(string: "https://github.com/\(repo)")!

    private static let lastCheckKey = "update.lastCheck"
    private static let skippedKey = "update.skippedVersion"
    private static let autoOffKey = "update.autoOff"

    struct Release: Decodable {
        let tag_name: String
        let html_url: String
        let body: String?
        let assets: [Asset]
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
        var version: String { tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name }
        var downloadURL: URL {
            // DMG가 있으면 DMG, 없으면 zip
            let file = assets.first { $0.name.lowercased().hasSuffix(".dmg") }
                ?? assets.first { $0.name.lowercased().hasSuffix(".zip") }
            return URL(string: file?.browser_download_url ?? html_url) ?? UpdateChecker.releasesPage
        }
    }

    static var currentVersion: String {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment["HEALTHCHECKUP_FAKE_VERSION"] { return v }
        #endif
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// 앱을 켤 때: 하루에 한 번만, 조용히 확인 (새 버전이 있을 때만 알림)
    static func checkAutomatically() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: autoOffKey) else { return }
        var due = Date().timeIntervalSince(d.object(forKey: lastCheckKey) as? Date ?? .distantPast) > 24 * 3600
        #if DEBUG
        due = due || ProcessInfo.processInfo.environment["HEALTHCHECKUP_UPDATE_CHECK"] == "1"
        #endif
        guard due else { return }
        Task { await check(manual: false) }
    }

    /// 메뉴에서 직접 누를 때: 결과를 항상 알려 줌
    static func checkManually() {
        Task { await check(manual: true) }
    }

    private static func check(manual: Bool) async {
        let release: Release
        do {
            var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 15
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            release = try JSONDecoder().decode(Release.self, from: data)
        } catch {
            if manual {
                alert("업데이트를 확인하지 못했습니다",
                      "인터넷 연결을 확인한 뒤 다시 시도해 주세요.\n(\(error.localizedDescription))")
            }
            return
        }
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)

        let current = currentVersion
        guard isNewer(release.version, than: current) else {
            if manual { alert("최신 버전을 쓰고 있습니다", "지금 버전: \(current)") }
            return
        }
        if !manual, UserDefaults.standard.string(forKey: skippedKey) == release.version { return }
        offer(release, current: current, manual: manual)
    }

    private static func offer(_ r: Release, current: String, manual: Bool) {
        let a = NSAlert()
        a.messageText = "새 버전 \(r.version)이 나왔습니다"
        var info = "지금 버전: \(current)\n\n"
        let notes = (r.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { info += String(notes.prefix(600)) + "\n\n" }
        info += "[내려받기]를 누르면 새 버전 파일을 받습니다. 이 앱을 종료한 뒤, 받은 파일을 열어 앱을 '응용 프로그램' 폴더로 끌어 놓고 [대치]를 누르면 됩니다. 기록은 따로 저장되어 있어 그대로 남습니다."
        a.informativeText = info
        a.addButton(withTitle: "내려받기")
        a.addButton(withTitle: "나중에")
        a.addButton(withTitle: "이 버전 건너뛰기")
        if !manual {
            a.showsSuppressionButton = true
            a.suppressionButton?.title = "앞으로 자동으로 확인하지 않기 (메뉴에서는 확인 가능)"
        }
        let res = a.runModal()
        if a.suppressionButton?.state == .on { UserDefaults.standard.set(true, forKey: autoOffKey) }
        switch res {
        case .alertFirstButtonReturn: NSWorkspace.shared.open(r.downloadURL)
        case .alertThirdButtonReturn: UserDefaults.standard.set(r.version, forKey: skippedKey)
        default: break
        }
    }

    private static func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }

    /// "0.10.1" > "0.9.3" 처럼 숫자 단위로 비교
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
