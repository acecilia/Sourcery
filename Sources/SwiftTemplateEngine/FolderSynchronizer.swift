import Foundation
import PathKit

struct FolderSynchronizer {
    func sync(files: [SwiftTemplate.File], to dir: Path) throws {
        if dir.exists {
            let synchronizedPaths = files.map { dir + Path($0.name) }
            try dir.children().forEach({ path in
                if synchronizedPaths.contains(path) {
                    return
                }
                try path.delete()
            })
        } else {
            try dir.mkpath()
        }
        try files.forEach { file in
            let filePath = dir + Path(file.name)
            try filePath.write(file.content)
        }
    }
}
