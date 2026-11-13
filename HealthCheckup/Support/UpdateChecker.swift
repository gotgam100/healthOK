import AppKit
import Sparkle

/// 앱 안 자동 업데이트 (Sparkle).
/// GitHub Release의 appcast.xml을 확인하고, 업데이트 서명 열쇠로 서명된 새 버전만 받아 설치·재실행함.
/// 기록 등 개인 정보는 보내지 않음.
enum UpdateChecker {
    static let repo = "gotgam100/healthOK"
    static let releasesPage = URL(string: "https://github.com/\(repo)/releases/latest")!
    static let repoPage = URL(string: "https://github.com/\(repo)")!

    private static let delegate = FeedOverride()
    private static let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: delegate, userDriverDelegate: nil)

    /// 앱을 켤 때 한 번 부름. 이후 자동 확인은 Sparkle이 하루 한 번 함.
    static func start() {
        _ = controller
        // 시험용: 켜자마자 조용히 확인 (자동 설치 설정이면 받아 두었다가 종료할 때 설치)
        if ProcessInfo.processInfo.environment["HEALTHCHECKUP_CHECK_UPDATE_NOW"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                controller.updater.checkForUpdatesInBackground()
            }
        }
    }

    /// 메뉴 [업데이트 확인…]
    static func checkManually() {
        controller.checkForUpdates(nil)
    }
}

/// 시험용: HEALTHCHECKUP_FEED_URL로 업데이트 주소를 바꿀 수 있음 (없으면 Info.plist의 주소)
private final class FeedOverride: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        ProcessInfo.processInfo.environment["HEALTHCHECKUP_FEED_URL"]
    }
}
