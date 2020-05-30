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
        try super.init(
            path: path,
            cachePath: cachePath,
            version: version,
            prefix: """
            import Foundation
            import RuntimeCode

            let context = ProcessInfo().context!
            let types = context.types
            let functions = context.functions
            let type = context.types.typesByName
            let argument = context.argument
            """,
            runtimeFiles: sourceryRuntimeFiles
        )
    }
}
