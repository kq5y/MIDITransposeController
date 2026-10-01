enum RangeBehavior: String, Codable, CaseIterable { case clamp, wrap }
enum LaunchBehavior: String, Codable, CaseIterable { case resetToZero, restoreLast }

struct TransposeSettings: Codable, Equatable {
    var baseKey: Int                   // 0 = C … 11 = B
    var lowerBound: Int
    var upperBound: Int
    var rangeBehavior: RangeBehavior
    var preferFlats: Bool
    var launchBehavior: LaunchBehavior
    var resendOnReconnect: Bool
    var allowKeyRepeat: Bool
    var alwaysOnTop: Bool
    var sysexTemplate: String
    var destinationUniqueID: Int32?
}

extension TransposeSettings {
    static func defaults(preset: DevicePreset = .masterCoarseTuning) -> TransposeSettings {
        var settings = TransposeSettings(
            baseKey: 0,
            lowerBound: -12,
            upperBound: 12,
            rangeBehavior: .clamp,
            preferFlats: false,
            launchBehavior: .resetToZero,
            resendOnReconnect: true,
            allowKeyRepeat: false,
            alwaysOnTop: false,
            sysexTemplate: "",
            destinationUniqueID: nil
        )
        settings.apply(preset)
        return settings
    }

    mutating func apply(_ preset: DevicePreset) {
        sysexTemplate = preset.sysexTemplate
        lowerBound = preset.lowerBound
        upperBound = preset.upperBound
    }

    var range: ClosedRange<Int> { lowerBound...upperBound }
}
