import AppKit
import WebKit

struct MainActorWebNavigationEvent: @unchecked Sendable {
    let webView: WKWebView
    let navigation: WKNavigation?
}

final class MainActorWebNavigationDelegate: NSObject, WKNavigationDelegate {
    private let didFinish: @MainActor @Sendable (MainActorWebNavigationEvent) -> Void

    init(didFinish: @escaping @MainActor @Sendable (MainActorWebNavigationEvent) -> Void) {
        self.didFinish = didFinish
        super.init()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let event = MainActorWebNavigationEvent(webView: webView, navigation: navigation)
        Task { @MainActor in
            didFinish(event)
        }
    }
}

struct MainActorMenuEvent: @unchecked Sendable {
    let menu: NSMenu
}

final class MainActorMenuDelegate: NSObject, NSMenuDelegate {
    private let willOpen: @MainActor @Sendable (MainActorMenuEvent) -> Void
    private let didClose: @MainActor @Sendable (MainActorMenuEvent) -> Void

    init(
        willOpen: @escaping @MainActor @Sendable (MainActorMenuEvent) -> Void,
        didClose: @escaping @MainActor @Sendable (MainActorMenuEvent) -> Void
    ) {
        self.willOpen = willOpen
        self.didClose = didClose
        super.init()
    }

    func menuWillOpen(_ menu: NSMenu) {
        let event = MainActorMenuEvent(menu: menu)
        Task { @MainActor in
            willOpen(event)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        let event = MainActorMenuEvent(menu: menu)
        Task { @MainActor in
            didClose(event)
        }
    }
}

struct MainActorWindowEvent: @unchecked Sendable {
    let notification: Notification
}

final class MainActorWindowDelegate: NSObject, NSWindowDelegate {
    private let willClose: @MainActor @Sendable (MainActorWindowEvent) -> Void

    init(willClose: @escaping @MainActor @Sendable (MainActorWindowEvent) -> Void) {
        self.willClose = willClose
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        let event = MainActorWindowEvent(notification: notification)
        Task { @MainActor in
            willClose(event)
        }
    }
}

struct MainActorTextFieldEvent: @unchecked Sendable {
    let notification: Notification
}

struct MainActorTextCommandEvent: @unchecked Sendable {
    let control: NSControl
    let textView: NSTextView
    let commandSelector: Selector
}

final class MainActorTextFieldDelegate: NSObject, NSTextFieldDelegate {
    private let didEndEditing: (@MainActor @Sendable (MainActorTextFieldEvent) -> Void)?
    private let handlesCommand: @Sendable (Selector) -> Bool
    private let doCommand: (@MainActor @Sendable (MainActorTextCommandEvent) -> Void)?

    init(
        didEndEditing: (@MainActor @Sendable (MainActorTextFieldEvent) -> Void)? = nil,
        handlesCommand: @escaping @Sendable (Selector) -> Bool = { _ in false },
        doCommand: (@MainActor @Sendable (MainActorTextCommandEvent) -> Void)? = nil
    ) {
        self.didEndEditing = didEndEditing
        self.handlesCommand = handlesCommand
        self.doCommand = doCommand
        super.init()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let didEndEditing else {
            return
        }
        let event = MainActorTextFieldEvent(notification: notification)
        Task { @MainActor in
            didEndEditing(event)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard handlesCommand(commandSelector), let doCommand else {
            return false
        }
        let event = MainActorTextCommandEvent(
            control: control,
            textView: textView,
            commandSelector: commandSelector
        )
        Task { @MainActor in
            doCommand(event)
        }
        return true
    }
}
