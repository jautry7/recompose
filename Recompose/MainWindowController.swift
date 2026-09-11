import AppKit

final class MainWindowController: NSWindowController {
    convenience init() {
        let contentViewController = MainViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.init(window: window)
        window.contentViewController = contentViewController
        configure(window)
    }

    private func configure(_ window: NSWindow) {
        window.title = "Recompose"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior.insert(.fullScreenNone)

        let toolbar = NSToolbar(identifier: "RecomposeToolbar")
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar

        window.standardWindowButton(.zoomButton)?.isEnabled = false
        var frame = window.frame
        frame.size = NSSize(width: 700, height: 400)
        window.setFrame(frame, display: false)
        window.center()
    }
}
