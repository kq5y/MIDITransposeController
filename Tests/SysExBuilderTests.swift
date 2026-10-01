import XCTest
@testable import MIDITransposeController

final class SysExBuilderTests: XCTestCase {
    private let mct = DevicePreset.masterCoarseTuning.sysexTemplate

    func testMasterCoarseTuningTemplate() throws {
        XCTAssertEqual(try SysExBuilder.build(mct, value: 0), [0xF0, 0x7F, 0x7F, 0x04, 0x04, 0x00, 0x40, 0xF7])
        XCTAssertEqual(try SysExBuilder.build(mct, value: 4), [0xF0, 0x7F, 0x7F, 0x04, 0x04, 0x00, 0x44, 0xF7])
        XCTAssertEqual(try SysExBuilder.build(mct, value: -1), [0xF0, 0x7F, 0x7F, 0x04, 0x04, 0x00, 0x3F, 0xF7])
        XCTAssertEqual(try SysExBuilder.build(mct, value: 12), [0xF0, 0x7F, 0x7F, 0x04, 0x04, 0x00, 0x4C, 0xF7])
        XCTAssertEqual(try SysExBuilder.build(mct, value: -12), [0xF0, 0x7F, 0x7F, 0x04, 0x04, 0x00, 0x34, 0xF7])
    }

    func testOffset64() throws {
        XCTAssertEqual(try SysExBuilder.build("F0 {v:offset64} F7", value: 4), [0xF0, 0x44, 0xF7])
        XCTAssertEqual(try SysExBuilder.build("F0 {v:offset64} F7", value: -3), [0xF0, 0x3D, 0xF7])
    }

    func testSigned7() throws {
        XCTAssertEqual(try SysExBuilder.build("F0 {v:signed7} F7", value: 4), [0xF0, 0x04, 0xF7])
        XCTAssertEqual(try SysExBuilder.build("F0 {v:signed7} F7", value: -3), [0xF0, 0x7D, 0xF7])
    }

    func testNibble() throws {
        XCTAssertEqual(try SysExBuilder.build("F0 {v:nibble} F7", value: 4), [0xF0, 0x00, 0x04, 0xF7])
        XCTAssertEqual(try SysExBuilder.build("F0 {v:nibble} F7", value: -3), [0xF0, 0x0F, 0x0D, 0xF7])
    }

    func testLowercaseHexAndExtraWhitespace() throws {
        XCTAssertEqual(
            try SysExBuilder.build("  f0 7f\t7F  04 04 00 {v:offset64}\nf7 ", value: 0),
            [0xF0, 0x7F, 0x7F, 0x04, 0x04, 0x00, 0x40, 0xF7]
        )
    }

    func testHexString() {
        XCTAssertEqual(SysExBuilder.hexString([0xF0, 0x0A, 0xF7]), "F0 0A F7")
    }

    func testMissingStartByte() {
        assertError("7F {v:offset64} F7", .missingStartByte)
        assertError("", .missingStartByte)
    }

    func testMissingEndByte() {
        assertError("F0 7F {v:offset64}", .missingEndByte)
        assertError("F0", .missingEndByte)
    }

    func testDataByteTooLarge() {
        assertError("F0 7F 80 F7", .dataByteTooLarge(index: 2, byte: 0x80))
    }

    func testInvalidToken() {
        assertError("F0 7G F7", .invalidToken("7G"))
        assertError("F0 F F7", .invalidToken("F"))
        assertError("F0 {v} F7", .invalidToken("{v}"))
    }

    func testUnknownEncoding() {
        assertError("F0 {v:foo} F7", .unknownEncoding("foo"))
    }

    func testValueOutOfRange() {
        assertError("F0 {v:offset64} F7", value: 64, .valueOutOfRange(encoding: "offset64", value: 64))
        assertError("F0 {v:signed7} F7", value: -65, .valueOutOfRange(encoding: "signed7", value: -65))
        assertError("F0 {v:nibble} F7", value: 128, .valueOutOfRange(encoding: "nibble", value: 128))
    }

    func testTooLong() {
        let template = "F0 " + Array(repeating: "00", count: 255).joined(separator: " ") + " F7"
        assertError(template, .tooLong(257))
        let ok = "F0 " + Array(repeating: "00", count: 254).joined(separator: " ") + " F7"
        XCTAssertEqual(try SysExBuilder.build(ok, value: 0).count, 256)
    }

    private func assertError(
        _ template: String, value: Int = 0, _ expected: SysExBuildError,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertThrowsError(try SysExBuilder.build(template, value: value), file: file, line: line) {
            XCTAssertEqual($0 as? SysExBuildError, expected, file: file, line: line)
        }
    }
}
