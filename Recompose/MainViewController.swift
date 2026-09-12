import AppKit
import UniformTypeIdentifiers

private final class HoverRevealView: NSView {
    weak var revealedView: NSView? {
        didSet {
            revealedView?.isHidden = false
            revealedView?.alphaValue = 0
        }
    }
    private var hoverTrackingArea: NSTrackingArea?
    private let fadeDuration: TimeInterval = 0.2

    override func updateTrackingAreas() {
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let newTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newTrackingArea)
        hoverTrackingArea = newTrackingArea
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        setRevealed(true)
    }

    override func mouseExited(with event: NSEvent) {
        setRevealed(false)
    }

    private func setRevealed(_ isRevealed: Bool) {
        guard let revealedView else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            revealedView.animator().alphaValue = isRevealed ? 1 : 0
        }
    }
}

private final class CircularShadowView: NSView {
    override func layout() {
        super.layout()
        layer?.shadowPath = CGPath(ellipseIn: bounds, transform: nil)
    }
}

final class MainViewController: NSViewController, DropZoneViewDelegate {
    private enum NoIconReason: Equatable {
        case assetCatalog
        case appMissingAssetCatalog
        case appAssetCatalog

        var message: String {
            switch self {
            case .assetCatalog:
                "This asset catalog does not appear to contain an app icon."
            case .appMissingAssetCatalog:
                "This app does not appear to contain an asset catalog."
            case .appAssetCatalog:
                "This app's asset catalog does not appear to contain an app icon."
            }
        }
    }

    private enum TraditionalBitmapIconSource: Equatable {
        case assetCatalog
        case app

        var message: String {
            switch self {
            case .assetCatalog:
                "This asset catalog contains an older bitmap icon set. Recompose can only reconstruct Liquid Glass icon stacks created with Icon Composer."
            case .app:
                "This app uses an older bitmap icon set. Recompose can only reconstruct Liquid Glass icon stacks created with Icon Composer."
            }
        }
    }

    private enum State: Equatable {
        case resting
        case hovering
        case processing
        case noIcon(NoIconReason)
        case traditionalBitmapIcon(TraditionalBitmapIconSource)
        case singleIcon(String)
        case multipleIcons([String])
        case failure
    }

    private enum Layout {
        /* You're not supposed to design for pixel perfection anymore, but
           screw it, I wanna make the UI perfect.
         
           These enums enable optical tweaks across the UI due to things
           like differing copy length and content size preventing universal
           spacing from looking correct in every context.
         
           Thanks, Codex, for indulging me.
         */
        
        static let paneWidth: CGFloat = 350

        enum LeftPane {
            static let leadingPadding: CGFloat = 48
            static let trailingPadding: CGFloat = 64
            static let eyebrowSymbolPointSize: CGFloat = 13
            static let eyebrowSymbolSpacing: CGFloat = 3

            enum Intro {
                static let centerYOffset: CGFloat = -4
                static let titleSpacing: CGFloat = 6
            }

            enum Success {
                static let centerYOffset: CGFloat = 16
                static let eyebrowSpacing: CGFloat = 14
                static let titleSpacing: CGFloat = 8
                static let detailListSpacing: CGFloat = 4
                static let assetDropdownHorizontalSpacing: CGFloat = 6
                static let assetDropdownBottomSpacing: CGFloat = 8
                static let buttonSpacing: CGFloat = 32
                static let documentToolTipSize: CGFloat = 16
                static let documentToolTipYOffset: CGFloat = 0.5
                static let documentToolTipSymbolPointSize: CGFloat = 13
            }

            enum GenericError {
                static let centerYOffset: CGFloat = 16
                static let eyebrowSpacing: CGFloat = 12
                static let titleSpacing: CGFloat = 6
                static let buttonSpacing: CGFloat = 32
                static let buttonRowSpacing: CGFloat = 10
            }

            enum UnsupportedIcon {
                static let centerYOffset: CGFloat = 20
                static let eyebrowSpacing: CGFloat = 12
                static let titleSpacing: CGFloat = 6
                static let buttonSpacing: CGFloat = 32
            }

            enum NoIcon {
                static let centerYOffset: CGFloat = 16
                static let xSymbolPointSize: CGFloat = 32
                static let xSymbolLayoutWidth: CGFloat = 30
                static let xSymbolSpacing: CGFloat = 18
                static let titleSpacing: CGFloat = 4
                static let buttonSpacing: CGFloat = 32
            }
        }

        enum RightPane {
            enum DropZone {
                static let centerYOffset: CGFloat = -12
                static let symbolPointSize: CGFloat = 112
                static let symbolFrameSize: CGFloat = 144
                static let stackSpacing: CGFloat = 8
            }

            enum Processing {
                static let centerYOffset: CGFloat = -8
                static let spinnerSize: CGFloat = 32
                static let stackSpacing: CGFloat = 16
            }

            enum Preview {
                static let centerYOffset: CGFloat = 0
                static let areaSize: CGFloat = 256
                static let stackSpacing: CGFloat = 16
                static let appearanceSegmentWidth: CGFloat = 40
                static let appearanceSymbolPointSize: CGFloat = 13
                static let clearButtonSize: CGFloat = 36
                static let clearButtonSymbolPointSize: CGFloat = 17
                static let previewClearButtonFromRight: CGFloat = 20
                static let previewClearButtonFromTop: CGFloat = 20
            }
        }
    }

    private enum Typography {
        static let bodyKerning: CGFloat = 0.12
        static let headlineKerning: CGFloat = 0.18
        static let dropPromptKerning: CGFloat = 0.2
        static let titleLineHeight: CGFloat = 26
    }

    private enum Motion {
        static let previewEntranceDelay: TimeInterval = 0.2
        static let previewFadeDuration: TimeInterval = 0.18
        static let previewSpringDurationMultiplier: TimeInterval = 0.5
        static let appearanceControlsDelayAfterSpring: TimeInterval = 0.0
        static let appearanceControlsFadeDuration: TimeInterval = 0.2
    }

    private let leftPaneView = NSView()
    private let dropZoneView = DropZoneView()
    private var leftContentView: NSView?
    private var contentView: NSView?
    private var restingSymbolView: NSImageView?
    private var session: RecompositionSession?
    private var outputs: [String: RecompositionOutput] = [:]
    private var preparingNames: Set<String> = []
    private var animatedPreviewNames: Set<String> = []
    private var lastAvailablePreviewAppearances: Set<IconPreviewAppearance> = []
    private var hasAnimatedAppearanceControl = false
    private var selectedIconName: String?
    private var selectedPreviewAppearance: IconPreviewAppearance = .standard
    private var lastErrorDescription: String?
    private var state: State = .resting
    private var documentVersionPopover: NSPopover?

    override func loadView() {
        let rootView = NSView()
        leftPaneView.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.delegate = self
        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(leftPaneView)
        rootView.addSubview(dropZoneView)
        NSLayoutConstraint.activate([
            leftPaneView.widthAnchor.constraint(equalToConstant: Layout.paneWidth),
            leftPaneView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            leftPaneView.topAnchor.constraint(equalTo: rootView.topAnchor),
            leftPaneView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            dropZoneView.widthAnchor.constraint(equalToConstant: Layout.paneWidth),
            dropZoneView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            dropZoneView.topAnchor.constraint(equalTo: rootView.topAnchor),
            dropZoneView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        render(.resting)
    }

    deinit {
        if let session {
            RecompositionEngine.remove(session)
        }
    }

    func dropZone(_ dropZone: DropZoneView, hoveringOverValidFile isHovering: Bool) {
        guard state == .resting || state == .hovering else { return }
        let nextState: State = isHovering ? .hovering : .resting
        guard nextState != state else { return }
        render(nextState)
    }

    func dropZone(
        _ dropZone: DropZoneView,
        didReceiveCatalogAt catalogURL: URL,
        securityScopeURL: URL,
        displayName: String
    ) {
        guard state == .resting || state == .hovering else { return }
        beginProcessing(
            catalogURL,
            securityScopeURL: securityScopeURL,
            displayName: displayName
        )
    }

    func dropZoneDidRejectFile(_ dropZone: DropZoneView) {
        guard state == .resting else { return }
        restingSymbolView?.addSymbolEffect(.wiggle, options: .speed(2.0))
    }

    private func beginProcessing(
        _ catalogURL: URL,
        securityScopeURL: URL,
        displayName: String
    ) {
        clearSession()
        render(.processing)
        let didAccess = securityScopeURL.startAccessingSecurityScopedResource()
        let sourceIsApp = securityScopeURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var catalogIsDirectory: ObjCBool = false
            let catalogExists = FileManager.default.fileExists(
                atPath: catalogURL.path,
                isDirectory: &catalogIsDirectory
            ) && !catalogIsDirectory.boolValue
            let result: Result<RecompositionSession, Error>? = if catalogExists {
                Result {
                    let preferredIconName = sourceIsApp
                        ? Self.primaryIconName(inAppAt: securityScopeURL)
                        : nil
                    return try RecompositionEngine.inspect(
                        catalogURL: catalogURL,
                        sourceDisplayName: displayName,
                        preferredIconName: preferredIconName
                    )
                }
            } else {
                nil
            }
            if didAccess {
                securityScopeURL.stopAccessingSecurityScopedResource()
            }

            DispatchQueue.main.async {
                guard let self else { return }
                guard let result else {
                    self.render(.noIcon(sourceIsApp ? .appMissingAssetCatalog : .assetCatalog))
                    return
                }
                switch result {
                case .success(let session):
                    self.session = session
                    self.present(session, sourceIsApp: sourceIsApp)
                case .failure(let error):
                    NSLog("Catalog inspection failed: %@", error.localizedDescription)
                    self.lastErrorDescription = error.localizedDescription
                    self.render(.failure)
                }
            }
        }
    }

    private func present(_ session: RecompositionSession, sourceIsApp: Bool) {
        switch session.iconNames.count {
        case 0:
            if session.hasTraditionalBitmapIcon {
                render(.traditionalBitmapIcon(sourceIsApp ? .app : .assetCatalog))
            } else {
                render(.noIcon(sourceIsApp ? .appAssetCatalog : .assetCatalog))
            }
        case 1:
            let name = session.iconNames[0]
            selectedIconName = name
            prepareIcon(named: name, in: session)
        default:
            let name = session.iconNames[0]
            selectedIconName = name
            render(.multipleIcons(session.iconNames))
            prepareIcon(named: name, in: session)
        }
    }

    private func prepareIcon(named name: String, in session: RecompositionSession) {
        if outputs[name] != nil {
            showCompletedSelection(in: session)
            return
        }
        guard !preparingNames.contains(name) else { return }

        preparingNames.insert(name)
        if session.iconNames.count == 1 {
            render(.processing)
        } else {
            render(.multipleIcons(session.iconNames))
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try RecompositionEngine.recompose(session: session, assetName: name)
            }

            DispatchQueue.main.async {
                guard let self, self.session?.id == session.id else { return }
                self.preparingNames.remove(name)
                switch result {
                case .success(let output):
                    self.outputs[name] = output
                    if self.selectedIconName == name {
                        self.showCompletedSelection(in: session)
                    }
                case .failure(let error):
                    NSLog("Recomposition failed for %@: %@", name, error.localizedDescription)
                    if self.selectedIconName == name {
                        self.lastErrorDescription = error.localizedDescription
                        self.render(.failure)
                    }
                }
            }
        }
    }

    private func showCompletedSelection(in session: RecompositionSession) {
        guard let selectedIconName else { return }
        if session.iconNames.count == 1 {
            render(.singleIcon(selectedIconName))
        } else {
            render(.multipleIcons(session.iconNames))
        }
    }

    private func render(_ newState: State) {
        state = newState
        dropZoneView.acceptsDrops = newState == .resting || newState == .hovering
        dropZoneView.isHighlighted = newState == .hovering
        restingSymbolView = nil
        updateLeftPane(for: newState)

        contentView?.removeFromSuperview()
        let replacement: NSView
        switch newState {
        case .resting:
            replacement = makeDropPrompt(isHovering: false)
        case .hovering:
            replacement = makeDropPrompt(isHovering: true)
        case .processing:
            replacement = makeProcessingView()
        case .noIcon, .traditionalBitmapIcon:
            replacement = makeDropPrompt(isHovering: false)
        case .singleIcon:
            replacement = makeSuccessPreviewView()
        case .multipleIcons:
            replacement = makeSuccessPreviewView()
        case .failure:
            replacement = makeDropPrompt(isHovering: false)
        }

        replacement.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.installContentView(replacement)
        NSLayoutConstraint.activate([
            replacement.leadingAnchor.constraint(equalTo: dropZoneView.leadingAnchor),
            replacement.trailingAnchor.constraint(equalTo: dropZoneView.trailingAnchor),
            replacement.topAnchor.constraint(equalTo: dropZoneView.topAnchor),
            replacement.bottomAnchor.constraint(equalTo: dropZoneView.bottomAnchor)
        ])
        contentView = replacement
    }

    private func updateLeftPane(for state: State) {
        leftContentView?.removeFromSuperview()

        switch state {
        case .resting, .hovering, .processing:
            let title = makePreferredLabel(
                "Welcome",
                textStyle: .largeTitle,
                emphasized: true,
                color: .labelColor
            )
            title.alignment = .left
            let text = NSMutableAttributedString(attributedString: title.attributedStringValue)
            text.addAttribute(
                .kern,
                value: Typography.headlineKerning,
                range: NSRange(location: 0, length: text.length)
            )
            title.attributedStringValue = text

            let description = makePreferredLabel(
                "Reconstruct any Liquid Glass app icon as an Icon Composer document.",
                textStyle: .body,
                color: .secondaryLabelColor
            )
            description.alignment = .left
            description.maximumNumberOfLines = 3
            description.lineBreakMode = .byWordWrapping
            let textD = NSMutableAttributedString(attributedString: description.attributedStringValue)
            textD.addAttribute(
                .kern,
                value: Typography.bodyKerning,
                range: NSRange(location: 0, length: textD.length)
            )
            description.attributedStringValue = textD

            let stack = NSStackView(views: [title, description])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = Layout.LeftPane.Intro.titleSpacing
            description.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            installLeftContent(stack, centerYOffset: Layout.LeftPane.Intro.centerYOffset)
        case .singleIcon(let name):
            installLeftContent(
                makeSuccessContent(assetName: name, names: nil),
                centerYOffset: Layout.LeftPane.Success.centerYOffset
            )
        case .multipleIcons(let names):
            let selectedName = selectedIconName ?? names[0]
            installLeftContent(
                makeSuccessContent(assetName: selectedName, names: names),
                centerYOffset: Layout.LeftPane.Success.centerYOffset
            )
        case .noIcon(let reason):
            installLeftContent(
                makeNoIconContent(reason: reason),
                centerYOffset: Layout.LeftPane.NoIcon.centerYOffset
            )
        case .traditionalBitmapIcon(let source):
            installLeftContent(
                makeTraditionalBitmapIconContent(source: source),
                centerYOffset: Layout.LeftPane.UnsupportedIcon.centerYOffset
            )
        case .failure:
            installLeftContent(
                makeGenericErrorContent(),
                centerYOffset: Layout.LeftPane.GenericError.centerYOffset
            )
        }
    }

    private func installLeftContent(_ content: NSView, centerYOffset: CGFloat) {
        content.translatesAutoresizingMaskIntoConstraints = false
        leftPaneView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(
                equalTo: leftPaneView.leadingAnchor,
                constant: Layout.LeftPane.leadingPadding
            ),
            content.trailingAnchor.constraint(
                equalTo: leftPaneView.trailingAnchor,
                constant: -Layout.LeftPane.trailingPadding
            ),
            content.centerYAnchor.constraint(
                equalTo: leftPaneView.centerYAnchor,
                constant: centerYOffset
            )
        ])
        leftContentView = content
    }

    private func makeNoIconContent(reason: NoIconReason) -> NSView {
        let symbol = makeSymbolView(
            named: "xmark.circle",
            pointSize: Layout.LeftPane.NoIcon.xSymbolPointSize,
            weight: .light,
            color: .tertiaryLabelColor,
            accessibilityDescription: "No icon found"
        )
        let symbolContainer = NSView()
        symbol.translatesAutoresizingMaskIntoConstraints = false
        symbolContainer.addSubview(symbol)
        NSLayoutConstraint.activate([
            symbolContainer.widthAnchor.constraint(
                equalToConstant: Layout.LeftPane.NoIcon.xSymbolLayoutWidth
            ),
            symbol.centerXAnchor.constraint(equalTo: symbolContainer.centerXAnchor),
            symbol.topAnchor.constraint(equalTo: symbolContainer.topAnchor),
            symbol.bottomAnchor.constraint(equalTo: symbolContainer.bottomAnchor)
        ])
        let header = makeErrorHeader(
            title: "No icon found",
            message: reason.message,
            spacing: Layout.LeftPane.NoIcon.titleSpacing,
            titleLines: 1
        )

        let information = NSStackView(views: [symbolContainer, header])
        information.orientation = .vertical
        information.alignment = .leading
        information.spacing = Layout.LeftPane.NoIcon.xSymbolSpacing

        let okayButton = NSButton(title: "OK", target: self, action: #selector(goBack))
        configureButton(okayButton)

        let content = NSStackView(views: [information, okayButton])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = Layout.LeftPane.NoIcon.buttonSpacing
        information.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        header.widthAnchor.constraint(equalTo: information.widthAnchor).isActive = true
        return content
    }

    private func makeGenericErrorContent() -> NSView {
        let status = makeStatusView(
            "Error",
            symbolName: "xmark.circle",
            color: .systemRed
        )
        let header = makeErrorHeader(
            title: "Could not process asset catalog",
            message: "An unknown error occurred and the CAR file could not be processed.",
            spacing: Layout.LeftPane.GenericError.titleSpacing,
            titleLines: 2,
            titleLineHeight: Typography.titleLineHeight
        )

        let information = NSStackView(views: [status, header])
        information.orientation = .vertical
        information.alignment = .leading
        information.spacing = Layout.LeftPane.GenericError.eyebrowSpacing

        let okayButton = NSButton(title: "OK", target: self, action: #selector(goBack))
        configureButton(okayButton)

        let copyButton = NSButton(title: "Copy Error", target: self, action: #selector(copyError))
        copyButton.isBordered = false
        copyButton.controlSize = .extraLarge
        copyButton.font = .systemFont(ofSize: 13)

        let actions = NSStackView(views: [okayButton, copyButton])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = Layout.LeftPane.GenericError.buttonRowSpacing

        let content = NSStackView(views: [information, actions])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = Layout.LeftPane.GenericError.buttonSpacing
        information.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        header.widthAnchor.constraint(equalTo: information.widthAnchor).isActive = true
        return content
    }

    private func makeTraditionalBitmapIconContent(source: TraditionalBitmapIconSource) -> NSView {
        let status = makeStatusView(
            "Old icon identified",
            symbolName: "exclamationmark.circle",
            color: .systemOrange
        )
        let header = makeErrorHeader(
            title: "Icon not supported",
            message: source.message,
            spacing: Layout.LeftPane.UnsupportedIcon.titleSpacing,
            titleLines: 2,
            messageLines: 0
        )

        let information = NSStackView(views: [status, header])
        information.orientation = .vertical
        information.alignment = .leading
        information.spacing = Layout.LeftPane.UnsupportedIcon.eyebrowSpacing

        let okayButton = NSButton(title: "OK", target: self, action: #selector(goBack))
        configureButton(okayButton)

        let content = NSStackView(views: [information, okayButton])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = Layout.LeftPane.UnsupportedIcon.buttonSpacing
        information.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        header.widthAnchor.constraint(equalTo: information.widthAnchor).isActive = true
        return content
    }

    private nonisolated static func primaryIconName(inAppAt appURL: URL) -> String? {
        guard let info = Bundle(url: appURL)?.infoDictionary else { return nil }
        if let name = info["CFBundleIconName"] as? String, !name.isEmpty {
            return name
        }
        guard let icons = info["CFBundleIcons"] as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let name = primaryIcon["CFBundleIconName"] as? String,
              !name.isEmpty else {
            return nil
        }
        return name
    }

    private func makeErrorHeader(
        title: String,
        message: String,
        spacing: CGFloat,
        titleLines: Int,
        titleLineHeight: CGFloat? = nil,
        messageLines: Int = 2
    ) -> NSView {
        let titleLabel = makePreferredLabel(
            title,
            textStyle: .largeTitle,
            emphasized: true,
            color: .labelColor
        )
        titleLabel.alignment = .left
        titleLabel.maximumNumberOfLines = titleLines
        titleLabel.lineBreakMode = .byWordWrapping
        let titleText = NSMutableAttributedString(attributedString: titleLabel.attributedStringValue)
        titleText.addAttribute(
            .kern,
            value: Typography.headlineKerning,
            range: NSRange(location: 0, length: titleText.length)
        )
        if let titleLineHeight {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.minimumLineHeight = titleLineHeight
            paragraphStyle.maximumLineHeight = titleLineHeight
            titleText.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: titleText.length)
            )
        }
        titleLabel.attributedStringValue = titleText

        let messageLabel = makePreferredLabel(
            message,
            textStyle: .body,
            color: .secondaryLabelColor
        )
        messageLabel.alignment = .left
        messageLabel.maximumNumberOfLines = messageLines
        messageLabel.lineBreakMode = .byWordWrapping
        let messageText = NSMutableAttributedString(attributedString: messageLabel.attributedStringValue)
        messageText.addAttribute(
            .kern,
            value: Typography.bodyKerning,
            range: NSRange(location: 0, length: messageText.length)
        )
        messageLabel.attributedStringValue = messageText

        let header = NSStackView(views: [titleLabel, messageLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = spacing
        titleLabel.widthAnchor.constraint(equalTo: header.widthAnchor).isActive = true
        messageLabel.widthAnchor.constraint(equalTo: header.widthAnchor).isActive = true
        return header
    }

    private func makeSuccessContent(assetName: String, names: [String]?) -> NSView {
        let status = makeStatusView(
            names == nil ? "Icon identified" : "Multiple icons identified"
        )

        let title = makePreferredLabel(
            session?.sourceDisplayName ?? "Assets.car",
            textStyle: .largeTitle,
            emphasized: true,
            color: .labelColor
        )
        title.alignment = .left
        title.maximumNumberOfLines = 0
        title.lineBreakMode = .byWordWrapping
        let textT = NSMutableAttributedString(attributedString: title.attributedStringValue)
        textT.addAttribute(
            .kern,
            value: Typography.headlineKerning,
            range: NSRange(location: 0, length: textT.length)
        )
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.minimumLineHeight = Typography.titleLineHeight
        titleParagraphStyle.maximumLineHeight = Typography.titleLineHeight
        textT.addAttribute(
            .paragraphStyle,
            value: titleParagraphStyle,
            range: NSRange(location: 0, length: textT.length)
        )
        title.attributedStringValue = textT

        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = Layout.LeftPane.Success.detailListSpacing

        if let names {
            let selectionRow = makeAssetSelectionRow(names: names)
            details.addArrangedSubview(selectionRow)
            details.setCustomSpacing(Layout.LeftPane.Success.assetDropdownBottomSpacing, after: selectionRow)
        } else {
            details.addArrangedSubview(
                makeDetailLabel(prefix: "Asset name:", value: assetName)
            )
        }

        let generation = session?.minimumGenerations[assetName]
        details.addArrangedSubview(
            makeDetailLabel(
                prefix: "Compiled with:",
                value: session?.compilerVersion.map { "Xcode \($0)" } ?? "—"
            )
        )
        details.addArrangedSubview(makeDocumentVersionRow(generation: generation))

        let titleAndDetails = NSStackView(views: [title, details])
        titleAndDetails.orientation = .vertical
        titleAndDetails.alignment = .leading
        titleAndDetails.spacing = Layout.LeftPane.Success.titleSpacing

        let information = NSStackView(views: [status, titleAndDetails])
        information.orientation = .vertical
        information.alignment = .leading
        information.spacing = Layout.LeftPane.Success.eyebrowSpacing

        let saveButton = NSButton(title: "Save Icon", target: self, action: #selector(saveIcon))
        configureButton(saveButton)
        saveButton.keyEquivalent = "\r"
        saveButton.isEnabled = outputs[assetName] != nil

        let content = NSStackView(views: [information, saveButton])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = Layout.LeftPane.Success.buttonSpacing
        title.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        return content
    }

    private func makeStatusView(
        _ text: String,
        symbolName: String = "checkmark.circle",
        color: NSColor = .systemGreen
    ) -> NSView {
        let symbol = makeSymbolView(
            named: symbolName,
            pointSize: Layout.LeftPane.eyebrowSymbolPointSize,
            weight: .semibold,
            color: color,
            accessibilityDescription: text
        )
        let label = makePreferredLabel(
            text,
            textStyle: .body,
            color: color
        )
        label.alignment = .left
        label.font = .systemFont(ofSize: label.font!.pointSize, weight: .medium)
        let textL = NSMutableAttributedString(attributedString: label.attributedStringValue)
        textL.addAttribute(
            .kern,
            value: Typography.headlineKerning,
            range: NSRange(location: 0, length: textL.length)
        )
        label.attributedStringValue = textL

        let row = NSStackView(views: [symbol, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Layout.LeftPane.eyebrowSymbolSpacing
        return row
    }

    private func makeAssetSelectionRow(names: [String]) -> NSView {
        let prompt = makeDetailLabel(prefix: "Choose an asset:")

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.controlSize = .regular
        for name in names {
            popup.addItem(withTitle: name)
            popup.lastItem?.representedObject = name
        }
        let selectedName = selectedIconName ?? names[0]
        if let selectedIndex = popup.itemArray.firstIndex(where: {
            ($0.representedObject as? String) == selectedName
        }) {
            popup.selectItem(at: selectedIndex)
        }
        popup.target = self
        popup.action = #selector(selectIcon(_:))

        let row = NSStackView(views: [prompt, popup])
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = Layout.LeftPane.Success.assetDropdownHorizontalSpacing
        return row
    }

    private func makeDetailLabel(prefix: String, value: String? = nil) -> NSTextField {
        let regularFont = NSFont.preferredFont(forTextStyle: .body)
        let emphasizedFont = NSFontManager.shared.convert(
            regularFont,
            toHaveTrait: .boldFontMask
        )
        let string = value.map { "\(prefix) \($0)" } ?? prefix
        let text = NSMutableAttributedString(
            string: string,
            attributes: [
                .font: regularFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        text.addAttribute(
            .font,
            value: emphasizedFont,
            range: NSRange(location: 0, length: prefix.utf16.count)
        )

        let label = NSTextField(labelWithAttributedString: text)
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.maximumNumberOfLines = 1
        let textLa = NSMutableAttributedString(attributedString: label.attributedStringValue)
        textLa.addAttribute(
            .kern,
            value: Typography.bodyKerning,
            range: NSRange(location: 0, length: textLa.length)
        )
        label.attributedStringValue = textLa
        return label
    }

    private func makeDocumentVersionRow(generation: Int?) -> NSView {
        let label = makeDetailLabel(
            prefix: "Document version:",
            value: generation.map { "v\($0)" } ?? "—"
        )
        let helpConfiguration = NSImage.SymbolConfiguration(
            pointSize: Layout.LeftPane.Success.documentToolTipSymbolPointSize,
            weight: .medium
        )
        let helpImage = NSImage(
            systemSymbolName: "questionmark.circle",
            accessibilityDescription: "Document version information"
        )?.withSymbolConfiguration(helpConfiguration) ?? NSImage()
        let help = NSButton(
            image: helpImage,
            target: self,
            action: #selector(showDocumentVersionHelp(_:))
        )
        help.isBordered = false
        help.imagePosition = .imageOnly
        help.imageScaling = .scaleProportionallyDown
        help.contentTintColor = .tertiaryLabelColor
        help.setAccessibilityLabel("About document version")

        let helpContainer = NSView()
        help.translatesAutoresizingMaskIntoConstraints = false
        helpContainer.addSubview(help)
        NSLayoutConstraint.activate([
            helpContainer.widthAnchor.constraint(equalToConstant: Layout.LeftPane.Success.documentToolTipSize),
            helpContainer.heightAnchor.constraint(equalToConstant: Layout.LeftPane.Success.documentToolTipSize),
            help.widthAnchor.constraint(equalToConstant: Layout.LeftPane.Success.documentToolTipSize),
            help.heightAnchor.constraint(equalToConstant: Layout.LeftPane.Success.documentToolTipSize),
            help.centerXAnchor.constraint(equalTo: helpContainer.centerXAnchor),
            help.centerYAnchor.constraint(
                equalTo: helpContainer.centerYAnchor,
                constant: Layout.LeftPane.Success.documentToolTipYOffset
            )
        ])

        let row = NSStackView(views: [label, helpContainer])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 4
        return row
    }

    private func makeSuccessPreviewView() -> NSView {
        let container = NSView()
        let previewContainer = HoverRevealView()

        let preview = NSBox()
        preview.boxType = .custom
        preview.borderWidth = 0
        preview.fillColor = .clear
        preview.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(preview)
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            preview.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            preview.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor)
        ])

        let output = selectedIconName.flatMap { outputs[$0] }
        let shouldAnimatePreview = output != nil
            && selectedIconName.map { animatedPreviewNames.insert($0).inserted } == true
        let previewURL = output?.previewURLs[selectedPreviewAppearance]
            ?? output?.previewURLs[.standard]
        let previewImage: NSImage? = if output == nil {
            nil
        } else {
            previewURL.flatMap { NSImage(contentsOf: $0) } ?? genericDocumentIcon()
        }
        var imageView: NSImageView?
        if let previewImage {
            let loadedImageView = NSImageView(image: previewImage)
            loadedImageView.imageScaling = .scaleProportionallyUpOrDown
            loadedImageView.translatesAutoresizingMaskIntoConstraints = false
            loadedImageView.setAccessibilityLabel("Identified icon preview")
            preview.addSubview(loadedImageView)
            NSLayoutConstraint.activate([
                loadedImageView.leadingAnchor.constraint(equalTo: preview.leadingAnchor),
                loadedImageView.trailingAnchor.constraint(equalTo: preview.trailingAnchor),
                loadedImageView.topAnchor.constraint(equalTo: preview.topAnchor),
                loadedImageView.bottomAnchor.constraint(equalTo: preview.bottomAnchor)
            ])
            imageView = loadedImageView
        } else {
            let progressIndicator = NSProgressIndicator()
            progressIndicator.style = .spinning
            progressIndicator.controlSize = .regular
            progressIndicator.isIndeterminate = true
            progressIndicator.translatesAutoresizingMaskIntoConstraints = false
            progressIndicator.setAccessibilityLabel("Preparing icon preview")
            progressIndicator.startAnimation(nil)
            preview.addSubview(progressIndicator)
            NSLayoutConstraint.activate([
                progressIndicator.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
                progressIndicator.centerYAnchor.constraint(equalTo: preview.centerYAnchor)
            ])
        }
        let clearSymbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: Layout.RightPane.Preview.clearButtonSymbolPointSize,
            weight: .semibold
        )
        let clearImage = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Clear")?
            .withSymbolConfiguration(clearSymbolConfiguration) ?? NSImage()
        let clearButton = NSButton(image: clearImage, target: self, action: #selector(goBack))
        clearButton.isBordered = false
        clearButton.imagePosition = .imageOnly
        clearButton.contentTintColor = .labelColor
        clearButton.setAccessibilityLabel("Clear")
        clearButton.toolTip = "Clear"

        let clearGlass = NSGlassEffectView()
        clearGlass.style = .regular
        clearGlass.cornerRadius = Layout.RightPane.Preview.clearButtonSize / 2
        if #available(macOS 27.0, *) {
            clearGlass.effectIsInteractive = true
        }
        clearGlass.contentView = clearButton
        clearGlass.translatesAutoresizingMaskIntoConstraints = false

        let clearShadow = CircularShadowView()
        clearShadow.isHidden = true
        clearShadow.translatesAutoresizingMaskIntoConstraints = false
        clearShadow.wantsLayer = true
        clearShadow.layer?.shadowColor = NSColor.black.cgColor
        clearShadow.layer?.shadowOpacity = 0.15
        clearShadow.layer?.shadowRadius = 6
        clearShadow.layer?.shadowOffset = CGSize(width: 0, height: -5)
        clearShadow.addSubview(clearGlass)
        previewContainer.addSubview(clearShadow)
        previewContainer.revealedView = clearShadow
        NSLayoutConstraint.activate([
            clearGlass.leadingAnchor.constraint(equalTo: clearShadow.leadingAnchor),
            clearGlass.trailingAnchor.constraint(equalTo: clearShadow.trailingAnchor),
            clearGlass.topAnchor.constraint(equalTo: clearShadow.topAnchor),
            clearGlass.bottomAnchor.constraint(equalTo: clearShadow.bottomAnchor),
            clearShadow.widthAnchor.constraint(equalToConstant: Layout.RightPane.Preview.clearButtonSize),
            clearShadow.heightAnchor.constraint(equalToConstant: Layout.RightPane.Preview.clearButtonSize),
            clearShadow.trailingAnchor.constraint(
                equalTo: previewContainer.trailingAnchor,
                constant: -Layout.RightPane.Preview.previewClearButtonFromRight
            ),
            clearShadow.topAnchor.constraint(
                equalTo: previewContainer.topAnchor,
                constant: Layout.RightPane.Preview.previewClearButtonFromTop
            )
        ])

        var arrangedViews: [NSView] = [previewContainer]
        var appearanceControl: NSSegmentedControl?
        let availablePreviewAppearances: Set<IconPreviewAppearance>
        if let output {
            availablePreviewAppearances = Set(output.previewURLs.keys)
            lastAvailablePreviewAppearances = availablePreviewAppearances
        } else {
            availablePreviewAppearances = lastAvailablePreviewAppearances
        }
        var shouldAnimateAppearanceControl = false
        if availablePreviewAppearances.count > 1 {
            let appearances = IconPreviewAppearance.allCases
            let symbolNames = ["sun.max", "moon", "circle.righthalf.filled"]
            let symbolConfiguration = NSImage.SymbolConfiguration(
                pointSize: Layout.RightPane.Preview.appearanceSymbolPointSize,
                weight: .semibold
            )
            let images = symbolNames.map {
                NSImage(systemSymbolName: $0, accessibilityDescription: nil)?
                    .withSymbolConfiguration(symbolConfiguration) ?? NSImage()
            }
            let control = NSSegmentedControl(
                images: images,
                trackingMode: .selectOne,
                target: self,
                action: #selector(selectPreviewAppearance(_:))
            )
            control.controlSize = .large
            control.segmentStyle = .rounded
            control.selectedSegmentBezelColor = .unemphasizedSelectedContentBackgroundColor
            control.selectedSegment = appearances.firstIndex(of: selectedPreviewAppearance) ?? 0
            for (index, appearance) in appearances.enumerated() {
                control.setWidth(Layout.RightPane.Preview.appearanceSegmentWidth, forSegment: index)
                control.setToolTip(appearance.displayName, forSegment: index)
                control.setEnabled(availablePreviewAppearances.contains(appearance), forSegment: index)
            }
            shouldAnimateAppearanceControl = !hasAnimatedAppearanceControl
            hasAnimatedAppearanceControl = true
            appearanceControl = control
            arrangedViews.append(control)
        }
        let stack = NSStackView(views: arrangedViews)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Layout.RightPane.Preview.stackSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            previewContainer.widthAnchor.constraint(equalToConstant: Layout.RightPane.Preview.areaSize),
            previewContainer.heightAnchor.constraint(equalToConstant: Layout.RightPane.Preview.areaSize),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(
                equalTo: container.centerYAnchor,
                constant: Layout.RightPane.Preview.centerYOffset
            )
        ])
        if shouldAnimatePreview, let imageView {
            animatePreviewEntrance(
                imageView,
                appearanceControl: appearanceControl,
                animateAppearanceControl: shouldAnimateAppearanceControl
            )
        }
        return container
    }

    private func genericDocumentIcon() -> NSImage {
        NSWorkspace.shared.icon(for: .data)
    }

    private func animatePreviewEntrance(
        _ imageView: NSImageView,
        appearanceControl: NSSegmentedControl?,
        animateAppearanceControl: Bool
    ) {
        imageView.wantsLayer = true
        imageView.layer?.opacity = 0
        if animateAppearanceControl {
            appearanceControl?.alphaValue = 0
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.82
        spring.toValue = 1
        spring.mass = 1
        spring.stiffness = 240
        spring.damping = 15
        spring.initialVelocity = 0
        spring.duration = spring.settlingDuration * Motion.previewSpringDurationMultiplier

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Motion.previewEntranceDelay
        ) { [weak imageView] in
            guard let imageView, imageView.window != nil, let layer = imageView.layer else { return }

            let frame = layer.frame
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.frame = frame
            layer.opacity = 1

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = Motion.previewFadeDuration
            layer.add(fade, forKey: "previewFadeIn")

            if !reduceMotion {
                layer.add(spring, forKey: "previewBounceIn")
            }
        }

        if animateAppearanceControl {
            let previewAnimationDuration = reduceMotion
                ? Motion.previewFadeDuration
                : spring.duration
            let appearanceControlsDelay = Motion.previewEntranceDelay
                + previewAnimationDuration
                + Motion.appearanceControlsDelayAfterSpring
            DispatchQueue.main.asyncAfter(
                deadline: .now() + appearanceControlsDelay
            ) { [weak appearanceControl] in
                guard let appearanceControl, appearanceControl.window != nil else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Motion.appearanceControlsFadeDuration
                    appearanceControl.animator().alphaValue = 1
                }
            }
        }
    }

    private func makePreferredLabel(
        _ string: String,
        textStyle: NSFont.TextStyle,
        emphasized: Bool = false,
        color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        let preferredFont = NSFont.preferredFont(forTextStyle: textStyle)
        label.font = emphasized
            ? NSFontManager.shared.convert(preferredFont, toHaveTrait: .boldFontMask)
            : preferredFont
        label.textColor = color
        label.alignment = .center
        label.maximumNumberOfLines = 1
        return label
    }

    private func makeDropPrompt(isHovering: Bool) -> NSView {
        let container = NSView()
        let symbolName: String
        if isHovering {
            symbolName = "arrow.down.circle"
        } else if NSImage(systemSymbolName: "square.dashed.micro", accessibilityDescription: nil) != nil {
            symbolName = "square.dashed.micro"
        } else {
            symbolName = "square.dashed"
        }
        let symbol = makeSymbolView(
            named: symbolName,
            pointSize: Layout.RightPane.DropZone.symbolPointSize,
            weight: .ultraLight,
            color: isHovering ? .controlAccentColor : .tertiaryLabelColor,
            accessibilityDescription: isHovering ? "Ready to drop" : "Drop zone"
        )
        let label = makePreferredLabel(
            "Drop an app or\nAssets.car file here",
            textStyle: .title2,
            color: isHovering ? .controlAccentColor : .secondaryLabelColor
        )
        label.maximumNumberOfLines = 2
        let text = NSMutableAttributedString(attributedString: label.attributedStringValue)
        text.addAttribute(
            .kern,
            value: Typography.dropPromptKerning,
            range: NSRange(location: 0, length: text.length)
        )
        label.attributedStringValue = text
        label.alphaValue = isHovering ? 1.0 : 0.7

        let stack = NSStackView(views: [symbol, label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Layout.RightPane.DropZone.stackSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: Layout.RightPane.DropZone.symbolFrameSize),
            symbol.heightAnchor.constraint(equalToConstant: Layout.RightPane.DropZone.symbolFrameSize),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(
                equalTo: container.centerYAnchor,
                constant: Layout.RightPane.DropZone.centerYOffset
            )
        ])

        if !isHovering {
            restingSymbolView = symbol
        }
        return container
    }

    private func makeProcessingView() -> NSView {
        let container = NSView()
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .large
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)

        let label = makeLabel(
            "Processing",
            size: 17,
            weight: .regular,
            color: .secondaryLabelColor
        )
        let stack = NSStackView(views: [spinner, label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Layout.RightPane.Processing.stackSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            spinner.widthAnchor.constraint(equalToConstant: Layout.RightPane.Processing.spinnerSize),
            spinner.heightAnchor.constraint(equalToConstant: Layout.RightPane.Processing.spinnerSize),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(
                equalTo: container.centerYAnchor,
                constant: Layout.RightPane.Processing.centerYOffset
            )
        ])
        return container
    }

    private func makeSymbolView(
        named name: String,
        pointSize: CGFloat,
        weight: NSFont.Weight,
        color: NSColor,
        accessibilityDescription: String
    ) -> NSImageView {
        let baseImage = NSImage(
            systemSymbolName: name,
            accessibilityDescription: accessibilityDescription
        ) ?? NSImage()
        let configuration = NSImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: weight
        )
        let image = baseImage.withSymbolConfiguration(configuration) ?? baseImage
        let imageView = NSImageView(image: image)
        imageView.contentTintColor = color
        imageView.imageScaling = .scaleProportionallyDown
        return imageView
    }

    private func makeLabel(
        _ string: String,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = .center
        label.maximumNumberOfLines = 1
        return label
    }

    private func configureButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.controlSize = .extraLarge
        button.font = .systemFont(ofSize: 13)
    }

    private func clearSession() {
        documentVersionPopover?.close()
        documentVersionPopover = nil
        if let session {
            RecompositionEngine.remove(session)
        }
        session = nil
        outputs.removeAll()
        preparingNames.removeAll()
        animatedPreviewNames.removeAll()
        lastAvailablePreviewAppearances.removeAll()
        hasAnimatedAppearanceControl = false
        selectedIconName = nil
        selectedPreviewAppearance = .standard
        lastErrorDescription = nil
    }

    @objc private func goBack() {
        clearSession()
        render(.resting)
    }

    @objc private func selectIcon(_ sender: NSPopUpButton) {
        guard let session,
              let name = sender.selectedItem?.representedObject as? String else { return }
        selectedIconName = name
        render(.multipleIcons(session.iconNames))
        prepareIcon(named: name, in: session)
    }

    @objc private func selectPreviewAppearance(_ sender: NSSegmentedControl) {
        let appearances = IconPreviewAppearance.allCases
        guard appearances.indices.contains(sender.selectedSegment) else { return }
        selectedPreviewAppearance = appearances[sender.selectedSegment]
        render(state)
    }

    @objc private func copyError() {
        guard let lastErrorDescription else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lastErrorDescription, forType: .string)
    }

    @objc private func showDocumentVersionHelp(_ sender: NSButton) {
        if let documentVersionPopover, documentVersionPopover.isShown {
            documentVersionPopover.close()
            self.documentVersionPopover = nil
            return
        }

        let explanation = NSTextField(
            wrappingLabelWithString: "Recompose uses the earliest Icon Composer document version that can represent all of this icon’s features. This prevents missing material properties from reverting to their default values, which could alter the intended appearance."
        )
        explanation.font = NSFont.preferredFont(forTextStyle: .body)
        explanation.textColor = .labelColor
        explanation.preferredMaxLayoutWidth = 240
        explanation.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(explanation)
        NSLayoutConstraint.activate([
            explanation.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            explanation.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            explanation.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            explanation.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            explanation.widthAnchor.constraint(equalToConstant: 240)
        ])

        let controller = NSViewController()
        controller.view = content
        content.layoutSubtreeIfNeeded()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = controller
        popover.contentSize = content.fittingSize
        documentVersionPopover = popover
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxX)
    }

    @objc private func saveIcon() {
        guard let selectedIconName,
              let output = outputs[selectedIconName],
              let window = view.window else { return }

        let panel = NSSavePanel()
        panel.title = "Save Reconstructed Icon"
        panel.nameFieldStringValue = "\(safeFilename(selectedIconName))-recomposed.icon"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if let iconType = UTType(filenameExtension: "icon", conformingTo: .package) {
            panel.allowedContentTypes = [iconType]
        }

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destinationURL = panel.url else { return }
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: output.iconURL, to: destinationURL)
            } catch {
                NSLog("Saving recomposed icon failed: %@", error.localizedDescription)
            }
        }
    }

    private func safeFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitized = name.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        let result = String(sanitized)
        return result.isEmpty ? "icon" : result
    }

}
