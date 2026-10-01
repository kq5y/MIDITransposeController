@MainActor
protocol MIDIOutput: AnyObject {
    var destinations: [MIDIDestination] { get }
    var onDestinationsChanged: (([MIDIDestination]) -> Void)? { get set }
    func send(_ bytes: [UInt8], to uniqueID: Int32) throws
}

@MainActor
final class NullMIDIOutput: MIDIOutput {
    let destinations: [MIDIDestination] = []
    var onDestinationsChanged: (([MIDIDestination]) -> Void)?
    func send(_ bytes: [UInt8], to uniqueID: Int32) throws {}
}
