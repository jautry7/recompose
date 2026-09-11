import AppKit
import Symbols

protocol DropZoneViewDelegate: AnyObject {
    func dropZone(_ dropZone: DropZoneView, hoveringOverValidFile isHovering: Bool)
    func dropZone(
        _ dropZone: DropZoneView,
        didReceiveCatalogAt catalogURL: URL,
        securityScopeURL: URL,
        displayName: String
    )
    func dropZoneDidRejectFile(_ dropZone: DropZoneView)
}

private final class DragCaptureView: NSView {
    weak var dropZone: DropZoneView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        dropZone?.draggingEntered(sender) ?? []
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        dropZone?.draggingUpdated(sender) ?? []
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        dropZone?.draggingExited(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        dropZone?.performDragOperation(sender) ?? false
    }
}

final class DropZoneView: NSView {
    weak var delegate: DropZoneViewDelegate?
    var acceptsDrops = true {
        didSet { dragCaptureView.isHidden = !acceptsDrops }
    }
    var isHighlighted = false {
        didSet { needsDisplay = true }
    }

    private let dragCaptureView = DragCaptureView()
    private let leadingSeparatorLayer = CALayer()
    private var hasSignaledInvalidDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        leadingSeparatorLayer.zPosition = 1
        layer?.addSublayer(leadingSeparatorLayer)
        registerForDraggedTypes([.fileURL])

        dragCaptureView.dropZone = self
        dragCaptureView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dragCaptureView)
        NSLayoutConstraint.activate([
            dragCaptureView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dragCaptureView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dragCaptureView.topAnchor.constraint(equalTo: topAnchor),
            dragCaptureView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override func updateLayer() {
        let backgroundColor = isHighlighted
            ? NSColor.controlAccentColor.withAlphaComponent(0.08)
            : NSColor.quaternarySystemFill
        let separatorColor = isHighlighted
            ? NSColor.controlAccentColor.withAlphaComponent(0.25)
            : NSColor.separatorColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = backgroundColor.cgColor
            self.leadingSeparatorLayer.backgroundColor = separatorColor.cgColor
        }
    }

    override func layout() {
        super.layout()
        leadingSeparatorLayer.frame = NSRect(x: -1, y: 0, width: 1, height: bounds.height)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    func installContentView(_ contentView: NSView) {
        addSubview(contentView, positioned: .below, relativeTo: dragCaptureView)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        updateDragState(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        updateDragState(sender)
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        hasSignaledInvalidDrag = false
        delegate?.dropZone(self, hoveringOverValidFile: false)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        defer {
            hasSignaledInvalidDrag = false
            delegate?.dropZone(self, hoveringOverValidFile: false)
        }

        guard acceptsDrops, let input = validCatalogInput(from: sender.draggingPasteboard) else {
            delegate?.dropZoneDidRejectFile(self)
            return false
        }

        delegate?.dropZone(
            self,
            didReceiveCatalogAt: input.catalogURL,
            securityScopeURL: input.securityScopeURL,
            displayName: input.displayName
        )
        return true
    }

    private func updateDragState(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard acceptsDrops else { return [] }

        if validCatalogInput(from: sender.draggingPasteboard) != nil {
            hasSignaledInvalidDrag = false
            delegate?.dropZone(self, hoveringOverValidFile: true)
            return .copy
        }

        delegate?.dropZone(self, hoveringOverValidFile: false)
        if !hasSignaledInvalidDrag {
            hasSignaledInvalidDrag = true
            delegate?.dropZoneDidRejectFile(self)
        }
        return []
    }

    private func validCatalogInput(
        from pasteboard: NSPasteboard
    ) -> (catalogURL: URL, securityScopeURL: URL, displayName: String)? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [NSURL], objects.count == 1 else {
            return nil
        }

        let url = objects[0] as URL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }

        if url.pathExtension.caseInsensitiveCompare("car") == .orderedSame,
           !isDirectory.boolValue {
            return (url, url, url.lastPathComponent)
        }

        guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
              isDirectory.boolValue else {
            return nil
        }
        let catalogURL = url
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("Assets.car", isDirectory: false)
        var catalogIsDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: catalogURL.path,
            isDirectory: &catalogIsDirectory
        ), !catalogIsDirectory.boolValue else {
            return nil
        }
        return (catalogURL, url, url.deletingPathExtension().lastPathComponent)
    }
}
