import Foundation

enum SysExBuildError: Error, Equatable {
    case invalidToken(String)
    case unknownEncoding(String)
    case valueOutOfRange(encoding: String, value: Int)
    case missingStartByte
    case missingEndByte
    case dataByteTooLarge(index: Int, byte: UInt8)
    case tooLong(Int)
}

extension SysExBuildError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidToken(let token): "不正なトークン: \(token)"
        case .unknownEncoding(let enc): "未知のエンコード: \(enc)"
        case .valueOutOfRange(let enc, let value): "値 \(value) は \(enc) の範囲外です"
        case .missingStartByte: "先頭が F0 ではありません"
        case .missingEndByte: "末尾が F7 ではありません"
        case .dataByteTooLarge(let index, let byte):
            String(format: "%d バイト目 (0x%02X) が 0x80 以上です", index, byte)
        case .tooLong(let count): "長すぎます (\(count) バイト > 256)"
        }
    }
}

/// Expands a whitespace-separated template of hex bytes and `{v:<encoding>}` tokens.
enum SysExBuilder {
    static let maxLength = 256

    static func build(_ template: String, value: Int) throws -> [UInt8] {
        var bytes: [UInt8] = []
        for token in template.split(whereSeparator: \.isWhitespace).map(String.init) {
            if let byte = parseByte(token) {
                bytes.append(byte)
            } else if let encoding = parseValueToken(token) {
                bytes += try encode(value, as: encoding)
            } else {
                throw SysExBuildError.invalidToken(token)
            }
        }
        try validate(bytes)
        return bytes
    }

    static func hexString(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private static func parseByte(_ token: String) -> UInt8? {
        guard token.count == 2, token.allSatisfy(\.isHexDigit) else { return nil }
        return UInt8(token, radix: 16)
    }

    private static func parseValueToken(_ token: String) -> String? {
        guard token.hasPrefix("{v:"), token.hasSuffix("}"), token.count > 4 else { return nil }
        return String(token.dropFirst(3).dropLast())
    }

    private static func encode(_ value: Int, as encoding: String) throws -> [UInt8] {
        func check(_ range: ClosedRange<Int>) throws {
            guard range.contains(value) else {
                throw SysExBuildError.valueOutOfRange(encoding: encoding, value: value)
            }
        }
        switch encoding {
        case "offset64":
            try check(-64...63)
            return [UInt8(64 + value)]
        case "signed7":
            try check(-64...63)
            return [UInt8(value & 0x7F)]
        case "nibble":
            try check(-128...127)
            let byte = UInt8(bitPattern: Int8(value))
            return [byte >> 4, byte & 0x0F]
        default:
            throw SysExBuildError.unknownEncoding(encoding)
        }
    }

    private static func validate(_ bytes: [UInt8]) throws {
        guard bytes.first == 0xF0 else { throw SysExBuildError.missingStartByte }
        guard bytes.count >= 2, bytes.last == 0xF7 else { throw SysExBuildError.missingEndByte }
        for index in 1..<(bytes.count - 1) where bytes[index] >= 0x80 {
            throw SysExBuildError.dataByteTooLarge(index: index, byte: bytes[index])
        }
        guard bytes.count <= maxLength else { throw SysExBuildError.tooLong(bytes.count) }
    }
}
