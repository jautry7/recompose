import AppKit
import UniformTypeIdentifiers

final class MainViewController: NSViewController, DropZoneViewDelegate {
    private enum State: Equatable {
        case resting
        case hovering
        case processing
        case success
        case failure
    }

    private let dropZoneView = DropZoneView()
    private var contentView: NSView?
    private var restingSymbolView: NSImageView?
    private var output: RecompositionOutput?
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
        if let output {
            RecompositionEngine.remove(output)
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
        render(.processing)
        let didAccess = catalogURL.startAccessingSecurityScopedResource()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try RecompositionEngine.recompose(catalogURL: catalogURL) }
            if didAccess {
                catalogURL.stopAccessingSecurityScopedResource()
            }

            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let output):
                    self.output = output
                    self.render(.success)
                case .failure(let error):
                    NSLog("Recomposition failed: %@", error.localizedDescription)
                    self.render(.failure)
                }
            }
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
        case .success:
            replacement = makeResultView(
                symbolName: "checkmark.circle",
                symbolColor: .systemGreen,
                title: "Icon recomposed",
                message: "Identified asset name: AppIcon",
                showsSaveButton: true
            )
        case .failure:
            replacement = makeResultView(
                symbolName: "xmark.circle",
                symbolColor: .systemRed,
                title: "Could not recompose icon",
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

        let backButton = NSButton(title: "Back", target: self, action: #selector(goBack))
        configureButton(backButton)
        var buttons = [backButton]

        if showsSaveButton {
            let saveButton = NSButton(title: "Save Icon", target: self, action: #selector(saveIcon))
            configureButton(saveButton)
            saveButton.keyEquivalent = "\r"
            buttons.append(saveButton)
        }

        let buttonRow = NSStackView(views: buttons)
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let stack = NSStackView(views: [symbol, titleLabel, messageLabel, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.setCustomSpacing(24, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            symbol.widthAnchor.constraint(equalToConstant: 86),
            symbol.heightAnchor.constraint(equalToConstant: 86),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -8)
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

    @objc private func goBack() {
        if let output {
            RecompositionEngine.remove(output)
            self.output = nil
        }
        render(.resting)
    }

    @objc private func saveIcon() {
        guard let output, let window = view.window else { return }

        let panel = NSSavePanel()
        panel.title = "Save Reconstructed Icon"
        panel.nameFieldStringValue = "AppIcon-recomposed.icon"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if let iconType = UTType(filenameExtension: "icon", conformingTo: .package) {
            panel.allowedContentTypes = [iconType]
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let destinationURL = panel.url else { return }
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: output.iconURL, to: destinationURL)
            } catch {
                NSLog("Saving recomposed icon failed: %@", error.localizedDescription)
                self?.render(.failure)
            }
        }
    }
}
