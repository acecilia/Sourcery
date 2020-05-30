import Foundation
import CommonCrypto

extension Data {
    public func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { (pointer) -> Void in
            _ = CC_SHA256(pointer.baseAddress, CC_LONG(pointer.count), &hash)
        }
        return Data(hash)
    }
}
