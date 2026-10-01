# MIDI Transpose Controller

A small macOS app (macOS 14+) for transposing a MIDI instrument in semitone steps.
Each change is sent to the selected MIDI output as a SysEx message.

## Supported method

The app sends the MIDI standard **Universal Real Time SysEx — Master Coarse Tuning** message:

```
F0 7F 7F 04 04 00 mm F7    (mm = 0x40 + semitones)
```

Any instrument that responds to Master Coarse Tuning should work. The message is
defined by an editable template in Settings, so other formats can be configured too:

- Byte tokens: two hex digits (`F0`, `7f`, ...)
- Value token: `{v:offset64}` (64 + value), `{v:signed7}` (7-bit two's complement), or
  `{v:nibble}` (8-bit two's complement split into high/low nibbles)

Notes for Master Coarse Tuning instruments:

- The instrument's own transpose setting is added on top of this value; keep it at 0.
- The value is applied by the sound engine, so notes sent from the instrument's MIDI OUT
  are not transposed.
- Many instruments reset the value on power-cycle, so the app resends it when the
  device reconnects.

## Controls

| Action | In app | Global |
|---|---|---|
| +1 | ↑ / → | ⌃⌥⌘↑ |
| −1 | ↓ / ← | ⌃⌥⌘↓ |
| Reset | 0 | ⌃⌥⌘0 |

Global hotkeys can be changed in Settings. The current value is also shown in the menu bar.

## Output

Pick the MIDI output on the main window; the choice is remembered. When a device is connected
while no MIDI outputs exist, it is selected automatically.

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MIDITransposeController.xcodeproj -scheme MIDITransposeController -configuration Release -derivedDataPath build build
open build/Build/Products/Release/MIDITransposeController.app
```

## Test

```bash
xcodebuild -project MIDITransposeController.xcodeproj -scheme MIDITransposeController -destination 'platform=macOS' -derivedDataPath build test
```
