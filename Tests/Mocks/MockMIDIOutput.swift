@testable import MIDITransposeController

@MainActor
final class MockMIDIOutput: MIDIOutput {
    struct SendError: Error {}

    var destinations: [MIDIDestination]
    var onDestinationsChanged: (([MIDIDestination]) -> Void)?
    private(set) var sent: [(bytes: [UInt8], uniqueID: Int32)] = []
    var shouldThrow = false
    var onSend: (([UInt8]) -> Void)?

    init(destinations: [MIDIDestination] = []) {
        self.destinations = destinations
    }

    func send(_ bytes: [UInt8], to uniqueID: Int32) throws {
        if shouldThrow { throw SendError() }
        sent.append((bytes, uniqueID))
        onSend?(bytes)
    }

    func simulate(destinations: [MIDIDestination]) {
        self.destinations = destinations
        onDestinationsChanged?(destinations)
    }

    var lastBytes: [UInt8]? { sent.last?.bytes }
}
