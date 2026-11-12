import AppKit

/// 입력창 바깥을 클릭하면 입력창 선택(커서)을 풀어 줌.
/// 다른 입력창이나 글 상자를 누른 경우는 그대로 둠.
enum FocusReleaser {
    private static var monitor: Any?

    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window,
                  window.firstResponder is NSText,                 // 지금 무언가 입력 중일 때만
                  let root = window.contentView?.superview else { return event }
            let hit = root.hitTest(event.locationInWindow)
            if !isTextInput(hit) {
                window.makeFirstResponder(nil)
            }
            return event
        }
    }

    private static func isTextInput(_ view: NSView?) -> Bool {
        var v = view
        while let cur = v {
            if cur is NSTextField || cur is NSText || cur is NSTextView { return true }
            if cur is NSDatePicker || cur is NSSearchField { return true }
            v = cur.superview
        }
        return false
    }
}
