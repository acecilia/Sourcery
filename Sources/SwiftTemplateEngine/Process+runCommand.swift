import Foundation
import PathKit

extension Process {
    static func runCommand(
        path: String,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectoryPath: Path? = nil
    ) throws -> ProcessResult {
        let task = Process()
        task.launchPath = path
        task.arguments = arguments
        task.environment = environment
        if let currentDirectoryPath = currentDirectoryPath {
            if #available(OSX 10.13, *) {
                task.currentDirectoryURL = currentDirectoryPath.url
            } else {
                task.currentDirectoryPath = currentDirectoryPath.description
            }
        }
        task.environment = ProcessInfo.processInfo.environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        let outHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        // Log.verbose(path + " " + arguments.map { "\"\($0)\"" }.joined(separator: " "))
        task.launch()

        let outputData = outHandle.readDataToEndOfFile()
        let errorData = errorHandle.readDataToEndOfFile()
        outHandle.closeFile()
        errorHandle.closeFile()

        task.waitUntilExit()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        return ProcessResult(output: output, error: error, exitCode: task.terminationStatus)
    }
}

struct ProcessResult {
    let output: String
    let error: String
    let exitCode: Int32
}
