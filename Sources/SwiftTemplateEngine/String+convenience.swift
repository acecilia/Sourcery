import Foundation

// swiftlint:disable:next force_try
private let newlines = try! NSRegularExpression(pattern: "\\n\\r|\\r\\n|\\r|\\n", options: [])

extension String {
    /// :nodoc:
    @discardableResult
    mutating func trimPrefix(_ prefix: String) -> Bool {
        guard hasPrefix(prefix) else { return false }
        self = String(self.suffix(self.count - prefix.count))
        return true
    }

    /// :nodoc:
    @discardableResult
    mutating func trimSuffix(_ suffix: String) -> Bool {
        guard hasSuffix(suffix) else { return false }
        self = String(self.prefix(self.count - suffix.count))
        return true
    }

    func bridge() -> NSString {
        #if os(Linux)
            return NSString(string: self)
        #else
            return self as NSString
        #endif
    }

    var numberOfLineSeparators: Int {
        return newlines.matches(in: self, options: [], range: NSRange(location: 0, length: self.count)).count
    }

    var stringEncoded: String {
        return self.unicodeScalars.map { x -> String in
            return x.escaped(asASCII: true)
            }.joined(separator: "")
    }

    func sha256() -> String? {
        guard let data = data(using: String.Encoding.utf8) else { return nil }
        let rc = data.sha256().base64EncodedString(options: [])
        return rc
    }
}

extension NSString {
    /// :nodoc:
    var entireRange: NSRange {
        return NSRange(location: 0, length: self.length)
    }
}

extension String: Error { }
