//
//  SwiftTemplate.swift
//  Sourcery
//
//  Created by Krunoslav Zaher on 12/30/16.
//  Copyright © 2016 Pixle. All rights reserved.
//

import Foundation
import PathKit
import SourceryUtils

private enum Delimiters {
    static let open = "<%"
    static let close = "%>"
}

private enum Command {
    case includeFile(Path)
    case output(String)
    case controlFlow(String)
    case outputEncoded(String)
}

open class SwiftTemplate {
    public let sourcePath: Path
    public let code: String
    public let includedFiles: [Path]
    public let buildDir: Path
    public let runtimeFiles: [File]
    public let manifestCode: String
    public let cachePath: Path?

    public init(
        path: Path,
        prefix: String,
        runtimeFiles: [File],
        manifestCode: String,
        buildDir: Path,
        cachePath: Path?
    ) throws {
        self.sourcePath = path
        self.buildDir = buildDir
        self.runtimeFiles = runtimeFiles
        self.manifestCode = manifestCode
        self.cachePath = cachePath
        (self.code, self.includedFiles) = try Self.parse(sourcePath: path, prefix: prefix)
    }

    public func render<T: Codable>(_ context: T) throws -> String {
        try render(context) {
            try JSONEncoder().encode($0)
        }
    }

    public func render<T: NSCoding>(_ context: T) throws -> String {
        try render(context) {
            NSKeyedArchiver.archivedData(withRootObject: $0)
        }
    }

    private func render<T>(_ context: T, encode: (T) throws -> Data) throws -> String {
        let binaryPath: Path

        if let cachePath = cachePath,
            let hash = code.sha256(),
            let hashPath = hash.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) {

            binaryPath = cachePath + hashPath
            if !binaryPath.exists {
                try? cachePath.delete() // clear old cache
                try cachePath.mkdir()
                try build().move(binaryPath)
            }
        } else {
            try binaryPath = build()
        }

        let serializedContextPath = buildDir + "context.bin"
        let data = try encode(context)
        if !buildDir.exists {
            try buildDir.mkpath()
        }
        try serializedContextPath.write(data)

        let result = Process.runCommand(
            path: binaryPath.description,
            arguments: [serializedContextPath.description]
        )
        if !result.error.isEmpty {
            throw """
            Error rendering \(sourcePath):
            Error: \(result.error)
            Output: \(result.output)
            """
        }
        return result.output
    }

    private static func parse(sourcePath: Path, prefix: String) throws -> (String, [Path]) {
        let commands = try Self.parseCommands(in: sourcePath)

        var includedFiles: [Path] = []
        var outputFile = [String]()
        for command in commands {
            switch command {
            case let .includeFile(path):
                includedFiles.append(path)
            case let .output(code):
                outputFile.append("print(\"\\(" + code + ")\", terminator: \"\");")
            case let .controlFlow(code):
                outputFile.append("\(code)")
            case let .outputEncoded(code):
                if !code.isEmpty {
                    outputFile.append(("print(\"") + code.stringEncoded + "\", terminator: \"\");")
                }
            }
        }

        let contents = outputFile.joined(separator: "\n")
        let code = """
        \(prefix)

        \(contents)
        """

        return (code, includedFiles)
    }

    private static func parseCommands(in sourcePath: Path, includeStack: [Path] = []) throws -> [Command] {
        let templateContent = try "<%%>" + sourcePath.read()

        let components = templateContent.components(separatedBy: Delimiters.open)

        var processedComponents = [String]()
        var commands = [Command]()

        let currentLineNumber = {
            // the following +1 is to transform a line count (starting from 0) to a line number (starting from 1)
            return processedComponents.joined(separator: "").numberOfLineSeparators + 1
        }

        for component in components.suffix(from: 1) {
            guard let endIndex = component.range(of: Delimiters.close) else {
                throw "\(sourcePath):\(currentLineNumber()) Error while parsing template. Unmatched <%"
            }

            var code = String(component[..<endIndex.lowerBound])
            let shouldTrimTrailingNewLines = code.trimSuffix("-")
            let shouldTrimLeadingWhitespaces = code.trimPrefix("_")
            let shouldTrimTrailingWhitespaces = code.trimSuffix("_")

            // string after closing tag
            var encodedPart = String(component[endIndex.upperBound...])
            if shouldTrimTrailingNewLines {
                // we trim only new line caused by script tag, not all of leading new lines in string after tag
                encodedPart = encodedPart.replacingOccurrences(of: "^\\n{1}", with: "", options: .regularExpression, range: nil)
            }
            if shouldTrimTrailingWhitespaces {
                // trim all leading whitespaces in string after tag
                encodedPart = encodedPart.replacingOccurrences(of: "^[\\h\\t]*", with: "", options: .regularExpression, range: nil)
            }
            if shouldTrimLeadingWhitespaces {
                if case .outputEncoded(let code)? = commands.last {
                    // trim all trailing white spaces in previously enqued code string
                    let trimmed = code.replacingOccurrences(of: "[\\h\\t]*$", with: "", options: .regularExpression, range: nil)
                    _ = commands.popLast()
                    commands.append(.outputEncoded(trimmed))
                }
            }

            func parseInclude(command: String, defaultExtension: String) -> Path? {
                let regex = try? NSRegularExpression(pattern: "\(command)\\(\"([^\"]*)\"\\)", options: [])
                let match = regex?.firstMatch(in: code, options: [], range: code.bridge().entireRange)
                guard let includedFile = match.map({ code.bridge().substring(with: $0.range(at: 1)) }) else {
                    return nil
                }
                let includePath = Path(components: [sourcePath.parent().string, includedFile])
                // The template extension may be omitted, so try to read again by adding it if a template was not found
                if !includePath.exists, includePath.extension != "\(defaultExtension)" {
                    return Path(includePath.string + ".\(defaultExtension)")
                } else {
                    return includePath
                }
            }

            if code.trimPrefix("-") {
                if let includePath = parseInclude(command: "includeFile", defaultExtension: "swift") {
                    commands.append(.includeFile(includePath))
                } else if let includePath = parseInclude(command: "include", defaultExtension: "swifttemplate") {
                    // Check for include cycles to prevent stack overflow and show a more user friendly error
                    if includeStack.contains(includePath) {
                        throw "\(sourcePath):\(currentLineNumber()) Error: Include cycle detected for \(includePath). Check your include statements so that templates do not include each other."
                    }
                    let includedCommands = try Self.parseCommands(in: includePath, includeStack: includeStack + [includePath])
                    commands.append(contentsOf: includedCommands)
                } else {
                    throw "\(sourcePath):\(currentLineNumber()) Error while parsing template. Invalid include tag format '\(code)'"
                }
            } else if code.trimPrefix("=") {
                commands.append(.output(code))
            } else {
                if !code.hasPrefix("#") && !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    commands.append(.controlFlow(code))
                }
            }

            if !encodedPart.isEmpty {
                commands.append(.outputEncoded(encodedPart))
            }
            processedComponents.append(component)
        }

        return commands
    }

    private func build() throws -> Path {
        let sourcesDir = buildDir + Path("Sources")
        let templateFilesDir = sourcesDir + Path("SwiftTemplate")
        let mainFile = templateFilesDir + Path("main.swift")
        let manifestFile = buildDir + Path("Package.swift")

        try sourcesDir.mkpath()
        try? templateFilesDir.delete()
        try templateFilesDir.mkpath()

        try copyRuntimePackage(to: sourcesDir)
        try manifestFile.write(manifestCode)
        try mainFile.write(code)

        let binaryFile = buildDir + Path(".build/debug/SwiftTemplate")

        try includedFiles.forEach { includedFile in
            try includedFile.copy(templateFilesDir + Path(includedFile.lastComponent))
        }

        let arguments = [
            "xcrun",
            "swift",
            "build",
            "-Xswiftc", "-Onone",
            "-Xswiftc", "-suppress-warnings",
            "--disable-sandbox"
        ]
        let compilationResult = Process.runCommand(
            path: "/usr/bin/env",
            arguments: arguments,
            currentDirectoryPath: buildDir
        )

        if compilationResult.exitCode != 0 {
            throw """
            Error building \(buildDir):
            Error: \(compilationResult.error)
            Output: \(compilationResult.output)
            """
        }

        return binaryFile
    }

    private func copyRuntimePackage(to path: Path) throws {
        try FolderSynchronizer().sync(files: runtimeFiles, to: path + Path("RuntimeCode"))
    }
}
