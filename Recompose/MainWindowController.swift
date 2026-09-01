import AppKit

final class MainWindowController: NSWindowController, NSToolbarDelegate {
    private static let titleItemIdentifier = NSToolbarItem.Identifier("RecomposeTitle")

    convenience init() {
        let contentViewController = MainViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 308),
            styleMask: [.titled, .closable, .miniaturizable],
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
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .line
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior.insert(.fullScreenNone)
        let toolbar = NSToolbar(identifier: "RecomposeToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifiers = [Self.titleItemIdentifier]
        window.toolbar = toolbar

        window.standardWindowButton(.zoomButton)?.isEnabled = false
        var frame = window.frame
        frame.size = NSSize(width: 420, height: 360)
        window.setFrame(frame, display: false)
        window.center()
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.titleItemIdentifier]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.titleItemIdentifier]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == Self.titleItemIdentifier else { return nil }

        let title = NSTextField(labelWithString: "Recompose")
        title.font = .systemFont(ofSize: 13, weight: .bold)
        title.textColor = .labelColor
        title.alignment = .center
        title.setContentHuggingPriority(.required, for: .horizontal)

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Recompose"
        item.paletteLabel = "Recompose"
        item.view = title
        item.isNavigational = false
        return item
    }
}
