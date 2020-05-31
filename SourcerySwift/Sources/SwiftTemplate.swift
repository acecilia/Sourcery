//
//  SwiftTemplate.swift
//  Sourcery
//
//  Created by Krunoslav Zaher on 12/30/16.
//  Copyright © 2016 Pixle. All rights reserved.
//

import Foundation
import PathKit
import SwiftTemplateEngine

open class SwiftTemplate: SwiftTemplateEngine.SwiftTemplate {
    public init(path: Path, cachePath: Path? = nil, version: String? = nil) throws {
        let buildDir: Path = {
            let pathComponent = "SwiftTemplate" + (version.map { "/\($0)" } ?? "")
            guard let tempDirURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(pathComponent) else {
                fatalError("Unable to get temporary path")
            }
            return Path(tempDirURL.path)
        }()

        try super.init(
            path: path,
            prefix: """
            import Foundation
            import RuntimeCode

            let context = ProcessInfo().context!
            let types = context.types
            let functions = context.functions
            let type = context.types.typesByName
            let argument = context.argument
            """,
            runtimeFiles: sourceryRuntimeFiles,
            manifestCode: """
            // swift-tools-version:4.0
            // The swift-tools-version declares the minimum version of Swift required to build this package.
            import PackageDescription
            let package = Package(
                name: "SwiftTemplate",
                products: [
                    .executable(name: "SwiftTemplate", targets: ["SwiftTemplate"])
                ],
                targets: [
                    .target(name: "RuntimeCode"),
                    .target(
                        name: "SwiftTemplate",
                        dependencies: ["RuntimeCode"]),
                ]
            )
            """,
            buildDir: buildDir,
            cachePath: cachePath
        )
    }
}
