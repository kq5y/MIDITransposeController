import XCTest
@testable import MIDITransposeController

final class KeyNameTests: XCTestCase {
    func testKeyNamesFromC() {
        XCTAssertEqual(KeyName.name(base: 0, offset: 4, preferFlats: false), "E")
        XCTAssertEqual(KeyName.name(base: 0, offset: -1, preferFlats: false), "B")
        XCTAssertEqual(KeyName.name(base: 0, offset: 12, preferFlats: false), "C")
        XCTAssertEqual(KeyName.name(base: 0, offset: -13, preferFlats: false), "B")
    }

    func testSharpsAndFlats() {
        XCTAssertEqual(KeyName.name(base: 0, offset: 1, preferFlats: false), "C#")
        XCTAssertEqual(KeyName.name(base: 0, offset: 1, preferFlats: true), "Db")
    }

    func testNonCBase() {
        XCTAssertEqual(KeyName.name(base: 7, offset: 2, preferFlats: false), "A")   // G + 2
        XCTAssertEqual(KeyName.name(base: 10, offset: 0, preferFlats: true), "Bb")
    }

    func testOffsetLabel() {
        XCTAssertEqual(KeyName.offsetLabel(4), "+4")
        XCTAssertEqual(KeyName.offsetLabel(-3), "\u{2212}3")
        XCTAssertEqual(KeyName.offsetLabel(0), "0")
    }
}
