struct MIDIDestination: Identifiable, Hashable {
    let uniqueID: Int32
    let name: String
    var id: Int32 { uniqueID }
}
