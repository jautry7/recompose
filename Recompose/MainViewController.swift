import AppKit
import UniformTypeIdentifiers

final class MainViewController: NSViewController, DropZoneViewDelegate {
    private enum State: Equatable {
        case resting
        case hovering
        case processing
        case noIcon
        case singleIcon(String)
        case multipleIcons([String])
        case failure
    }

    private enum Layout {
        static let assetLabelToDropdownSpacing: CGFloat = 6
        static let paneWidth: CGFloat = 350
        static let introLeading: CGFloat = 48
        static let introBodyWidth: CGFloat = 222
        static let introSpacing: CGFloat = 4
        static let introCenterYOffset: CGFloat = -4
        static let successLeading: CGFloat = 48
        static let successCenterYOffset: CGFloat = 12
        static let successSectionSpacing: CGFloat = 14
        static let successTitleSpacing: CGFloat = 8
        static let successDetailSpacing: CGFloat = 5
        static let assetSelectionBottomSpacing: CGFloat = 8
        static let successButtonSpacing: CGFloat = 32
        static let documentHelpSize: CGFloat = 16
        static let documentHelpYOffset: CGFloat = 0.5
        static let previewSize: CGFloat = 256
        static let previewButtonSpacing: CGFloat = 8
    }

    private enum Typography {
        static let bodyKerning: CGFloat = 0.1
        static let headlineKerning: CGFloat = 0.2
        static let dropPromptKerning: CGFloat = 0.2
    }

    private let leftPaneView = NSView()
    private let dropZoneView = DropZoneView()
    private var leftContentView: NSView?
    private var contentView: NSView?
    private var restingSymbolView: NSImageView?
    private var session: RecompositionSession?
    private var outputs: [String: RecompositionOutput] = [:]
    private var preparingNames: Set<String> = []
    private var selectedIconName: String?
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

    func dropZone(_ dropZone: DropZoneView, didReceiveCatalogAt url: URL) {
        guard state == .resting || state == .hovering else { return }
        beginProcessing(url)
    }

    func dropZoneDidRejectFile(_ dropZone: DropZoneView) {
        guard state == .resting else { return }
        restingSymbolView?.addSymbolEffect(.wiggle, options: .speed(2.0))
    }

    private func beginProcessing(_ catalogURL: URL) {
        clearSession()
        render(.processing)
        let didAccess = catalogURL.startAccessingSecurityScopedResource()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try RecompositionEngine.inspect(catalogURL: catalogURL) }
            if didAccess {
                catalogURL.stopAccessingSecurityScopedResource()
            }

            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let session):
                    self.session = session
                    self.present(session)
                case .failure(let error):
                    NSLog("Catalog inspection failed: %@", error.localizedDescription)
                    self.render(.failure)
                }
            }
        }
    }

    private func present(_ session: RecompositionSession) {
        switch session.iconNames.count {
        case 0:
            render(.noIcon)
        case 1:
            let name = session.iconNames[0]
            selectedIconName = name
            prepareIcon(named: name, in: session)
        default:
            let name = session.iconNames.contains("AppIcon")
                ? "AppIcon"
                : session.iconNames[0]
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
        case .noIcon:
            replacement = makeResultView(
                symbolName: "xmark.circle",
                symbolColor: .tertiaryLabelColor,
                title: "No icon found",
                message: "This asset catalog does not appear to\ncontain an IconImageStack"
            )
        case .singleIcon:
            replacement = makeSuccessPreviewView()
        case .multipleIcons:
            replacement = makeSuccessPreviewView()
        case .failure:
            replacement = makeResultView(
                symbolName: "xmark.circle",
                symbolColor: .systemRed,
                title: "Could not process CAR file",
                message: "Please check Console for logs"
            )
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
                "Recompose",
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
                "Reconstruct an Icon Composer document for any app icon.",
                textStyle: .body,
                color: .secondaryLabelColor
            )
            description.alignment = .left
            description.maximumNumberOfLines = 2
            description.lineBreakMode = .byWordWrapping
            description.preferredMaxLayoutWidth = Layout.introBodyWidth
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
            stack.spacing = Layout.introSpacing
            stack.translatesAutoresizingMaskIntoConstraints = false
            leftPaneView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(
                    equalTo: leftPaneView.leadingAnchor,
                    constant: Layout.introLeading
                ),
                stack.centerYAnchor.constraint(
                    equalTo: leftPaneView.centerYAnchor,
                    constant: Layout.introCenterYOffset
                ),
                description.widthAnchor.constraint(equalToConstant: Layout.introBodyWidth)
            ])
            leftContentView = stack
        case .singleIcon(let name):
            installSuccessContent(makeSuccessContent(assetName: name, names: nil))
        case .multipleIcons(let names):
            let selectedName = selectedIconName ?? names[0]
            installSuccessContent(makeSuccessContent(assetName: selectedName, names: names))
        default:
            leftContentView = nil
        }
    }

    private func installSuccessContent(_ content: NSView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        leftPaneView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(
                equalTo: leftPaneView.leadingAnchor,
                constant: Layout.successLeading
            ),
            content.centerYAnchor.constraint(
                equalTo: leftPaneView.centerYAnchor,
                constant: Layout.successCenterYOffset
            )
        ])
        leftContentView = content
    }

    private func makeSuccessContent(assetName: String, names: [String]?) -> NSView {
        let status = makeStatusView(
            names == nil ? "Icon identified" : "Multiple icons identified"
        )

        let title = makePreferredLabel(
            "Assets.car",
            textStyle: .largeTitle,
            emphasized: true,
            color: .labelColor
        )
        title.alignment = .left
        let textT = NSMutableAttributedString(attributedString: title.attributedStringValue)
        textT.addAttribute(
            .kern,
            value: Typography.headlineKerning,
            range: NSRange(location: 0, length: textT.length)
        )
        title.attributedStringValue = textT

        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = Layout.successDetailSpacing

        if let names {
            let selectionRow = makeAssetSelectionRow(names: names)
            details.addArrangedSubview(selectionRow)
            details.setCustomSpacing(Layout.assetSelectionBottomSpacing, after: selectionRow)
        } else {
            details.addArrangedSubview(
                makeDetailLabel(prefix: "Identified asset:", value: assetName)
            )
        }

        let generation = session?.minimumGenerations[assetName]
        details.addArrangedSubview(
            makeDetailLabel(
                prefix: "Compiled with:",
                value: generation.map { "Xcode \($0)" } ?? "—"
            )
        )
        details.addArrangedSubview(makeDocumentVersionRow(generation: generation))

        let titleAndDetails = NSStackView(views: [title, details])
        titleAndDetails.orientation = .vertical
        titleAndDetails.alignment = .leading
        titleAndDetails.spacing = Layout.successTitleSpacing

        let information = NSStackView(views: [status, titleAndDetails])
        information.orientation = .vertical
        information.alignment = .leading
        information.spacing = Layout.successSectionSpacing

        let saveButton = NSButton(title: "Save Icon", target: self, action: #selector(saveIcon))
        configureButton(saveButton)
        saveButton.keyEquivalent = "\r"
        saveButton.isEnabled = outputs[assetName] != nil

        let content = NSStackView(views: [information, saveButton])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = Layout.successButtonSpacing
        return content
    }

    private func makeStatusView(_ text: String) -> NSView {
        let symbol = makeSymbolView(
            named: "checkmark.circle",
            pointSize: 13,
            weight: .semibold,
            color: .systemGreen,
            accessibilityDescription: text
        )
        let label = makePreferredLabel(
            text,
            textStyle: .body,
            color: .systemGreen
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
        row.spacing = 3
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
        row.spacing = Layout.assetLabelToDropdownSpacing
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
            pointSize: 13,
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
            helpContainer.widthAnchor.constraint(equalToConstant: Layout.documentHelpSize),
            helpContainer.heightAnchor.constraint(equalToConstant: Layout.documentHelpSize),
            help.widthAnchor.constraint(equalToConstant: Layout.documentHelpSize),
            help.heightAnchor.constraint(equalToConstant: Layout.documentHelpSize),
            help.centerXAnchor.constraint(equalTo: helpContainer.centerXAnchor),
            help.centerYAnchor.constraint(
                equalTo: helpContainer.centerYAnchor,
                constant: Layout.documentHelpYOffset
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

        let placeholder = NSBox()
        placeholder.boxType = .custom
        placeholder.borderWidth = 0
        placeholder.fillColor = .tertiarySystemFill

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(goBack))
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .large

        let stack = NSStackView(views: [placeholder, clearButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Layout.previewButtonSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            placeholder.widthAnchor.constraint(equalToConstant: Layout.previewSize),
            placeholder.heightAnchor.constraint(equalToConstant: Layout.previewSize),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
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
            pointSize: 112,
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
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: 144),
            symbol.heightAnchor.constraint(equalToConstant: 144),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -12)
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
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            spinner.widthAnchor.constraint(equalToConstant: 32),
            spinner.heightAnchor.constraint(equalToConstant: 32),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -8)
        ])
        return container
    }

    private func makeResultView(
        symbolName: String,
        symbolColor: NSColor,
        title: String,
        message: String
    ) -> NSView {
        let container = NSView()
        let symbol = makeSymbolView(
            named: symbolName,
            pointSize: 72,
            weight: .thin,
            color: symbolColor,
            accessibilityDescription: title
        )
        let titleLabel = makeLabel(title, size: 17, weight: .semibold, color: .labelColor)
        let messageLabel = makeLabel(message, size: 13, weight: .regular, color: .secondaryLabelColor)
        messageLabel.maximumNumberOfLines = 2

        let backButton = NSButton(title: "Back", target: self, action: #selector(goBack))
        configureButton(backButton)

        let stack = NSStackView(views: [symbol, titleLabel, messageLabel, backButton])
        configureResultStack(stack, messageView: messageLabel, in: container)
        constrainResultSymbol(symbol)
        return container
    }

    private func configureResultStack(
        _ stack: NSStackView,
        messageView: NSView,
        in container: NSView
    ) {
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.setCustomSpacing(24, after: messageView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -8)
        ])
    }

    private func constrainResultSymbol(_ symbol: NSImageView) {
        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: 86),
            symbol.heightAnchor.constraint(equalToConstant: 86)
        ])
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
        selectedIconName = nil
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

    @objc private func showDocumentVersionHelp(_ sender: NSButton) {
        if let documentVersionPopover, documentVersionPopover.isShown {
            documentVersionPopover.close()
            self.documentVersionPopover = nil
            return
        }

        let explanation = NSTextField(
            wrappingLabelWithString: "Recompose uses the earliest Icon Composer document version that can represent all of this icon’s features. This prevents omitted material properties from falling back to their default values, which could alter the intended appearance."
//            wrappingLabelWithString: "The earliest Icon Composer document version that can represent all of this icon’s features."
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
