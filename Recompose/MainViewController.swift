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
    }

    private let dropZoneView = DropZoneView()
    private var contentView: NSView?
    private var restingSymbolView: NSImageView?
    private var session: RecompositionSession?
    private var outputs: [String: RecompositionOutput] = [:]
    private var preparingNames: Set<String> = []
    private var selectedIconName: String?
    private var state: State = .resting

    override func loadView() {
        dropZoneView.delegate = self
        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        view = dropZoneView
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
                message: "This asset catalog does not appear to\ncontain an IconImageStack",
                showsSaveButton: false
            )
        case .singleIcon(let name):
            replacement = makeResultView(
                symbolName: "checkmark.circle",
                symbolColor: .systemGreen,
                title: "Icon recomposed",
                message: "Identified asset name: \(name)",
                showsSaveButton: true
            )
        case .multipleIcons(let names):
            replacement = makeMultipleIconView(names: names)
        case .failure:
            replacement = makeResultView(
                symbolName: "xmark.circle",
                symbolColor: .systemRed,
                title: "Could not process CAR file",
                message: "Please check Console for logs",
                showsSaveButton: false
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

    private func makeDropPrompt(isHovering: Bool) -> NSView {
        let container = NSView()
        let symbolName = isHovering ? "arrow.down.circle" : "square.dashed.micro"
        let symbol = makeSymbolView(
            named: symbolName,
            pointSize: 120,
            weight: .ultraLight,
            color: isHovering ? .controlAccentColor : .tertiaryLabelColor,
            accessibilityDescription: isHovering ? "Ready to drop" : "Drop zone"
        )
        let label = makeLabel(
            "Drop your Assets.car file here",
            size: 17,
            weight: .regular,
            color: isHovering ? .controlAccentColor : .secondaryLabelColor
        )

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
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -22)
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
        message: String,
        showsSaveButton: Bool
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

        let buttonRow = makeButtonRow(showsSaveButton: showsSaveButton)
        let stack = NSStackView(views: [symbol, titleLabel, messageLabel, buttonRow])
        configureResultStack(stack, messageView: messageLabel, in: container)
        constrainResultSymbol(symbol)
        return container
    }

    private func makeMultipleIconView(names: [String]) -> NSView {
        let container = NSView()
        let symbol = makeSymbolView(
            named: "checkmark.circle",
            pointSize: 72,
            weight: .thin,
            color: .systemGreen,
            accessibilityDescription: "Multiple icons identified"
        )
        let titleLabel = makeLabel(
            "Multiple icons identified",
            size: 17,
            weight: .semibold,
            color: .labelColor
        )
        let promptLabel = makeLabel(
            "Choose an asset:",
            size: 13,
            weight: .regular,
            color: .secondaryLabelColor
        )
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        // AppKit calls the UI kit's medium control size "regular".
        popup.controlSize = .regular
        popup.addItems(withTitles: names)
        popup.selectItem(withTitle: selectedIconName ?? names[0])
        popup.target = self
        popup.action = #selector(selectIcon(_:))

        let selectionRow = NSStackView(views: [promptLabel, popup])
        selectionRow.orientation = .horizontal
        selectionRow.alignment = .centerY
        selectionRow.spacing = Layout.assetLabelToDropdownSpacing

        let buttonRow = makeButtonRow(showsSaveButton: true)
        let stack = NSStackView(views: [symbol, titleLabel, selectionRow, buttonRow])
        configureResultStack(stack, messageView: selectionRow, in: container)
        constrainResultSymbol(symbol)
        return container
    }

    private func makeButtonRow(showsSaveButton: Bool) -> NSStackView {
        let backButton = NSButton(title: "Back", target: self, action: #selector(goBack))
        configureButton(backButton)
        var buttons = [backButton]

        if showsSaveButton {
            let saveButton = NSButton(title: "Save icon", target: self, action: #selector(saveIcon))
            configureButton(saveButton)
            saveButton.keyEquivalent = "\r"
            saveButton.isEnabled = selectedIconName.flatMap { outputs[$0] } != nil
            buttons.append(saveButton)
        }

        let buttonRow = NSStackView(views: buttons)
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        return buttonRow
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
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: accessibilityDescription
        ) ?? NSImage()
        let imageView = NSImageView(image: image)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: weight
        )
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
        guard let session, let name = sender.selectedItem?.title else { return }
        selectedIconName = name
        render(.multipleIcons(session.iconNames))
        prepareIcon(named: name, in: session)
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
