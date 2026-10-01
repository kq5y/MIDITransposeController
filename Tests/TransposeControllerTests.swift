import XCTest
@testable import MIDITransposeController

@MainActor
final class TransposeControllerTests: XCTestCase {
    private let device = MIDIDestination(uniqueID: 42, name: "USB MIDI Device")
    private let other = MIDIDestination(uniqueID: 7, name: "IAC Driver Bus 1")
    private var defaults: UserDefaults!
    private var store: SettingsStore!
    private var output: MockMIDIOutput!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "TransposeControllerTests")!
        defaults.removePersistentDomain(forName: "TransposeControllerTests")
        store = SettingsStore(defaults: defaults)
        output = MockMIDIOutput(destinations: [other, device])
    }

    private func makeController(
        _ configure: (inout TransposeSettings) -> Void = { _ in },
        delay: Duration = .milliseconds(10)
    ) -> TransposeController {
        var settings = TransposeSettings.defaults()
        settings.destinationUniqueID = device.uniqueID
        configure(&settings)
        return TransposeController(settings: settings, output: output, store: store, reconnectDelay: delay)
    }

    private func sysex(_ mm: UInt8) -> [UInt8] { [0xF0, 0x7F, 0x7F, 0x04, 0x04, 0x00, mm, 0xF7] }

    func testUpDownReset() {
        let c = makeController()
        c.perform(.up)
        XCTAssertEqual(c.offset, 1)
        XCTAssertEqual(output.lastBytes, sysex(0x41))
        XCTAssertEqual(output.sent.last?.uniqueID, 42)

        c.perform(.down); c.perform(.down)
        XCTAssertEqual(c.offset, -1)
        XCTAssertEqual(output.lastBytes, sysex(0x3F))

        c.perform(.reset)
        XCTAssertEqual(c.offset, 0)
        XCTAssertEqual(output.lastBytes, sysex(0x40))
        XCTAssertEqual(output.sent.count, 4)
        if case .sent = c.status {} else { XCTFail("status = \(c.status)") }
    }

    func testClampAtBounds() {
        let c = makeController()
        for _ in 0..<12 { c.perform(.up) }
        XCTAssertEqual(c.offset, 12)
        let count = output.sent.count
        c.perform(.up)
        XCTAssertEqual(c.offset, 12)
        XCTAssertEqual(output.sent.count, count)

        c.perform(.reset)
        for _ in 0..<13 { c.perform(.down) }
        XCTAssertEqual(c.offset, -12)
        XCTAssertEqual(output.lastBytes, sysex(0x34))
        XCTAssertEqual(output.sent.count, count + 1 + 12)
    }

    func testWrap() {
        let c = makeController { $0.rangeBehavior = .wrap }
        for _ in 0..<13 { c.perform(.up) }
        XCTAssertEqual(c.offset, -12)
        XCTAssertEqual(output.lastBytes, sysex(0x34))
        c.perform(.down)
        XCTAssertEqual(c.offset, 12)
    }

    func testResetAtZeroStillSends() {
        let c = makeController()
        c.perform(.reset)
        XCTAssertEqual(output.sent.count, 1)
        XCTAssertEqual(output.lastBytes, sysex(0x40))
    }

    func testKeyRepeatIgnoredByDefault() {
        let c = makeController()
        c.handleKeyPress(.up, isRepeat: true)
        XCTAssertEqual(c.offset, 0)
        c.settings.allowKeyRepeat = true
        c.handleKeyPress(.up, isRepeat: true)
        XCTAssertEqual(c.offset, 1)
    }

    func testNoDestination() {
        output = MockMIDIOutput(destinations: [other])
        let c = makeController { $0.destinationUniqueID = nil }
        c.perform(.up)
        XCTAssertEqual(c.offset, 1)
        XCTAssertEqual(c.status, .noDestination)
        XCTAssertTrue(output.sent.isEmpty)
    }

    func testSavedDestinationNotConnected() {
        output = MockMIDIOutput(destinations: [other])
        let c = makeController { $0.destinationUniqueID = 99 }
        c.perform(.up)
        XCTAssertEqual(c.status, .noDestination)
    }

    func testSendFailure() {
        let c = makeController()
        output.shouldThrow = true
        c.perform(.up)
        XCTAssertEqual(c.offset, 1)
        if case .failed = c.status {} else { XCTFail("status = \(c.status)") }
    }

    func testInvalidTemplateFails() {
        let c = makeController { $0.sysexTemplate = "F0 {v:foo} F7" }
        c.perform(.up)
        if case .failed = c.status {} else { XCTFail("status = \(c.status)") }
        XCTAssertTrue(output.sent.isEmpty)
    }

    func testNoAutoSelectAtLaunch() {
        let c = makeController { $0.destinationUniqueID = nil }
        XCTAssertNil(c.settings.destinationUniqueID)
    }

    func testSavedDestinationIsKept() {
        let c = makeController { $0.destinationUniqueID = 7 }
        XCTAssertEqual(c.settings.destinationUniqueID, 7)
    }

    func testResendOnReconnect() async {
        let c = makeController()
        c.perform(.up); c.perform(.up); c.perform(.up)

        output.simulate(destinations: [other])
        XCTAssertEqual(c.status, .noDestination)

        let resent = expectation(description: "resent")
        output.onSend = { _ in resent.fulfill() }
        output.simulate(destinations: [other, device])
        await fulfillment(of: [resent], timeout: 2)
        XCTAssertEqual(output.lastBytes, sysex(0x43))
        if case .sent = c.status {} else { XCTFail("status = \(c.status)") }
    }

    func testRapidReconnectSendsOnce() async throws {
        let c = makeController(delay: .milliseconds(100))
        c.perform(.up)
        let count = output.sent.count
        for _ in 0..<3 {
            output.simulate(destinations: [other])
            output.simulate(destinations: [other, device])
        }
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(output.sent.count, count + 1)
    }

    func testNoResendWhenDisabled() async throws {
        let c = makeController { $0.resendOnReconnect = false }
        c.perform(.up)
        let count = output.sent.count
        output.simulate(destinations: [other])
        output.simulate(destinations: [other, device])
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(output.sent.count, count)
    }

    func testSelectsFirstDeviceConnectedFromNone() async {
        output = MockMIDIOutput(destinations: [])
        let c = makeController { $0.destinationUniqueID = nil }

        let resent = expectation(description: "resent")
        output.onSend = { _ in resent.fulfill() }
        output.simulate(destinations: [device])
        XCTAssertEqual(c.settings.destinationUniqueID, 42)
        XCTAssertEqual(store.load().destinationUniqueID, 42)
        await fulfillment(of: [resent], timeout: 2)
    }

    func testFirstDeviceReplacesMissingSavedDestination() {
        output = MockMIDIOutput(destinations: [])
        let c = makeController { $0.destinationUniqueID = 99 }
        output.simulate(destinations: [device])
        XCTAssertEqual(c.settings.destinationUniqueID, 42)
    }

    func testSavedDestinationWinsWhenConnectedFromNone() {
        output = MockMIDIOutput(destinations: [])
        let c = makeController { $0.destinationUniqueID = 42 }
        output.simulate(destinations: [other, device])
        XCTAssertEqual(c.settings.destinationUniqueID, 42)
    }

    func testNoAutoSelectWhileOtherDevicesConnected() {
        output = MockMIDIOutput(destinations: [other])
        let c = makeController { $0.destinationUniqueID = nil }
        output.simulate(destinations: [other, device])
        XCTAssertNil(c.settings.destinationUniqueID)
    }

    func testSelectDestinationSends() {
        let c = makeController()
        c.selectDestination(7)
        XCTAssertEqual(output.sent.last?.uniqueID, 7)
    }

    func testNarrowingRangeClampsAndSends() {
        let c = makeController()
        for _ in 0..<10 { c.perform(.up) }
        c.settings.upperBound = 5
        XCTAssertEqual(c.offset, 5)
        XCTAssertEqual(output.lastBytes, sysex(0x45))
    }

    func testLaunchResetsToZero() {
        store.lastOffset = 5
        let c = makeController()
        c.handleLaunch()
        XCTAssertEqual(c.offset, 0)
        XCTAssertEqual(output.lastBytes, sysex(0x40))
    }

    func testLaunchRestoresLast() {
        store.lastOffset = 5
        let c = makeController { $0.launchBehavior = .restoreLast }
        c.handleLaunch()
        XCTAssertEqual(c.offset, 5)
        XCTAssertEqual(output.lastBytes, sysex(0x45))
    }

    func testSettingsPersisted() {
        let c = makeController()
        c.settings.preferFlats = true
        c.perform(.up)
        XCTAssertTrue(store.load().preferFlats)
        XCTAssertEqual(store.lastOffset, 1)
        XCTAssertEqual(c.keyName, "Db")
        XCTAssertEqual(c.menuBarTitle, "Db +1")
    }
}
