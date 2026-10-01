import Foundation

enum SendStatus: Equatable {
    case idle
    case sent(Date)
    case failed(String)
    case noDestination
}

@MainActor
final class TransposeController: ObservableObject {
    @Published private(set) var offset: Int = 0
    @Published private(set) var status: SendStatus = .idle
    @Published private(set) var destinations: [MIDIDestination]
    @Published var settings: TransposeSettings {
        didSet { settingsDidChange(from: oldValue) }
    }

    private let output: MIDIOutput
    private let store: SettingsStore
    private let reconnectDelay: Duration
    private var resendTask: Task<Void, Never>?

    init(
        settings: TransposeSettings,
        output: MIDIOutput,
        store: SettingsStore,
        reconnectDelay: Duration = .milliseconds(500)  // A freshly connected USB device may not be ready yet
    ) {
        self.settings = settings
        self.output = output
        self.store = store
        self.reconnectDelay = reconnectDelay
        self.destinations = output.destinations

        output.onDestinationsChanged = { [weak self] destinations in
            self?.destinationsDidChange(destinations)
        }
    }

    var keyName: String {
        KeyName.name(base: settings.baseKey, offset: offset, preferFlats: settings.preferFlats)
    }

    var offsetLabel: String { KeyName.offsetLabel(offset) }

    var baseKeyName: String {
        KeyName.name(base: settings.baseKey, offset: 0, preferFlats: settings.preferFlats)
    }

    var menuBarTitle: String { "\(keyName) \(offsetLabel)" }

    var isDestinationConnected: Bool {
        guard let uid = settings.destinationUniqueID else { return false }
        return destinations.contains { $0.uniqueID == uid }
    }

    func perform(_ action: TransposeAction) {
        let range = settings.range
        var next: Int
        switch action {
        case .up: next = offset + 1
        case .down: next = offset - 1
        case .reset: next = 0
        }

        if !range.contains(next) {
            switch settings.rangeBehavior {
            case .clamp: next = min(max(next, range.lowerBound), range.upperBound)
            case .wrap: next = next > range.upperBound ? range.lowerBound : range.upperBound
            }
        }

        guard next != offset || action == .reset else { return }
        setOffset(next)
        send()
    }

    func handleKeyPress(_ action: TransposeAction, isRepeat: Bool) {
        if isRepeat && !settings.allowKeyRepeat { return }
        perform(action)
    }

    func resend() {
        send()
    }

    func handleLaunch() {
        switch settings.launchBehavior {
        case .resetToZero:
            setOffset(0)
        case .restoreLast:
            let range = settings.range
            setOffset(min(max(store.lastOffset, range.lowerBound), range.upperBound))
        }
        send()
    }

    func selectDestination(_ uniqueID: Int32?) {
        guard settings.destinationUniqueID != uniqueID else { return }
        settings.destinationUniqueID = uniqueID
        send()
    }

    func loadPreset(_ preset: DevicePreset) {
        settings.apply(preset)
    }

    private func setOffset(_ value: Int) {
        offset = value
        store.lastOffset = value
    }

    private func send() {
        guard let uid = settings.destinationUniqueID, isDestinationConnected else {
            status = .noDestination
            return
        }
        do {
            let bytes = try SysExBuilder.build(settings.sysexTemplate, value: offset)
            try output.send(bytes, to: uid)
            status = .sent(Date())
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func settingsDidChange(from old: TransposeSettings) {
        guard settings != old else { return }
        store.save(settings)

        if settings.range != old.range, !settings.range.contains(offset) {
            setOffset(min(max(offset, settings.lowerBound), settings.upperBound))
            send()
        }
    }

    private func destinationsDidChange(_ new: [MIDIDestination]) {
        let previousIDs = Set(destinations.map(\.uniqueID))
        destinations = new

        // When a device appears while none were connected, select it.
        if previousIDs.isEmpty, let first = new.first, !isDestinationConnected {
            settings.destinationUniqueID = first.uniqueID
        }

        guard let uid = settings.destinationUniqueID else { return }
        let isConnected = isDestinationConnected

        if !isConnected {
            resendTask?.cancel()
            status = .noDestination
        } else if !previousIDs.contains(uid), settings.resendOnReconnect {
            scheduleResend()
        }
    }

    /// Debounced so rapid reconnects resend only once.
    private func scheduleResend() {
        resendTask?.cancel()
        let delay = reconnectDelay
        resendTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.resend()
        }
    }
}
