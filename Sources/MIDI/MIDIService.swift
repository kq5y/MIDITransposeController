import CoreMIDI
import Foundation

enum MIDIServiceError: LocalizedError {
    case osStatus(String, OSStatus)
    case destinationNotFound(Int32)
    case messageTooLong(Int)

    var errorDescription: String? {
        switch self {
        case .osStatus(let function, let status): "\(function) failed (OSStatus \(status))"
        case .destinationNotFound(let uid): "送信先が見つかりません (UniqueID \(uid))"
        case .messageTooLong(let count): "メッセージが長すぎます (\(count) バイト)"
        }
    }
}

/// Uses MIDIPacketList + MIDISend: deprecated, but the simplest option for short SysEx.
@MainActor
final class MIDIService: MIDIOutput {
    private(set) var destinations: [MIDIDestination] = []
    var onDestinationsChanged: (([MIDIDestination]) -> Void)?

    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private(set) var setupError: Error?

    init() {
        do {
            try check("MIDIClientCreateWithBlock", MIDIClientCreateWithBlock("MIDITransposeController" as CFString, &client) { [weak self] notification in
                // Notifications arrive on an arbitrary thread.
                guard notification.pointee.messageID == .msgSetupChanged else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.refreshDestinations() }
                }
            })
            try check("MIDIOutputPortCreate", MIDIOutputPortCreate(client, "Output" as CFString, &outputPort))
        } catch {
            setupError = error
        }
        destinations = Self.enumerateDestinations()
    }

    func send(_ bytes: [UInt8], to uniqueID: Int32) throws {
        if let setupError { throw setupError }

        var object = MIDIObjectRef()
        var type = MIDIObjectType.other
        let status = MIDIObjectFindByUniqueID(uniqueID, &object, &type)
        guard status == noErr, type == .destination || type == .externalDestination else {
            throw MIDIServiceError.destinationNotFound(uniqueID)
        }

        guard bytes.count <= 256 else { throw MIDIServiceError.messageTooLong(bytes.count) }
        let bufferSize = 512
        let sendStatus = withUnsafeTemporaryAllocation(byteCount: bufferSize, alignment: MemoryLayout<MIDIPacketList>.alignment) { buffer in
            let packetList = buffer.baseAddress!.bindMemory(to: MIDIPacketList.self, capacity: 1)
            let packet = MIDIPacketListInit(packetList)
            _ = MIDIPacketListAdd(packetList, bufferSize, packet, 0, bytes.count, bytes)
            return MIDISend(outputPort, MIDIEndpointRef(object), packetList)
        }
        try check("MIDISend", sendStatus)
    }

    private func refreshDestinations() {
        destinations = Self.enumerateDestinations()
        onDestinationsChanged?(destinations)
    }

    private static func enumerateDestinations() -> [MIDIDestination] {
        (0..<MIDIGetNumberOfDestinations()).compactMap { index in
            let endpoint = MIDIGetDestination(index)
            guard endpoint != 0 else { return nil }

            var uniqueID: Int32 = 0
            guard MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID) == noErr else { return nil }

            var name: Unmanaged<CFString>?
            let nameStatus = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
            let displayName = nameStatus == noErr ? (name?.takeRetainedValue() as String?) : nil

            return MIDIDestination(uniqueID: uniqueID, name: displayName ?? "Unknown (\(uniqueID))")
        }
    }

    private func check(_ function: String, _ status: OSStatus) throws {
        guard status == noErr else { throw MIDIServiceError.osStatus(function, status) }
    }
}
