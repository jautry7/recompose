import AppKit
import Symbols

protocol DropZoneViewDelegate: AnyObject {
    func dropZone(_ dropZone: DropZoneView, hoveringOverValidFile isHovering: Bool)
    func dropZone(_ dropZone: DropZoneView, didReceiveCatalogAt url: URL)
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
    private var hasSignaledInvalidDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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

    override func draw(_ dirtyRect: NSRect) {
        let color = isHighlighted
            ? NSColor.controlAccentColor.withAlphaComponent(0.08)
            : NSColor.quaternarySystemFill
        color.setFill()
        dirtyRect.fill()
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

        guard acceptsDrops, let url = validCatalogURL(from: sender.draggingPasteboard) else {
            delegate?.dropZoneDidRejectFile(self)
            return false
        }

        delegate?.dropZone(self, didReceiveCatalogAt: url)
        return true
    }

    private func updateDragState(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard acceptsDrops else { return [] }

        if validCatalogURL(from: sender.draggingPasteboard) != nil {
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

    private func validCatalogURL(from pasteboard: NSPasteboard) -> URL? {
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
        guard url.pathExtension.caseInsensitiveCompare("car") == .orderedSame else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }
        return url
    }
}
