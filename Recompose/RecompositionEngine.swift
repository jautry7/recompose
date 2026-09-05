import Foundation

struct RecompositionSession: Sendable {
    let id: UUID
    let iconNames: [String]
    let catalogURL: URL
    let workspaceURL: URL
}

struct RecompositionOutput: Sendable {
    let assetName: String
    let iconURL: URL
}

enum RecompositionEngine {
    private nonisolated struct IconStackRecord: Decodable {
        let name: String
    }

    private nonisolated struct ListResponse: Decodable {
        let formatVersion: Int
        let iconStacks: [IconStackRecord]
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

    nonisolated static func inspect(catalogURL: URL) throws -> RecompositionSession {
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
            let names = response.iconStacks.map(\.name)
            guard response.formatVersion == 1,
                  names.allSatisfy({ !$0.isEmpty }),
                  Set(names).count == names.count else {
                throw EngineError.invalidListResponse
            }

            return RecompositionSession(
                id: UUID(),
                iconNames: names,
                catalogURL: stagedCatalogURL,
                workspaceURL: workspaceURL
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

        return RecompositionOutput(assetName: assetName, iconURL: iconURL)
    }

    nonisolated static func remove(_ session: RecompositionSession) {
        try? FileManager.default.removeItem(at: session.workspaceURL)
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
