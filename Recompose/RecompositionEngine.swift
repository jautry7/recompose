import Foundation

enum IconPreviewAppearance: String, CaseIterable, Sendable {
    case standard = "default"
    case dark
    case tinted

    var displayName: String {
        switch self {
        case .standard: "Default"
        case .dark: "Dark"
        case .tinted: "Tinted"
        }
    }
}

struct RecompositionSession: Sendable {
    let id: UUID
    let iconNames: [String]
    let minimumGenerations: [String: Int]
    let compilerVersion: String?
    let catalogURL: URL
    let workspaceURL: URL
    let sourceDisplayName: String
    let hasTraditionalBitmapIcon: Bool
}

struct RecompositionOutput: Sendable {
    let assetName: String
    let minimumGeneration: Int
    let iconURL: URL
    let previewURLs: [IconPreviewAppearance: URL]
}

enum RecompositionEngine {
    private nonisolated struct IconStackRecord: Decodable {
        let name: String
        let minimumGeneration: Int
    }

    private nonisolated struct ListResponse: Decodable {
        let formatVersion: Int
        let iconStacks: [IconStackRecord]
        let compilerVersion: String?
        let traditionalBitmapIcons: [String]?
    }

    private enum EngineError: LocalizedError {
        case missingHelper
        case helperFailed(status: Int32, diagnostics: String)
        case invalidListResponse
        case missingOutput

        var errorDescription: String? {
            switch self {
            case .missingHelper:
                return "The bundled recompose command-line tool could not be found."
            case .helperFailed(let status, let diagnostics):
                let suffix = diagnostics.isEmpty ? "" : " \(diagnostics)"
                return "recompose exited with status \(status).\(suffix)"
            case .invalidListResponse:
                return "The command-line tool returned an invalid icon-stack list."
            case .missingOutput:
                return "The pipeline completed without producing an icon."
            }
        }
    }

    nonisolated static func inspect(
        catalogURL: URL,
        sourceDisplayName: String,
        preferredIconName: String?
    ) throws -> RecompositionSession {
        let fileManager = FileManager.default
        let workspaceURL = fileManager.temporaryDirectory
            .appendingPathComponent("recompose-\(UUID().uuidString)", isDirectory: true)
        let stagedCatalogURL = workspaceURL.appendingPathComponent("Assets.car")

        do {
            try fileManager.createDirectory(
                at: workspaceURL,
                withIntermediateDirectories: true
            )
            try fileManager.copyItem(at: catalogURL, to: stagedCatalogURL)

            let data = try runCLI(arguments: ["list", stagedCatalogURL.path, "--json"])
            let response = try JSONDecoder().decode(ListResponse.self, from: data)
            let names = orderedIconNames(
                response.iconStacks.map(\.name),
                preferredIconName: preferredIconName
            )
            let minimumGenerations = Dictionary(
                uniqueKeysWithValues: response.iconStacks.map { ($0.name, $0.minimumGeneration) }
            )
            let traditionalBitmapIcons = response.traditionalBitmapIcons ?? []
            guard response.formatVersion == 1,
                  names.allSatisfy({ !$0.isEmpty }),
                  Set(names).count == names.count,
                  response.iconStacks.allSatisfy({ $0.minimumGeneration == 26 || $0.minimumGeneration == 27 }),
                  traditionalBitmapIcons.allSatisfy({ !$0.isEmpty }),
                  Set(traditionalBitmapIcons).count == traditionalBitmapIcons.count else {
                throw EngineError.invalidListResponse
            }

            return RecompositionSession(
                id: UUID(),
                iconNames: names,
                minimumGenerations: minimumGenerations,
                compilerVersion: response.compilerVersion,
                catalogURL: stagedCatalogURL,
                workspaceURL: workspaceURL,
                sourceDisplayName: sourceDisplayName,
                hasTraditionalBitmapIcon: !traditionalBitmapIcons.isEmpty
            )
        } catch {
            try? fileManager.removeItem(at: workspaceURL)
            throw error
        }
    }

    nonisolated static func recompose(
        session: RecompositionSession,
        assetName: String
    ) throws -> RecompositionOutput {
        guard session.iconNames.contains(assetName) else {
            throw EngineError.invalidListResponse
        }
        guard let minimumGeneration = session.minimumGenerations[assetName] else {
            throw EngineError.invalidListResponse
        }

        let fileManager = FileManager.default
        let outputDirectory = session.workspaceURL.appendingPathComponent("outputs", isDirectory: true)
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let iconURL = outputDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("icon")

        _ = try runCLI(arguments: [
            session.catalogURL.path,
            "--asset", assetName,
            "--output", iconURL.path
        ])

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: iconURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw EngineError.missingOutput
        }

        var previewURLs: [IconPreviewAppearance: URL] = [:]
        for appearance in IconPreviewAppearance.allCases {
            let requestedPreviewURL = outputDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("png")
            do {
                _ = try runCLI(arguments: [
                    "_preview", session.catalogURL.path,
                    "--asset", assetName,
                    "--appearance", appearance.rawValue,
                    "--output", requestedPreviewURL.path
                ])
                if fileManager.fileExists(atPath: requestedPreviewURL.path) {
                    previewURLs[appearance] = requestedPreviewURL
                }
            } catch {
                NSLog(
                    "Rendering %@ CAR preview for %@ failed: %@",
                    appearance.rawValue,
                    assetName,
                    error.localizedDescription
                )
            }
        }

        return RecompositionOutput(
            assetName: assetName,
            minimumGeneration: minimumGeneration,
            iconURL: iconURL,
            previewURLs: previewURLs
        )
    }

    nonisolated static func remove(_ session: RecompositionSession) {
        try? FileManager.default.removeItem(at: session.workspaceURL)
    }

    private nonisolated static func orderedIconNames(
        _ names: [String],
        preferredIconName: String?
    ) -> [String] {
        var orderedNames = names.sorted { left, right in
            let insensitive = left.caseInsensitiveCompare(right)
            return insensitive == .orderedSame
                ? left.compare(right) == .orderedAscending
                : insensitive == .orderedAscending
        }
        guard let preferredIconName,
              let preferredIndex = orderedNames.firstIndex(of: preferredIconName) else {
            return orderedNames
        }
        orderedNames.insert(orderedNames.remove(at: preferredIndex), at: 0)
        return orderedNames
    }

    private nonisolated static func runCLI(arguments: [String]) throws -> Data {
        let executableURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("recompose")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw EngineError.missingHelper
        }

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let diagnostics = String(decoding: errorData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !output.isEmpty {
            NSLog("[recompose] %@", output)
        }
        if !diagnostics.isEmpty {
            NSLog("[recompose] %@", diagnostics)
        }

        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw EngineError.helperFailed(
                status: process.terminationStatus,
                diagnostics: diagnostics
            )
        }
        return outputData
    }
}
