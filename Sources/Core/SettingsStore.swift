import Foundation

final class SettingsStore {
    static let settingsKey = "transposeSettings.v1"
    static let lastOffsetKey = "lastOffset.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TransposeSettings {
        guard let data = defaults.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(TransposeSettings.self, from: data)
        else { return .defaults() }
        return settings
    }

    func save(_ settings: TransposeSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.settingsKey)
    }

    var lastOffset: Int {
        get { defaults.integer(forKey: Self.lastOffsetKey) }
        set { defaults.set(newValue, forKey: Self.lastOffsetKey) }
    }
}
