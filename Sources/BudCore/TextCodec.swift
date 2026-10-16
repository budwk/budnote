import Foundation
import CoreFoundation

public struct TextCodec {
    public var encoding: String.Encoding
    public var bom: Data
    private static var isEnglish: Bool {
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["BUDNOTE_TEST_DEFAULTS_SUITE"],
           let defaults = UserDefaults(suiteName: suite) {
            return defaults.integer(forKey: "language") == 1
        }
        #endif
        return UserDefaults.standard.integer(forKey: "language") == 1
    }
    public var name: String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .utf16BigEndian: return "UTF-16 BE"
        case .utf32LittleEndian: return "UTF-32 LE"
        case .utf32BigEndian: return "UTF-32 BE"
        case .gb_18030_2000: return "GB18030"
        default: return Self.isEnglish ? "Text" : "文本"
        }
    }
    public init(encoding: String.Encoding = .utf8, bom: Data = Data()) {
        self.encoding = encoding; self.bom = bom
    }
    public static func decode(_ data: Data) throws -> (String, TextCodec) {
        let signatures: [(Data, String.Encoding)] = [
            (Data([0xff,0xfe,0,0]), .utf32LittleEndian), (Data([0,0,0xfe,0xff]), .utf32BigEndian),
            (Data([0xef,0xbb,0xbf]), .utf8), (Data([0xff,0xfe]), .utf16LittleEndian),
            (Data([0xfe,0xff]), .utf16BigEndian)]
        for (bom, encoding) in signatures where data.starts(with: bom) {
            let payload = Data(data.dropFirst(bom.count))
            let unit = encoding == .utf32LittleEndian || encoding == .utf32BigEndian ? 4 : encoding == .utf8 ? 1 : 2
            guard payload.count % unit == 0, let text = String(data: payload, encoding: encoding),
                  text.data(using: encoding, allowLossyConversion: false) == payload else { throw CodecError.invalidEncoding }
            return (text, TextCodec(encoding: encoding, bom: bom))
        }
        // Never treat NUL-containing binary files as editable text.
        guard !data.contains(0) else { throw CodecError.binary }
        for encoding in [String.Encoding.utf8, .gb_18030_2000] {
            if let text = String(data: data, encoding: encoding), text.data(using: encoding, allowLossyConversion: false) == data {
                let controls = text.unicodeScalars.filter { $0.value < 32 && ![9,10,12,13].contains($0.value) }
                guard controls.isEmpty else { throw CodecError.binary }
                return (text, TextCodec(encoding: encoding))
            }
        }
        throw CodecError.invalidEncoding
    }
    public func encode(_ text: String) throws -> Data {
        guard let data = text.data(using: encoding, allowLossyConversion: false) else { throw CodecError.unrepresentable }
        return bom + data
    }
    public enum CodecError: LocalizedError {
        case binary, invalidEncoding, unrepresentable
        public var errorDescription: String? {
            let en = TextCodec.isEnglish
            switch self {
            case .binary:
                return en ? "This file contains binary data and cannot be safely edited as plain text." : "此文件包含二进制数据，无法作为纯文本安全编辑。"
            case .invalidEncoding:
                return en ? "Unrecognized text encoding. Please convert the file to UTF-8, UTF-16, or GB18030 first." : "无法识别文本编码。请先将文件转换为 UTF-8、UTF-16 或 GB18030。"
            case .unrepresentable:
                return en ? "The current encoding cannot represent these characters. Convert to UTF-8 in the Format menu before saving." : "当前编码无法保存这些字符。请在“格式”菜单中转换为 UTF-8 后保存。"
            }
        }
    }
}
public extension String.Encoding {
    static let gb_18030_2000 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
}
