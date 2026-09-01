import Foundation

struct RecompositionOutput: Sendable {
    let iconURL: URL
    let workspaceURL: URL
}

enum RecompositionEngine {
    private enum EngineError: LocalizedError {
        case missingHelper(String)
        case helperFailed(name: String, status: Int32, diagnostics: String)
        case missingOutput

        var errorDescription: String? {
            switch self {
            case .missingHelper(let name):
                return "The bundled helper \(name) could not be found."
            case .helperFailed(let name, let status, let diagnostics):
                let suffix = diagnostics.isEmpty ? "" : " \(diagnostics)"
                return "\(name) exited with status \(status).\(suffix)"
            case .missingOutput:
                return "The pipeline completed without producing an icon."
            }
        }
    }

    nonisolated static func recompose(catalogURL: URL) throws -> RecompositionOutput {
        let fileManager = FileManager.default
        let workspaceURL = fileManager.temporaryDirectory
            .appendingPathComponent("recompose-\(UUID().uuidString)", isDirectory: true)
        let extractionURL = workspaceURL.appendingPathComponent("extracted", isDirectory: true)
        let iconURL = workspaceURL.appendingPathComponent("AppIcon.icon", isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: workspaceURL,
                withIntermediateDirectories: true
            )

            try runHelper(
                named: "coreui-icon-extract",
                arguments: [catalogURL.path, "AppIcon", extractionURL.path]
            )
            try runHelper(
                named: "icon-recreate",
                arguments: [
                    extractionURL.appendingPathComponent("manifest.json").path,
                    extractionURL.appendingPathComponent("Assets", isDirectory: true).path,
                    iconURL.path
                ]
            )

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: iconURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw EngineError.missingOutput
            }

            return RecompositionOutput(iconURL: iconURL, workspaceURL: workspaceURL)
        } catch {
            try? fileManager.removeItem(at: workspaceURL)
            throw error
        }
    }

    nonisolated static func remove(_ output: RecompositionOutput) {
        try? FileManager.default.removeItem(at: output.workspaceURL)
    }

    private nonisolated static func runHelper(named name: String, arguments: [String]) throws {
        guard let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() else {
            throw EngineError.missingHelper(name)
        }
        let executableURL = executableDirectory.appendingPathComponent(name)
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw EngineError.missingHelper(name)
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
            NSLog("[%@] %@", name, output)
        }
        if !diagnostics.isEmpty {
            NSLog("[%@] %@", name, diagnostics)
        }

        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw EngineError.helperFailed(
                name: name,
                status: process.terminationStatus,
                diagnostics: diagnostics
            )
        }
    }
}
