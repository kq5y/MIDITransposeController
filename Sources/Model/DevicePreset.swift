struct DevicePreset {
    let sysexTemplate: String
    let lowerBound: Int
    let upperBound: Int
}

extension DevicePreset {
    /// Universal Real Time SysEx: Master Coarse Tuning
    static let masterCoarseTuning = DevicePreset(
        sysexTemplate: "F0 7F 7F 04 04 00 {v:offset64} F7",
        lowerBound: -12,
        upperBound: 12
    )
}
