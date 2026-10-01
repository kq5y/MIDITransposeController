enum KeyName {
    static let sharps = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static let flats  = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

    static func name(base: Int, offset: Int, preferFlats: Bool) -> String {
        let i = ((base + offset) % 12 + 12) % 12
        return (preferFlats ? flats : sharps)[i]
    }

    /// Negative values use U+2212 MINUS SIGN.
    static func offsetLabel(_ offset: Int) -> String {
        offset > 0 ? "+\(offset)" : offset < 0 ? "\u{2212}\(-offset)" : "0"
    }
}
