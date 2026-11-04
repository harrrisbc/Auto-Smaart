# Auto-Smaart Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Mac app that tunes one DiGiCo Quantum 225 Matrix output per pass from a Smaart trace and one curve-bank preset, with confirm-before-write delay and EQ.

**Architecture:** Five units from the spec, each tested on its own. A pure delay rule and a pure EQ fit sit behind a Smaart API session and a Quantum 225 OSC client. A pass controller owns unlock, confirm, undo, and errors. SwiftUI draws the four screens and sends nothing by itself. The fit never opens a socket.

**Tech Stack:** Swift 5.10 package, macOS 14, SwiftUI, Foundation URLSession WebSockets, POSIX UDP OSC, XCTest. Run every `swift test` command on a Mac.

## Global Constraints

Every task includes this section. Values are copied from the spec and, where the spec points at layout, from the approved design system. If a draft caption disagrees with the spec, follow the spec.

- Auto-Smaart is a Mac app. One window. Title “Auto-Smaart”. Subtitle “Quantum 225”. Window size 1440×900.
- One pass tunes one zone. A zone is one DiGiCo Quantum 225 Matrix output plus one curve-bank preset.
- The app does not keep chasing the system during a show, and it does not send a console lock command.
- Out of scope: show-time continuous chasing, timers, or a measure-and-write loop after Compare; Yamaha PM10 or any console other than the DiGiCo Quantum 225; more than one Matrix output in one pass; AI suggestions, model calls, or any non-deterministic step in the read, fit, or write path; screen capture, UI scraping, or screenshot parsing.
- Steps, in order: Pick, Delay, EQ, Compare. A future step cannot be opened until this spec says it is unlocked. Back and the step rail send no OSC.
- The app reads Rational Acoustics Smaart through the official API. It opens the local API session. There is no Smaart host field. The app does not screen-capture.
- Delay suggestion order: a numeric delay-finder result is used and the impulse is not scanned; otherwise the earliest sample with the greatest absolute amplitude, time in milliseconds `sampleIndex / sampleRate * 1000`; otherwise no suggestion.
- Delay shows the Smaart suggestion in milliseconds to one decimal place, rounded half away from zero. That displayed number is the value the operator confirms.
- Phase is stored with the trace. The EQ fit does not use phase. Compare does not plot phase.
- Curve bank: one local list, shared by every pass, still there after relaunch. Types are Target and Reference. Blank name is refused. A name already in the list replaces that preset's curve and type. There is no separate delete command.
- Store-target failure copy: “No Smaart target curve.” Store-trace and missing-magnitude copy: “No Smaart trace.” Missing-suggestion copy: “No delay suggestion.”
- DiGiCo Quantum 225 only, over OSC. A Quantum 225 has 12 Matrix outputs. The Pulse upgrade does not change that count. The Pick list is Matrix 1 through Matrix 12. The app does not query the console for the list. The app does not fill in a default address or port.
- EQ addresses, band `b` from 1 through 8, names case-sensitive: `/sd/Matrix_Outputs/<n>/EQ/eq_freq_<b>`, `/sd/Matrix_Outputs/<n>/EQ/eq_gain_<b>`, `/sd/Matrix_Outputs/<n>/EQ/eq_Q_<b>`, `/sd/Matrix_Outputs/<n>/EQ/eq_on_<b>`. A used band sends `eq_on_<b>` as `1`. Unused bands are left untouched: no message of any kind, including no zero frequency, no 0 dB, no Q 0, and no off switch.
- Delay addresses, in this order: `/sd/Matrix_Outputs/<n>/Channel_Delay/delay`, `/sd/Matrix_Outputs/<n>/Channel_Delay/fine_delay`. The confirmed Matrix 1 example, value 0, is those two addresses with argument 0. The value the operator confirms is the argument of both messages. This spec does not state a unit for either address and does not apply a numeric range.
- No OSC of any kind is sent before the confirm press. The fake-console test asserts an empty receive buffer up to that press.
- Confirm order: read the parameters this confirm will replace; hold that read as this attempt's restore copy; write the new values; on success replace the saved snapshot with the restore copy. Failure before any accepted write: “Write failed. Previous value kept.” A later write that fails is restored only for parameters already written. Restore accepted: “Write failed. Previous value kept.” Restore not accepted: “Write failed. Console may not match the previous value.” The saved snapshot stays unchanged either way.
- Delay must be confirmed with a successful write before any EQ calculation. There is no skip, even when the suggestion matches the previous value.
- EQ write order: band 1 upward, and within a band freq, gain, Q, on. EQ confirm does not read or write unused bands and does not read or write delay.
- A zero-band EQ confirm sends no OSC, does not remeasure, does not replace the EQ snapshot, and opens Compare on the post-delay magnitude.
- Remeasure failure after a successful delay write: the delay write stays a success, EQ is not calculated, stay on Delay, “Could not remeasure.” Retry remeasure reads Smaart again and does not write the console.
- Remeasure failure after a successful EQ write: the EQ write stays a success, open Compare, “Could not remeasure.” Before is the post-delay magnitude. After is absent.
- A failed remeasure never rolls back a write that already succeeded.
- Fit: deterministic; 20 Hz through 20 kHz inclusive; interpolate dB linearly against the natural log of frequency; do not extrapolate; deviation is measurement dB minus preset dB; greatest absolute deviation 1.0 dB or less produces zero bands; otherwise up to 8 peaking bands; ties go to the lower frequency; gain is deviation times −1, clamped to −18.0 dB through +18.0 dB, then rounded half away from zero to 0.1 dB; single-bin lobe Q is 4.00; otherwise `N = log2(f_hi / f_lo)` and `Q = sqrt(2^N) / (2^N − 1)`, clamped to 0.10 through 20.00, then rounded half away from zero to 0.01; frequency is unrounded on the wire; subtract the 48 kHz RBJ peaking magnitude from the deviation. The 48 kHz figure is only the fit model.
- No-overlap copy, shown on Delay: “Preset does not overlap the trace.”
- Zero-band copy on EQ: “No EQ is needed.”
- Pick last-write text changes only when Compare opens: `<delay ms> · <count> bands`, or `<delay ms> · no EQ`. Until then the row says “not written”. Undo does not change that line.
- Undo delay writes the delay snapshot only. Compare’s Undo last write writes the delay snapshot and, band for band, the EQ snapshot. Bands absent from the EQ snapshot are not sent. A control that has no snapshot yet is absent. The app never invents a previous value.
- Compare plots magnitude from 20 Hz to 20 kHz. Before `#a78b71` at 70% opacity. After `#e8d5b7`, present only when the post-EQ remeasure succeeded. No confirm button on Compare.
- Colors only: background `#0a0a0a`; primary text `#ffffff`; secondary `#a3a3a3`; dim `rgba(255,255,255,0.45)`; gold `#a78b71`; light gold `#c9b8a0`; hover gold `#e8d5b7`; live dot `#4ade80`; grid `rgba(255,255,255,0.12)`; selected row `rgba(167,139,113,0.16)` with a `#a78b71` 2px left edge. Do not use blue, purple, neon, cream pages, or rainbow gradients.
- Wordmark only: Playfair Display, italic, 18px. All other UI: Inter. Empty EQ cells are an em dash, never 0 Hz, 0 dB, or Q 0.
- Status: “Smaart API” is live only while the official API session is open. “OSC armed” only on Delay or EQ when a confirm press is allowed to send. Otherwise “OSC idle”.
- Warning copy on Delay and before an EQ send: “Nothing is sent until you confirm.”
- Delay supporting line states that the suggestion is the Smaart delay and must not say the suggestion came from the target or the reference.

## Scope

The spec says the scope is one implementation plan and names five units that can be tested without each other: Smaart reader, curve bank, fit, console, pass UI. This document is that one plan. The units are separate tasks so each can fail review on its own. They are not separate plans.

## File structure

- `Package.swift` — macOS 14 package, library targets plus the app executable.
- `Sources/AutoSmaartCore/Rounding.swift` — half-away-from-zero rounding.
- `Sources/AutoSmaartCore/Models.swift` — traces, presets, bands, OSC values, matrix records.
- `Sources/AutoSmaartCore/DelaySuggestion.swift` — finder, then impulse peak, then none.
- `Sources/AutoSmaartCore/Fit.swift` — interpolation, peaking fit, frequency labels.
- `Sources/AutoSmaartCore/CurveBank.swift` — the persistent preset list.
- `Sources/AutoSmaartPass/OutputStore.swift` — twelve local matrix rows, names, snapshots, last-write text.
- `Sources/AutoSmaartPass/Pass.swift` — pass controller. Confirm, EQ, and undo are extensions in this same file so they can see private state. The target depends on `AutoSmaartCore` and `ConsoleOSC` and does not create a dependency cycle.
- `Sources/AutoSmaartPass/Presenter.swift` — every user-visible string and the OSC-armed rule.
- `Sources/SmaartAPI/Session.swift` — official local API session and payload decoder.
- `Sources/ConsoleOSC/OscMessage.swift` — OSC 1.0 encode and decode for float32 and int32.
- `Sources/ConsoleOSC/Addresses.swift` — the only address strings this app may build.
- `Sources/ConsoleOSC/Confirm.swift` — read, hold, write, restore.
- `Sources/ConsoleOSC/Quantum225Client.swift` — UDP client. Writes are accepted only when the console echoes them.
- `Sources/AutoSmaartApp/` — SwiftUI window. It calls the pass controller and does not format its own copy.
- `Tests/Fixtures/` — recorded Smaart captures. No console.
- `Tests/AutoSmaartCoreTests/` — rounding, delay, fit, bank.
- `Tests/AutoSmaartPassTests/` — pass unlock, confirm, undo, and copy.
- `Tests/SmaartAPITests/` — scripted API session.
- `Tests/ConsoleOSCTests/` — codec, in-memory confirm, UDP fake console.
- `Tests/HardwareTests/Quantum225HardwareTests.swift` — one real Quantum 225, skipped unless the hardware environment is set.

---

### Task 1: Package and rounding

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/AutoSmaartCore/Rounding.swift`
- Test: `Tests/AutoSmaartCoreTests/RoundingTests.swift`

**Interfaces:**
- Consumes: none
- Produces: `roundHalfAwayFromZero(_ value: Double, places: Int) -> Double`. `places` is the number of digits after the decimal. Halfway values move away from zero. `NSDecimalNumberHandler.RoundingMode.plain` is that rule.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AutoSmaartCore

final class RoundingTests: XCTestCase {
    func testHalfAwayFromZero() {
        XCTAssertEqual(roundHalfAwayFromZero(12.35, places: 1), 12.4, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(12.34, places: 1), 12.3, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(-1.25, places: 1), -1.3, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(0.05, places: 1), 0.1, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(-0.05, places: 1), -0.1, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(80.5, places: 0), 81, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(80.4, places: 0), 80, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(-1.04, places: 1), -1.0, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(-1.05, places: 1), -1.1, accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RoundingTests`
Expected: FAIL. The build stops with `error: no such module 'AutoSmaartCore'`.

- [ ] **Step 3: Write minimal implementation**

`.gitignore`

```
.build/
.swiftpm/
.DS_Store
```

`Package.swift`

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AutoSmaart",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AutoSmaart", targets: ["AutoSmaartApp"])
    ],
    targets: [
        .target(name: "AutoSmaartCore"),
        .target(name: "SmaartAPI", dependencies: ["AutoSmaartCore"]),
        .target(name: "ConsoleOSC", dependencies: ["AutoSmaartCore"]),
        .executableTarget(
            name: "AutoSmaartApp",
            dependencies: ["AutoSmaartCore", "SmaartAPI", "ConsoleOSC"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "AutoSmaartCoreTests", dependencies: ["AutoSmaartCore"], resources: [.process("../Fixtures")]),
        .testTarget(name: "SmaartAPITests", dependencies: ["SmaartAPI"]),
        .testTarget(name: "ConsoleOSCTests", dependencies: ["ConsoleOSC", "AutoSmaartCore"]),
        .testTarget(name: "HardwareTests", dependencies: ["AutoSmaartCore", "SmaartAPI", "ConsoleOSC"])
    ]
)
```

`Sources/AutoSmaartCore/Rounding.swift`

```swift
import Foundation

public func roundHalfAwayFromZero(_ value: Double, places: Int) -> Double {
    let source = Decimal(string: String(value)) ?? Decimal(value)
    let behavior = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: Int16(places),
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    return NSDecimalNumber(decimal: source).rounding(accordingToBehavior: behavior).doubleValue
}
```

Create empty directories the later targets need so the package resolves: `Sources/SmaartAPI`, `Sources/ConsoleOSC`, `Sources/AutoSmaartApp/Resources`, `Tests/SmaartAPITests`, `Tests/ConsoleOSCTests`, `Tests/HardwareTests`, `Tests/Fixtures`. Put a one-line `Sources/SmaartAPI/Placeholder.swift`, `Sources/ConsoleOSC/Placeholder.swift`, and `Sources/AutoSmaartApp/Placeholder.swift` containing `import Foundation`. Put `Tests/SmaartAPITests/EmptyTests.swift`, `Tests/ConsoleOSCTests/EmptyTests.swift`, and `Tests/HardwareTests/EmptyTests.swift` containing:

```swift
import XCTest
final class EmptyTests: XCTestCase {
    func testPackageResolves() { XCTAssertTrue(true) }
}
```

The later tasks replace those placeholders by deleting `Placeholder.swift` when the real file arrives, and by replacing `EmptyTests.swift` when that target gets its first real test.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter RoundingTests`
Expected: PASS. `testHalfAwayFromZero` passed.

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "feat: add Mac package and half-away rounding"
```

---

### Task 2: Domain models and delay suggestion

**Files:**
- Create: `Sources/AutoSmaartCore/Models.swift`
- Create: `Sources/AutoSmaartCore/DelaySuggestion.swift`
- Create: `Tests/Fixtures/finder-and-impulse.json`
- Create: `Tests/Fixtures/impulse-only.json`
- Create: `Tests/Fixtures/neither.json`
- Create: `Tests/Fixtures/no-magnitude.json`
- Test: `Tests/AutoSmaartCoreTests/DelaySuggestionTests.swift`

**Interfaces:**
- Consumes: `roundHalfAwayFromZero(_:places:)`
- Produces:
  - `public struct MagnitudePoint: Equatable, Codable { var hz: Double; var db: Double; var phase: Double }`
  - `struct Impulse: Equatable, Codable { var sampleRate: Double; var samples: [Double] }`
  - `struct SmaartCapture: Equatable, Codable { var magnitude: [MagnitudePoint]; var delayFinderMs: Double?; var impulse: Impulse? }`
  - `enum DelaySuggestion: Equatable { case milliseconds(Double); case none }`
  - `func delaySuggestion(of capture: SmaartCapture) -> DelaySuggestion`
  - `func displayedDelayMs(_ rawMilliseconds: Double) -> Double`

- [ ] **Step 1: Write the failing test**

`Tests/Fixtures/finder-and-impulse.json`

```json
{
  "magnitude": [{"hz": 1000.0, "db": -3.0, "phase": 15.0}],
  "delayFinderMs": 12.35,
  "impulse": {"sampleRate": 48000.0, "samples": [0.0, 0.0, 1.0]}
}
```

`Tests/Fixtures/impulse-only.json`

```json
{
  "magnitude": [{"hz": 1000.0, "db": -3.0, "phase": 0.0}],
  "delayFinderMs": null,
  "impulse": {"sampleRate": 48000.0, "samples": [0.0, 0.1, -0.4, 0.9, 0.9, 0.2]}
}
```

The greatest absolute sample is 0.9. It occurs at indexes 3 and 4. The earliest index is 3. `3 / 48000 * 1000 = 0.0625` milliseconds.

`Tests/Fixtures/neither.json`

```json
{
  "magnitude": [{"hz": 500.0, "db": 1.0, "phase": 4.0}],
  "delayFinderMs": null,
  "impulse": null
}
```

`Tests/Fixtures/no-magnitude.json`

```json
{
  "magnitude": [],
  "delayFinderMs": 5.0,
  "impulse": {"sampleRate": 48000.0, "samples": [0.0, 1.0]}
}
```

`Tests/AutoSmaartCoreTests/DelaySuggestionTests.swift`

```swift
import XCTest
@testable import AutoSmaartCore

final class DelaySuggestionTests: XCTestCase {
    private func load(_ name: String) throws -> SmaartCapture {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        let data = try Data(contentsOf: try XCTUnwrap(url))
        return try JSONDecoder().decode(SmaartCapture.self, from: data)
    }

    func testFinderWinsWhenImpulseIsAlsoPresent() throws {
        let capture = try load("finder-and-impulse")
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(12.35))
        XCTAssertEqual(displayedDelayMs(12.35), 12.4, accuracy: 1e-9)
        XCTAssertEqual(capture.magnitude.first?.phase, 15.0)
    }

    func testMissingFinderUsesEarliestMaximumAbsoluteSample() throws {
        let capture = try load("impulse-only")
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(0.0625))
    }

    func testNeitherFinderNorImpulseProducesNoSuggestion() throws {
        let capture = try load("neither")
        XCTAssertEqual(delaySuggestion(of: capture), .none)
        XCTAssertFalse(capture.magnitude.isEmpty)
    }

    func testMissingMagnitudeIsAnEmptyTrace() throws {
        let capture = try load("no-magnitude")
        XCTAssertTrue(capture.magnitude.isEmpty)
    }

    func testEqualAbsolutePeaksChooseTheEarliestIndex() {
        let capture = SmaartCapture(
            magnitude: [MagnitudePoint(hz: 100, db: 0, phase: 0)],
            delayFinderMs: nil,
            impulse: Impulse(sampleRate: 48000, samples: [0.2, -0.5, 0.5])
        )
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(1.0 / 48000.0 * 1000.0))
    }

    func testImpulseWithoutSampleRateProducesNoSuggestion() {
        let capture = SmaartCapture(
            magnitude: [MagnitudePoint(hz: 100, db: 0, phase: 0)],
            delayFinderMs: nil,
            impulse: nil
        )
        XCTAssertEqual(delaySuggestion(of: capture), .none)
    }
}
```

SPM processes `../Fixtures` from the test target into the test bundle. If `Bundle.module` cannot see the subdirectory, the `load` helper's second lookup is the processed resource name. Keep both lookups. The fixture files live only in `Tests/Fixtures/`.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DelaySuggestionTests`
Expected: FAIL. The build stops with `error: cannot find type 'SmaartCapture' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AutoSmaartCore/Models.swift`

```swift
import Foundation

public struct MagnitudePoint: Equatable, Codable {
    public var hz: Double
    public var db: Double
    public var phase: Double
    public init(hz: Double, db: Double, phase: Double) {
        self.hz = hz
        self.db = db
        self.phase = phase
    }
}

struct Impulse: Equatable, Codable {
    var sampleRate: Double
    var samples: [Double]
}

struct SmaartCapture: Equatable, Codable {
    var magnitude: [MagnitudePoint]
    var delayFinderMs: Double?
    var impulse: Impulse?
}

public enum CurveKind: String, Equatable, Codable {
    case target
    case reference
}

public struct CurvePreset: Equatable, Codable {
    public var name: String
    public var kind: CurveKind
    public var points: [MagnitudePoint]
    public init(name: String, kind: CurveKind, points: [MagnitudePoint]) {
        self.name = name
        self.kind = kind
        self.points = points
    }
}

public struct EqBand: Equatable, Codable {
    public var index: Int
    public var hz: Double
    public var gainDb: Double
    public var q: Double
    public init(index: Int, hz: Double, gainDb: Double, q: Double) {
        self.index = index
        self.hz = hz
        self.gainDb = gainDb
        self.q = q
    }
}

public enum OscValue: Equatable, Codable {
    case float32(Float)
    case int32(Int32)

    private enum Key: String, CodingKey { case kind, value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .float32(let value):
            try container.encode("float32", forKey: .kind)
            try container.encode(value, forKey: .value)
        case .int32(let value):
            try container.encode("int32", forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let kind = try container.decode(String.self, forKey: .kind)
        if kind == "float32" {
            self = .float32(try container.decode(Float.self, forKey: .value))
        } else if kind == "int32" {
            self = .int32(try container.decode(Int32.self, forKey: .value))
        } else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "unknown OSC kind")
        }
    }
}
```

`Sources/AutoSmaartCore/DelaySuggestion.swift`

```swift
import Foundation

public enum DelaySuggestion: Equatable {
    case milliseconds(Double)
    case none
}

public func displayedDelayMs(_ rawMilliseconds: Double) -> Double {
    roundHalfAwayFromZero(rawMilliseconds, places: 1)
}

public func delaySuggestion(of capture: SmaartCapture) -> DelaySuggestion {
    if let finder = capture.delayFinderMs {
        return .milliseconds(finder)
    }
    guard let impulse = capture.impulse, impulse.sampleRate > 0, !impulse.samples.isEmpty else {
        return .none
    }
    var bestIndex = 0
    var bestAbsolute = abs(impulse.samples[0])
    for index in impulse.samples.indices.dropFirst() {
        let absolute = abs(impulse.samples[index])
        if absolute > bestAbsolute {
            bestAbsolute = absolute
            bestIndex = index
        }
    }
    return .milliseconds(Double(bestIndex) / impulse.sampleRate * 1000.0)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DelaySuggestionTests`
Expected: PASS. Six tests passed. The finder fixture's displayed delay is 12.4, and the impulse fixture's raw suggestion is 0.0625 because index 3 wins over the later equal peak.

- [ ] **Step 5: Commit**

```bash
git add Sources/AutoSmaartCore/Models.swift Sources/AutoSmaartCore/DelaySuggestion.swift Tests/Fixtures Tests/AutoSmaartCoreTests/DelaySuggestionTests.swift
git commit -m "feat: add delay suggestion from finder or impulse peak"
```

---

### Task 3: Smaart API session

**Files:**
- Create: `Sources/SmaartAPI/Session.swift`
- Delete: `Sources/SmaartAPI/Placeholder.swift`
- Delete: `Tests/SmaartAPITests/EmptyTests.swift`
- Test: `Tests/SmaartAPITests/SessionTests.swift`

**Interfaces:**
- Consumes: `SmaartCapture`, `MagnitudePoint`, `Impulse`
- Produces:
  - `public enum SmaartReaderError: Error, Equatable { case noTrace; case noTarget; case sessionClosed }`
  - `public protocol SmaartReader: AnyObject { func openSession() throws; func closeSession(); var isSessionOpen: Bool { get }; func readTrace() throws -> SmaartCapture; func readTargetCurve() throws -> [MagnitudePoint] }`
  - `protocol SmaartWire: AnyObject { func connect() throws; func close(); var isOpen: Bool { get }; func send(_ text: String) throws; func receive() throws -> String }`
  - `final class OfficialSmaartSession: SmaartReader`
  - `final class URLSessionSmaartWire: SmaartWire`
  - `let smaartAPIURL = URL(string: "ws://127.0.0.1:26000/api/v4/")!`

The transport is the published Smaart API v4 WebSocket used by the API at `ws://127.0.0.1:26000/api/v4/`. There is no host field. Commands this session sends:

- `{"action":"get","target":"measurements"}`
- `{"action":"findDelay","target":{"measurementName":"<name>"},"properties":[{"automaticallyStart":true},{"automaticallyInsert":false},{"automaticallyStop":true}]}`
- `{"action":"get","target":{"measurementName":"<name>"}}`
- `{"action":"get","target":"targetCurve"}`

Decoder contract for the bodies those commands return:

- Measurements: `transferFunctionMeasurements`, each object with `measurementName` and `active`. The session uses the first object whose `active` is true. Spectrum rows are ignored.
- Delay finder: a numeric `delayFinderMs` on the findDelay reply. A missing or null `delayFinderMs` means the API did not expose a finder value.
- Measurement body: `magnitude` array of `{hz, db, phase}`. Missing `phase` is stored as 0. `impulse` is `{sampleRate, samples}` or absent.
- Target: `points` array of `{hz, db}`. Phase on a target point is stored as 0. An error object or a missing `points` array is no target.

`automaticallyInsert` is false so the session does not change Smaart's inserted delay.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import SmaartAPI
@testable import AutoSmaartCore

final class ScriptedWire: SmaartWire {
    var sent: [String] = []
    var replies: [String]
    var isOpen = false
    init(replies: [String]) { self.replies = replies }
    func connect() throws { isOpen = true }
    func close() { isOpen = false }
    func send(_ text: String) throws { sent.append(text) }
    func receive() throws -> String {
        guard !replies.isEmpty else { throw SmaartReaderError.noTrace }
        return replies.removeFirst()
    }
}

final class SessionTests: XCTestCase {
    func testURLIsLocalAPIVersion4() {
        XCTAssertEqual(smaartAPIURL.absoluteString, "ws://127.0.0.1:26000/api/v4/")
    }

    func testFinderIsKeptWhenImpulseIsAlsoInThePayload() throws {
        let wire = ScriptedWire(replies: [
            #"{"transferFunctionMeasurements":[{"measurementName":"Later","active":false},{"measurementName":"TF","active":true}]}"#,
            #"{"delayFinderMs":12.35}"#,
            #"{"magnitude":[{"hz":1000,"db":-3,"phase":15}],"impulse":{"sampleRate":48000,"samples":[0,0,1]},"coherence":0.9}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        XCTAssertTrue(session.isSessionOpen)
        let capture = try session.readTrace()
        XCTAssertEqual(capture.delayFinderMs, 12.35)
        XCTAssertEqual(capture.magnitude, [MagnitudePoint(hz: 1000, db: -3, phase: 15)])
        XCTAssertEqual(capture.impulse?.samples, [0, 0, 1])
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(12.35))
        let sent = try wire.sent.map { try JSONDecoder().decode(JSONValue.self, from: Data($0.utf8)) }
        XCTAssertEqual(sent[0], JSONValue.object(["action": .string("get"), "target": .string("measurements")]))
        XCTAssertEqual(sent[1], JSONValue.object([
            "action": .string("findDelay"),
            "target": .object(["measurementName": .string("TF")]),
            "properties": .array([
                .object(["automaticallyStart": .bool(true)]),
                .object(["automaticallyInsert": .bool(false)]),
                .object(["automaticallyStop": .bool(true)])
            ])
        ]))
    }

    func testMissingFinderLeavesImpulseForTheDelayRule() throws {
        let wire = ScriptedWire(replies: [
            #"{"transferFunctionMeasurements":[{"measurementName":"TF","active":true}]}"#,
            #"{"error":"not implemented"}"#,
            #"{"magnitude":[{"hz":1000,"db":0}],"impulse":{"sampleRate":48000,"samples":[0,0.1,-0.4,0.9,0.9]}}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        let capture = try session.readTrace()
        XCTAssertNil(capture.delayFinderMs)
        XCTAssertEqual(capture.magnitude.first?.phase, 0)
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(0.0625))
    }

    func testNoActiveTransferFunctionIsNoTrace() throws {
        let wire = ScriptedWire(replies: [
            #"{"spectrumMeasurements":[{"measurementName":"RTA","active":true}],"transferFunctionMeasurements":[]}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        XCTAssertThrowsError(try session.readTrace()) { error in
            XCTAssertEqual(error as? SmaartReaderError, .noTrace)
        }
    }

    func testTargetCurveAndMissingTarget() throws {
        let wire = ScriptedWire(replies: [
            #"{"points":[{"hz":100,"db":0},{"hz":1000,"db":-6}]}"#,
            #"{"error":"unknown target"}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        let points = try session.readTargetCurve()
        XCTAssertEqual(points, [
            MagnitudePoint(hz: 100, db: 0, phase: 0),
            MagnitudePoint(hz: 1000, db: -6, phase: 0)
        ])
        XCTAssertThrowsError(try session.readTargetCurve()) { error in
            XCTAssertEqual(error as? SmaartReaderError, .noTarget)
        }
    }

    func testAuthenticationRequiredDoesNotOpen() {
        let wire = ScriptedWire(replies: [#"{"error":"authentication required"}"#])
        let session = OfficialSmaartSession(wire: wire)
        XCTAssertThrowsError(try session.openSession())
        XCTAssertFalse(session.isSessionOpen)
    }

    func testReadBeforeOpenThrowsSessionClosed() {
        let session = OfficialSmaartSession(wire: ScriptedWire(replies: []))
        XCTAssertThrowsError(try session.readTrace()) { error in
            XCTAssertEqual(error as? SmaartReaderError, .sessionClosed)
        }
    }
}

enum JSONValue: Equatable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
}

extension JSONValue: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown JSON")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SessionTests`
Expected: FAIL. The build stops with `error: cannot find 'OfficialSmaartSession' in scope`.

- [ ] **Step 3: Write minimal implementation**

Delete `Sources/SmaartAPI/Placeholder.swift`.

`Sources/SmaartAPI/Session.swift`

```swift
import Foundation
import AutoSmaartCore

let smaartAPIURL = URL(string: "ws://127.0.0.1:26000/api/v4/")!

public enum SmaartReaderError: Error, Equatable {
    case noTrace
    case noTarget
    case sessionClosed
}

public protocol SmaartReader: AnyObject {
    func openSession() throws
    func closeSession()
    var isSessionOpen: Bool { get }
    func readTrace() throws -> SmaartCapture
    func readTargetCurve() throws -> [MagnitudePoint]
}

public protocol SmaartWire: AnyObject {
    func connect() throws
    func close()
    var isOpen: Bool { get }
    func send(_ text: String) throws
    func receive() throws -> String
}

public final class URLSessionSmaartWire: SmaartWire {
    private let task: URLSessionWebSocketTask
    private let session: URLSession
    private(set) var isOpen = false

    public init(url: URL = smaartAPIURL) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        session = URLSession(configuration: configuration)
        task = session.webSocketTask(with: url)
    }

    func connect() throws {
        task.resume()
        isOpen = true
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
        isOpen = false
    }

    func send(_ text: String) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var sendError: Error?
        task.send(.string(text)) { error in
            sendError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let sendError { throw sendError }
    }

    func receive() throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var received: Result<String, Error>?
        task.receive { result in
            switch result {
            case .success(let message):
                if case .string(let text) = message { received = .success(text) }
                else { received = .failure(SmaartReaderError.noTrace) }
            case .failure(let error):
                received = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        switch received {
        case .success(let text): return text
        case .failure(let error): throw error
        case .none: throw SmaartReaderError.noTrace
        }
    }
}

public final class OfficialSmaartSession: SmaartReader {
    private let wire: SmaartWire
    public private(set) var isSessionOpen = false

    public init(wire: SmaartWire) { self.wire = wire }

    public func openSession() throws {
        try wire.connect()
        let reply = try request(["action": "get", "target": "measurements"])
        if reply["error"] as? String == "authentication required" || reply["error"] as? String == "incorrect password" {
            wire.close()
            isSessionOpen = false
            throw SmaartReaderError.sessionClosed
        }
        isSessionOpen = true
    }

    public func closeSession() {
        wire.close()
        isSessionOpen = false
    }

    public func readTrace() throws -> SmaartCapture {
        guard isSessionOpen else { throw SmaartReaderError.sessionClosed }
        let measurements = try request(["action": "get", "target": "measurements"])
        let rows = measurements["transferFunctionMeasurements"] as? [[String: Any]] ?? []
        guard let name = rows.first(where: { $0["active"] as? Bool == true })?["measurementName"] as? String else {
            throw SmaartReaderError.noTrace
        }
        let finderReply = try request([
            "action": "findDelay",
            "target": ["measurementName": name],
            "properties": [
                ["automaticallyStart": true],
                ["automaticallyInsert": false],
                ["automaticallyStop": true]
            ]
        ])
        let body = try request(["action": "get", "target": ["measurementName": name]])
        let magnitude = magnitudePoints(body["magnitude"] as? [[String: Any]] ?? [])
        if magnitude.isEmpty { throw SmaartReaderError.noTrace }
        return SmaartCapture(
            magnitude: magnitude,
            delayFinderMs: number(finderReply["delayFinderMs"]),
            impulse: impulse(body["impulse"] as? [String: Any])
        )
    }

    public func readTargetCurve() throws -> [MagnitudePoint] {
        guard isSessionOpen else { throw SmaartReaderError.sessionClosed }
        let reply = try request(["action": "get", "target": "targetCurve"])
        if reply["error"] != nil { throw SmaartReaderError.noTarget }
        guard let rows = reply["points"] as? [[String: Any]] else { throw SmaartReaderError.noTarget }
        let points = rows.compactMap { row -> MagnitudePoint? in
            guard let hz = number(row["hz"]), let db = number(row["db"]) else { return nil }
            return MagnitudePoint(hz: hz, db: db, phase: 0)
        }
        if points.isEmpty { throw SmaartReaderError.noTarget }
        return points
    }

    private func request(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try wire.send(String(data: data, encoding: .utf8)!)
        let text = try wire.receive()
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8))
        return object as? [String: Any] ?? [:]
    }

    private func magnitudePoints(_ rows: [[String: Any]]) -> [MagnitudePoint] {
        rows.compactMap { row in
            guard let hz = number(row["hz"]), let db = number(row["db"]) else { return nil }
            return MagnitudePoint(hz: hz, db: db, phase: number(row["phase"]) ?? 0)
        }
    }

    private func impulse(_ object: [String: Any]?) -> Impulse? {
        guard let object, let sampleRate = number(object["sampleRate"]), let samples = numbers(object["samples"]) else {
            return nil
        }
        return Impulse(sampleRate: sampleRate, samples: samples)
    }

    private func number(_ value: Any?) -> Double? {
        if value is NSNull || value == nil { return nil }
        if let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() { return nil }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private func numbers(_ value: Any?) -> [Double]? {
        guard let rows = value as? [Any] else { return nil }
        return rows.compactMap { number($0) }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SessionTests`
Expected: PASS. Seven tests passed. The finder case sends `automaticallyInsert: false` and the delay rule returns 12.35, not the impulse time.

- [ ] **Step 5: Commit**

```bash
git add Sources/SmaartAPI Tests/SmaartAPITests
git commit -m "feat: read Smaart through the local API session"
```

---

### Task 4: Curve bank

**Files:**
- Create: `Sources/AutoSmaartCore/CurveBank.swift`
- Test: `Tests/AutoSmaartCoreTests/CurveBankTests.swift`

**Interfaces:**
- Consumes: `CurvePreset`, `CurveKind`, `MagnitudePoint`
- Produces:
  - `enum CurveBankError: Error, Equatable { case blankName }`
  - `public final class CurveBank { init(fileURL: URL); func reload() throws; private(set) var presets: [CurvePreset] { get }; func store(name: String, kind: CurveKind, points: [MagnitudePoint]) throws }`
  - `store` trims the name. An empty trimmed name throws `blankName` and does not change the file. A trimmed name that already exists replaces that row's `kind` and `points` and leaves the row where it is. A new name appends. `reload` from a new instance returns the same list.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AutoSmaartCore

final class CurveBankTests: XCTestCase {
    func testStoreRecallReplaceBlankAndRelaunch() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let bank = CurveBank(fileURL: url)
        let trace = [MagnitudePoint(hz: 100, db: -2, phase: 3)]
        let target = [MagnitudePoint(hz: 100, db: 0, phase: 9)]
        XCTAssertThrowsError(try bank.store(name: "   ", kind: .reference, points: trace)) { error in
            XCTAssertEqual(error as? CurveBankError, .blankName)
        }
        XCTAssertTrue(bank.presets.isEmpty)
        try bank.store(name: " Main ", kind: .reference, points: trace)
        try bank.store(name: "Main target", kind: .target, points: target)
        XCTAssertEqual(bank.presets.map(\.name), ["Main", "Main target"])
        try bank.store(name: "Main", kind: .target, points: target)
        XCTAssertEqual(bank.presets.count, 1 + 1)
        XCTAssertEqual(bank.presets[0].kind, .target)
        XCTAssertEqual(bank.presets[0].points, target)
        let reloaded = CurveBank(fileURL: url)
        try reloaded.reload()
        XCTAssertEqual(reloaded.presets, bank.presets)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CurveBankTests`
Expected: FAIL. The build stops with `error: cannot find 'CurveBank' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

public enum CurveBankError: Error, Equatable {
    case blankName
}

public final class CurveBank {
    private let fileURL: URL
    public private(set) var presets: [CurvePreset] = []

    public init(fileURL: URL) {
        self.fileURL = fileURL
        try? reload()
    }

    public func reload() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            presets = []
            return
        }
        let data = try Data(contentsOf: fileURL)
        presets = try JSONDecoder().decode([CurvePreset].self, from: data)
    }

    public func store(name: String, kind: CurveKind, points: [MagnitudePoint]) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw CurveBankError.blankName }
        if let index = presets.firstIndex(where: { $0.name == trimmed }) {
            presets[index].kind = kind
            presets[index].points = points
        } else {
            presets.append(CurvePreset(name: trimmed, kind: kind, points: points))
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(presets).write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CurveBankTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/AutoSmaartCore/CurveBank.swift Tests/AutoSmaartCoreTests/CurveBankTests.swift
git commit -m "feat: store the shared curve bank on disk"
```

---

### Task 5: Deterministic EQ fit

**Files:**
- Create: `Sources/AutoSmaartCore/Fit.swift`
- Create: `Tests/Fixtures/flat-within-1db.json`
- Create: `Tests/Fixtures/needs-eq.json`
- Create: `Tests/Fixtures/no-overlap.json`
- Test: `Tests/AutoSmaartCoreTests/FitTests.swift`

**Interfaces:**
- Consumes: `MagnitudePoint`, `EqBand`, `roundHalfAwayFromZero(_:places:)`
- Produces:
  - `enum FitResult: Equatable { case bands([EqBand]); case noOverlap }`
  - `func fitEq(measurement: [MagnitudePoint], preset: [MagnitudePoint]) -> FitResult`
  - `func peakingMagnitudeDb(binHz: Double, centerHz: Double, gainDb: Double, q: Double) -> Double`
  - `func formatFrequency(_ hz: Double) -> String`

Fit rules locked by the tests below:

- Sort measurement bins by frequency. Keep 20 Hz through 20 kHz inclusive.
- Sort preset points by frequency. When two preset points have the same frequency, the earlier input point wins and the later one is dropped.
- At a measurement frequency equal to a preset frequency, use that dB value. Between two preset points, `t = (ln(f) - ln(f0)) / (ln(f1) - ln(f0))` and dB is `d0 + t * (d1 - d0)`. Drop bins outside the preset span.
- Deviation = measurement dB − preset dB. Phase is not read.
- If no bins remain, `.noOverlap`. If the greatest absolute deviation is 1.0 or less, `.bands([])`.
- Choose the greatest absolute deviation. Ties go to the lower frequency. Gain = clamp(deviation × −1, −18, 18), then half-away to 0.1. The lobe is the contiguous run whose absolute deviation is at least half the chosen bin's absolute deviation. Equal `f_lo` and `f_hi` produce Q 4.00. Otherwise use the spec Q formula, clamp 0.10...20.00, half-away to 0.01.
- Subtract `peakingMagnitudeDb` at every remaining bin. Coefficients use `fs = 48000` and the band frequency. Evaluation at a bin uses `ω = 2π * binHz / 48000`. The same bin may be chosen again. Stop at 8 bands or when the chosen absolute deviation is 1.0 or less.
- `formatFrequency` rounds half away to 1 Hz when `hz < 1000`, including a result of `1000 Hz`. At 1000 Hz and above it prints kilohertz to two decimal places.

- [ ] **Step 1: Write the failing test**

`Tests/Fixtures/flat-within-1db.json`

```json
{"measurement":[{"hz":100,"db":1.0,"phase":0},{"hz":1000,"db":0.0,"phase":90}],"preset":[{"hz":100,"db":0,"phase":0},{"hz":1000,"db":0,"phase":0}]}
```

`Tests/Fixtures/needs-eq.json`

```json
{"measurement":[{"hz":100,"db":6.0,"phase":10},{"hz":1000,"db":0.0,"phase":0},{"hz":10000,"db":0.0,"phase":0}],"preset":[{"hz":100,"db":0,"phase":0},{"hz":1000,"db":0,"phase":0},{"hz":10000,"db":0,"phase":0}]}
```

`Tests/Fixtures/no-overlap.json`

```json
{"measurement":[{"hz":100,"db":6.0,"phase":0}],"preset":[{"hz":1000,"db":0,"phase":0},{"hz":2000,"db":0,"phase":0}]}
```

```swift
import XCTest
@testable import AutoSmaartCore

final class FitTests: XCTestCase {
    private struct Fixture: Decodable { var measurement: [MagnitudePoint]; var preset: [MagnitudePoint] }

    private func load(_ name: String) throws -> Fixture {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: try XCTUnwrap(url)))
    }

    func testInterpolationUsesNaturalLog() {
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: -6, phase: 40)]
        let measurement = [MagnitudePoint(hz: 316.22776601683796, db: 0, phase: 0)]
        let result = fitEq(measurement: measurement, preset: preset)
        guard case .bands(let bands) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(bands.first?.gainDb, -3.0, accuracy: 1e-9)
        XCTAssertEqual(bands.first?.hz ?? 0, 316.22776601683796, accuracy: 1e-6)
    }

    func testDuplicatePresetFrequencyKeepsTheFirstPoint() {
        let preset = [
            MagnitudePoint(hz: 100, db: 0, phase: 0),
            MagnitudePoint(hz: 100, db: 5, phase: 0),
            MagnitudePoint(hz: 1000, db: 0, phase: 0)
        ]
        let measurement = [MagnitudePoint(hz: 100, db: 0.2, phase: 0)]
        XCTAssertEqual(fitEq(measurement: measurement, preset: preset), .bands([]))
    }

    func testAbsoluteDeviationAtOrBelowOneProducesZeroBands() throws {
        let fixture = try load("flat-within-1db")
        XCTAssertEqual(fitEq(measurement: fixture.measurement, preset: fixture.preset), .bands([]))
        let justOver = [MagnitudePoint(hz: 100, db: 1.04, phase: 0)]
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        guard case .bands(let bands) = fitEq(measurement: justOver, preset: preset) else { return XCTFail("expected bands") }
        XCTAssertEqual(bands.first?.gainDb, -1.0, accuracy: 1e-9)
        XCTAssertEqual(bands.first?.q, 4.0, accuracy: 1e-9)
    }

    func testNeedsEqMatchesFrequencyGainAndQ() throws {
        let fixture = try load("needs-eq")
        guard case .bands(let bands) = fitEq(measurement: fixture.measurement, preset: fixture.preset) else {
            return XCTFail("expected bands")
        }
        XCTAssertEqual(bands.count, 8)
        XCTAssertEqual(bands[0].index, 1)
        XCTAssertEqual(bands[0].hz, 100, accuracy: 1e-9)
        XCTAssertEqual(bands[0].gainDb, -6.0, accuracy: 1e-9)
        XCTAssertEqual(bands[0].q, 4.0, accuracy: 1e-9)
        XCTAssertEqual(bands[1].hz, 100, accuracy: 1e-9)
        XCTAssertEqual(bands[1].gainDb, -12.0, accuracy: 1e-9)
        XCTAssertEqual(bands[1].q, 4.0, accuracy: 1e-9)
        XCTAssertEqual(bands[2].gainDb, -18.0, accuracy: 1e-9)
        XCTAssertEqual(bands[7].gainDb, -18.0, accuracy: 1e-9)
        XCTAssertEqual(bands[7].index, 8)
    }

    func testTieGoesToTheLowerFrequencyAndLobeSetsQ() {
        let measurement = [
            MagnitudePoint(hz: 800, db: -3, phase: 1),
            MagnitudePoint(hz: 200, db: 3, phase: 2)
        ]
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        guard case .bands(let bands) = fitEq(measurement: measurement, preset: preset) else { return XCTFail("expected bands") }
        XCTAssertEqual(bands[0].hz, 200, accuracy: 1e-9)
        XCTAssertEqual(bands[0].gainDb, -3.0, accuracy: 1e-9)
        XCTAssertEqual(bands[0].q, 0.67, accuracy: 1e-9)
        XCTAssertEqual(bands.count, 8)
    }

    func testPhaseDoesNotChangeTheBands() throws {
        let fixture = try load("needs-eq")
        let other = fixture.measurement.map { MagnitudePoint(hz: $0.hz, db: $0.db, phase: 123) }
        XCTAssertEqual(fitEq(measurement: fixture.measurement, preset: fixture.preset), fitEq(measurement: other, preset: fixture.preset))
    }

    func testSameInputsProduceTheSameBands() throws {
        let fixture = try load("needs-eq")
        XCTAssertEqual(
            fitEq(measurement: fixture.measurement, preset: fixture.preset),
            fitEq(measurement: fixture.measurement, preset: fixture.preset)
        )
    }

    func testNoOverlapAndOutOfBandBins() throws {
        let missing = try load("no-overlap")
        XCTAssertEqual(fitEq(measurement: missing.measurement, preset: missing.preset), .noOverlap)
        let measurement = [MagnitudePoint(hz: 19.999, db: 12, phase: 0), MagnitudePoint(hz: 20, db: 0.2, phase: 0)]
        let preset = [MagnitudePoint(hz: 10, db: 0, phase: 0), MagnitudePoint(hz: 20000, db: 0, phase: 0)]
        XCTAssertEqual(fitEq(measurement: measurement, preset: preset), .bands([]))
    }

    func testPeakingCenterUsesThe48kModel() {
        XCTAssertEqual(peakingMagnitudeDb(binHz: 100, centerHz: 100, gainDb: 6, q: 4), 6, accuracy: 1e-9)
        XCTAssertEqual(peakingMagnitudeDb(binHz: 200, centerHz: 100, gainDb: 6, q: 4), 0.1742005174966169, accuracy: 1e-9)
    }

    func testFrequencyLabels() {
        XCTAssertEqual(formatFrequency(80.4), "80 Hz")
        XCTAssertEqual(formatFrequency(80.5), "81 Hz")
        XCTAssertEqual(formatFrequency(999.5), "1000 Hz")
        XCTAssertEqual(formatFrequency(1000), "1.00 kHz")
        XCTAssertEqual(formatFrequency(3150), "3.15 kHz")
    }

    func testFitSourceHasNoRandomness() throws {
        let source = try String(contentsOfFile: "Sources/AutoSmaartCore/Fit.swift")
        XCTAssertFalse(source.contains("random"))
        XCTAssertFalse(source.contains("Double.random"))
        XCTAssertTrue(source.contains("48000"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FitTests`
Expected: FAIL. The build stops with `error: cannot find 'fitEq' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AutoSmaartCore/Fit.swift`

```swift
import Foundation

public enum FitResult: Equatable {
    case bands([EqBand])
    case noOverlap
}

public func formatFrequency(_ hz: Double) -> String {
    if hz < 1000 {
        return "\(Int(roundHalfAwayFromZero(hz, places: 0))) Hz"
    }
    let kilohertz = roundHalfAwayFromZero(hz / 1000.0, places: 2)
    return String(format: "%.2f kHz", kilohertz)
}

func peakingMagnitudeDb(binHz: Double, centerHz: Double, gainDb: Double, q: Double) -> Double {
    let fs = 48000.0
    let a = pow(10.0, gainDb / 40.0)
    let omega0 = 2.0 * Double.pi * centerHz / fs
    let alpha = sin(omega0) / (2.0 * q)
    let b0 = 1.0 + alpha * a
    let b1 = -2.0 * cos(omega0)
    let b2 = 1.0 - alpha * a
    let a0 = 1.0 + alpha / a
    let a1 = -2.0 * cos(omega0)
    let a2 = 1.0 - alpha / a
    let omega = 2.0 * Double.pi * binHz / fs
    let cosine1 = cos(omega)
    let sine1 = sin(omega)
    let cosine2 = cos(2.0 * omega)
    let sine2 = sin(2.0 * omega)
    let numeratorReal = b0 + b1 * cosine1 + b2 * cosine2
    let numeratorImag = -b1 * sine1 - b2 * sine2
    let denominatorReal = a0 + a1 * cosine1 + a2 * cosine2
    let denominatorImag = -a1 * sine1 - a2 * sine2
    let numerator = hypot(numeratorReal, numeratorImag)
    let denominator = hypot(denominatorReal, denominatorImag)
    return 20.0 * log10(numerator / denominator)
}

public func fitEq(measurement: [MagnitudePoint], preset: [MagnitudePoint]) -> FitResult {
    let bins = measurement.filter { $0.hz >= 20 && $0.hz <= 20000 }.sorted { $0.hz < $1.hz }
    let presetPoints = uniquePreset(preset)
    guard let first = presetPoints.first, let last = presetPoints.last else { return .noOverlap }
    var deviation: [(hz: Double, db: Double)] = []
    for bin in bins {
        guard let presetDb = interpolate(hz: bin.hz, preset: presetPoints, first: first.hz, last: last.hz) else { continue }
        deviation.append((bin.hz, bin.db - presetDb))
    }
    if deviation.isEmpty { return .noOverlap }
    if deviation.map({ abs($0.db) }.max() ?? 0 <= 1.0 { return .bands([]) }
    var bands: [EqBand] = []
    while bands.count < 8 {
        let chosen = deviation.indices.max { lhs, rhs in
            let left = abs(deviation[lhs].db)
            let right = abs(deviation[rhs].db)
            if left == right { return deviation[lhs].hz > deviation[rhs].hz }
            return left < right
        }!
        let center = deviation[chosen]
        if abs(center.db) <= 1.0 { break }
        let gain = roundHalfAwayFromZero(min(18.0, max(-18.0, -center.db)), places: 1)
        let half = abs(center.db) / 2.0
        var low = chosen
        while low > 0 && abs(deviation[low - 1].db) >= half { low -= 1 }
        var high = chosen
        while high < deviation.count - 1 && abs(deviation[high + 1].db) >= half { high += 1 }
        let q = quality(lowHz: deviation[low].hz, highHz: deviation[high].hz)
        bands.append(EqBand(index: bands.count + 1, hz: center.hz, gainDb: gain, q: q))
        for index in deviation.indices {
            deviation[index].db -= peakingMagnitudeDb(binHz: deviation[index].hz, centerHz: center.hz, gainDb: gain, q: q)
        }
    }
    return .bands(bands)
}

private func uniquePreset(_ preset: [MagnitudePoint]) -> [MagnitudePoint] {
    var firstIndex: [Double: Int] = [:]
    for (index, point) in preset.enumerated() where firstIndex[point.hz] == nil {
        firstIndex[point.hz] = index
    }
    return preset.enumerated()
        .filter { firstIndex[$0.element.hz] == $0.offset }
        .map(\.element)
        .sorted { $0.hz < $1.hz }
}

private func interpolate(hz: Double, preset: [MagnitudePoint], first: Double, last: Double) -> Double? {
    if hz < first || hz > last { return nil }
    if let exact = preset.first(where: { $0.hz == hz }) { return exact.db }
    for index in 0..<(preset.count - 1) {
        let left = preset[index]
        let right = preset[index + 1]
        if hz >= left.hz && hz <= right.hz {
            let t = (log(hz) - log(left.hz)) / (log(right.hz) - log(left.hz))
            return left.db + t * (right.db - left.db)
        }
    }
    return nil
}

private func quality(lowHz: Double, highHz: Double) -> Double {
    if lowHz == highHz { return 4.0 }
    let n = log2(highHz / lowHz)
    let raw = sqrt(pow(2.0, n)) / (pow(2.0, n) - 1.0)
    return roundHalfAwayFromZero(min(20.0, max(0.10, raw)), places: 2)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FitTests`
Expected: PASS. `needs-eq` produces eight bands. Band 1 is 100 Hz, gain −6.0, Q 4.00. Band 2 is 100 Hz, gain −12.0, Q 4.00. The 1.0 dB fixture produces zero bands. The no-overlap fixture returns `.noOverlap`.

- [ ] **Step 5: Commit**

```bash
git add Sources/AutoSmaartCore/Fit.swift Tests/AutoSmaartCoreTests/FitTests.swift Tests/Fixtures/flat-within-1db.json Tests/Fixtures/needs-eq.json Tests/Fixtures/no-overlap.json
git commit -m "feat: fit up to eight peaking bands deterministically"
```

---

### Task 6: OSC addresses and confirm transaction

**Files:**
- Create: `Sources/ConsoleOSC/OscMessage.swift`
- Create: `Sources/ConsoleOSC/Addresses.swift`
- Create: `Sources/ConsoleOSC/Confirm.swift`
- Delete: `Sources/ConsoleOSC/Placeholder.swift`
- Delete: `Tests/ConsoleOSCTests/EmptyTests.swift`
- Test: `Tests/ConsoleOSCTests/OscTests.swift`

**Interfaces:**
- Consumes: `OscValue`
- Produces:
  - `func encodeOsc(address: String, value: OscValue?) -> Data`
  - `func decodeOsc(_ data: Data) throws -> (address: String, value: OscValue?)`
  - `enum AddressError: Error, Equatable { case outputOutOfRange; case bandOutOfRange }`
  - `func delayAddresses(output: Int) throws -> (delay: String, fineDelay: String)`
  - `func eqAddresses(output: Int, band: Int) throws -> (freq: String, gain: String, q: String, on: String)`
  - `struct Replacement: Equatable { var address: String; var value: OscValue }`
  - `enum ConfirmError: Error, Equatable { case kept; case mismatch }`
  - `public protocol OscLink: AnyObject { func read(address: String) throws -> OscValue; func write(address: String, value: OscValue) throws }`
  - `func confirmReplace(_ items: [Replacement], link: OscLink) throws -> [Replacement]`
  - `func writeOnly(_ items: [Replacement], link: OscLink) throws`

`encodeOsc` with `value: nil` is a read query: address plus an empty type tag `,`. `confirmReplace` reads every address first. Any read error throws `.kept` and writes nothing. It then writes in order. On a write error it writes the read values back for the parameters whose writes were already accepted, and for no others. If every restore write is accepted it throws `.kept`; if a restore write throws it throws `.mismatch`. Success returns the read values in the same order. `writeOnly` does not read. If the first failing write is also the first write, it throws `.kept`. If an earlier write was accepted, it throws `.mismatch` and does not invent a restore read.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ConsoleOSC
@testable import AutoSmaartCore

final class MemoryLink: OscLink {
    var values: [String: OscValue]
    var log: [(String, String, OscValue?)] = []
    var failWriteAddresses: Set<String> = []
    var failRestoreAddresses: Set<String> = []
    private var writesAccepted: Set<String> = []
    init(values: [String: OscValue]) { self.values = values }
    public func read(address: String) throws -> OscValue {
        log.append(("read", address, nil))
        guard let value = values[address] else { throw LinkFailure.missing }
        return value
    }
    public func write(address: String, value: OscValue) throws {
        log.append(("write", address, value))
        if failWriteAddresses.contains(address) && !writesAccepted.contains(address) { throw LinkFailure.rejected }
        if failRestoreAddresses.contains(address) && writesAccepted.contains(address) { throw LinkFailure.rejected }
        values[address] = value
        writesAccepted.insert(address)
    }
}

enum LinkFailure: Error { case missing, rejected }

final class OscTests: XCTestCase {
    func testDelayQueryAndFloatZeroPacket() throws {
        let address = "/sd/Matrix_Outputs/1/Channel_Delay/delay"
        XCTAssertEqual(encodeOsc(address: address, value: nil).hex, "2f73642f4d61747269785f4f7574707574732f312f4368616e6e656c5f44656c61792f64656c6179000000002c000000")
        let packet = encodeOsc(address: address, value: .float32(0))
        XCTAssertEqual(packet.hex, "2f73642f4d61747269785f4f7574707574732f312f4368616e6e656c5f44656c61792f64656c6179000000002c66000000000000")
        let decoded = try decodeOsc(packet)
        XCTAssertEqual(decoded.address, address)
        XCTAssertEqual(decoded.value, .float32(0))
    }

    func testEqOnIntPacket() throws {
        let address = "/sd/Matrix_Outputs/1/EQ/eq_on_1"
        let packet = encodeOsc(address: address, value: .int32(1))
        XCTAssertEqual(packet.hex, "2f73642f4d61747269785f4f7574707574732f312f45512f65715f6f6e5f31002c69000000000001")
        XCTAssertEqual(try decodeOsc(packet).value, .int32(1))
    }

    func testAddressesRejectAnythingOutsideMatrixBandRange() throws {
        let delay = try delayAddresses(output: 1)
        XCTAssertEqual(delay.delay, "/sd/Matrix_Outputs/1/Channel_Delay/delay")
        XCTAssertEqual(delay.fineDelay, "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay")
        let eq = try eqAddresses(output: 12, band: 8)
        XCTAssertEqual(eq.freq, "/sd/Matrix_Outputs/12/EQ/eq_freq_8")
        XCTAssertEqual(eq.gain, "/sd/Matrix_Outputs/12/EQ/eq_gain_8")
        XCTAssertEqual(eq.q, "/sd/Matrix_Outputs/12/EQ/eq_Q_8")
        XCTAssertEqual(eq.on, "/sd/Matrix_Outputs/12/EQ/eq_on_8")
        XCTAssertThrowsError(try delayAddresses(output: 0))
        XCTAssertThrowsError(try delayAddresses(output: 13))
        XCTAssertThrowsError(try eqAddresses(output: 1, band: 0))
        XCTAssertThrowsError(try eqAddresses(output: 1, band: 9))
    }

    func testDriverSourceHasNoForbiddenAddress() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Sources/ConsoleOSC")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let source = try files.filter { $0.pathExtension == "swift" }.map { try String(contentsOf: $0) }.joined(separator: "\n")
        for forbidden in ["eq_curve", "dynamic_eq", "Input_Channels", "delay_on", "Graphic", "eq_in", "lock"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testConfirmReadsThenWritesAndReturnsTheRestoreCopy() throws {
        let delay = try delayAddresses(output: 1)
        let link = MemoryLink(values: [delay.delay: .float32(1.5), delay.fineDelay: .float32(2.5)])
        let sent = [
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ]
        let restore = try confirmReplace(sent, link: link)
        XCTAssertEqual(restore.map(\.value), [.float32(1.5), .float32(2.5)])
        XCTAssertEqual(link.log.map { $0.0 }, ["read", "read", "write", "write"])
        XCTAssertEqual(link.values[delay.delay], .float32(12.4))
    }

    func testReadFailureWritesNothing() throws {
        let delay = try delayAddresses(output: 1)
        let link = MemoryLink(values: [delay.delay: .float32(0)])
        XCTAssertThrowsError(try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: link)) { error in
            XCTAssertEqual(error as? ConfirmError, .kept)
        }
        XCTAssertEqual(link.log.map(\.0), ["read", "read"])
    }

    func testFailedLaterWriteRestoresOnlyWhatWasWritten() throws {
        let delay = try delayAddresses(output: 1)
        let link = MemoryLink(values: [delay.delay: .float32(0), delay.fineDelay: .float32(5)])
        link.failWriteAddresses = [delay.fineDelay]
        XCTAssertThrowsError(try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: link)) { error in
            XCTAssertEqual(error as? ConfirmError, .kept)
        }
        XCTAssertEqual(link.values[delay.delay], .float32(0))
        XCTAssertEqual(link.values[delay.fineDelay], .float32(5))
        XCTAssertEqual(link.log.filter { $0.0 == "write" }.map(\.1), [delay.delay, delay.fineDelay, delay.delay])
    }

    func testFailedRestoreIsMismatch() throws {
        let delay = try delayAddresses(output: 1)
        let link = MemoryLink(values: [delay.delay: .float32(0), delay.fineDelay: .float32(5)])
        link.failWriteAddresses = [delay.fineDelay]
        link.failRestoreAddresses = [delay.delay]
        XCTAssertThrowsError(try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: link)) { error in
            XCTAssertEqual(error as? ConfirmError, .mismatch)
        }
    }
}

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter OscTests`
Expected: FAIL. The build stops with `error: cannot find 'encodeOsc' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/ConsoleOSC/OscMessage.swift`

```swift
import Foundation
import AutoSmaartCore

enum OscCodecError: Error { case shortPacket, badType }

func encodeOsc(address: String, value: OscValue?) -> Data {
    var data = oscString(address)
    switch value {
    case nil:
        data.append(oscString(","))
    case .float32(let number):
        data.append(oscString(",f"))
        var big = number.bitPattern.bigEndian
        data.append(Data(bytes: &big, count: 4))
    case .int32(let number):
        data.append(oscString(",i"))
        var big = number.bigEndian
        data.append(Data(bytes: &big, count: 4))
    }
    return data
}

func decodeOsc(_ data: Data) throws -> (address: String, value: OscValue?) {
    var offset = 0
    let address = try readOscString(data, &offset)
    let tags = try readOscString(data, &offset)
    if tags == "," { return (address, nil) }
    if tags == ",f" {
        guard offset + 4 <= data.count else { throw OscCodecError.shortPacket }
        let bits = UInt32(bigEndian: data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self) })
        return (address, .float32(Float(bitPattern: bits)))
    }
    if tags == ",i" {
        guard offset + 4 <= data.count else { throw OscCodecError.shortPacket }
        let bits = Int32(bigEndian: data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: Int32.self) })
        return (address, .int32(bits))
    }
    throw OscCodecError.badType
}

private func oscString(_ text: String) -> Data {
    var data = Data(text.utf8)
    data.append(0)
    while data.count % 4 != 0 { data.append(0) }
    return data
}

private func readOscString(_ data: Data, _ offset: inout Int) throws -> String {
    guard let end = data[offset...].firstIndex(of: 0) else { throw OscCodecError.shortPacket }
    let text = String(data: data[offset..<end], encoding: .utf8) ?? ""
    offset = end + 1
    while offset % 4 != 0 { offset += 1 }
    return text
}
```

`Sources/ConsoleOSC/Addresses.swift`

```swift
import Foundation

enum AddressError: Error, Equatable {
    case outputOutOfRange
    case bandOutOfRange
}

public func delayAddresses(output: Int) throws -> (delay: String, fineDelay: String) {
    guard (1...12).contains(output) else { throw AddressError.outputOutOfRange }
    let prefix = "/sd/Matrix_Outputs/\(output)/Channel_Delay"
    return (prefix + "/delay", prefix + "/fine_delay")
}

public func eqAddresses(output: Int, band: Int) throws -> (freq: String, gain: String, q: String, on: String) {
    guard (1...12).contains(output) else { throw AddressError.outputOutOfRange }
    guard (1...8).contains(band) else { throw AddressError.bandOutOfRange }
    let prefix = "/sd/Matrix_Outputs/\(output)/EQ"
    return (prefix + "/eq_freq_\(band)", prefix + "/eq_gain_\(band)", prefix + "/eq_Q_\(band)", prefix + "/eq_on_\(band)")
}
```

`Sources/ConsoleOSC/Confirm.swift`

```swift
import Foundation
import AutoSmaartCore

public struct Replacement: Equatable {
    public var address: String
    public var value: OscValue
    public init(address: String, value: OscValue) {
        self.address = address
        self.value = value
    }
}

public enum ConfirmError: Error, Equatable {
    case kept
    case mismatch
}

public protocol OscLink: AnyObject {
    func read(address: String) throws -> OscValue
    func write(address: String, value: OscValue) throws
}

public func confirmReplace(_ items: [Replacement], link: OscLink) throws -> [Replacement] {
    var restore: [Replacement] = []
    for item in items {
        do {
            restore.append(Replacement(address: item.address, value: try link.read(address: item.address)))
        } catch {
            throw ConfirmError.kept
        }
    }
    var accepted = 0
    for item in items {
        do {
            try link.write(address: item.address, value: item.value)
            accepted += 1
        } catch {
            var restoreFailed = false
            for previous in restore.prefix(accepted) {
                do { try link.write(address: previous.address, value: previous.value) }
                catch { restoreFailed = true }
            }
            throw restoreFailed ? ConfirmError.mismatch : ConfirmError.kept
        }
    }
    return restore
}

public func writeOnly(_ items: [Replacement], link: OscLink) throws {
    var accepted = 0
    for item in items {
        do {
            try link.write(address: item.address, value: item.value)
            accepted += 1
        } catch {
            throw accepted == 0 ? ConfirmError.kept : ConfirmError.mismatch
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter OscTests`
Expected: PASS. The Matrix 1 delay float 0 packet matches `2f73642f4d61747269785f4f7574707574732f312f4368616e6e656c5f44656c61792f64656c6179000000002c66000000000000`. A failed fine-delay write restores only the delay address.

- [ ] **Step 5: Commit**

```bash
git add Sources/ConsoleOSC Tests/ConsoleOSCTests/OscTests.swift
git commit -m "feat: add Quantum 225 addresses and confirm restore"
```

---

### Task 7: UDP fake console

**Files:**
- Create: `Sources/ConsoleOSC/Quantum225Client.swift`
- Test: `Tests/ConsoleOSCTests/FakeConsoleTests.swift`

**Interfaces:**
- Consumes: `encodeOsc`, `decodeOsc`, `delayAddresses`, `eqAddresses`, `confirmReplace`, `OscValue`
- Produces: `public final class Quantum225Client: OscLink { init(host: String, port: UInt16, timeout: TimeInterval = 1.0) throws; func read(address: String) throws -> OscValue; func write(address: String, value: OscValue) throws; func close() }`

A write is accepted only when the next received packet has the same address and the same value. A read sends the address with no arguments and accepts the next packet on that address. Timeout is 1.0 second and throws `ConfirmError.kept` from the client by throwing `OscTransportError.notAccepted`. `confirmReplace` already maps any thrown error from `read` or `write` into `.kept` or `.mismatch`. The fake console is a real UDP socket on `127.0.0.1` with an ephemeral port. It records every datagram before this test calls confirm. Default stored values are float 0. A refused write does not change the stored value and does not reply.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import Darwin
@testable import ConsoleOSC
@testable import AutoSmaartCore

final class FakeQuantum225 {
    private var fd: Int32 = -1
    private var thread: Thread?
    private let lock = NSLock()
    private(set) var received: [Data] = []
    var values: [String: OscValue] = [:]
    var refuse: Set<String> = []
    let port: UInt16

    init() throws {
        fd = socket(AF_INET, SOCK_DGRAM, 0)
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        if bound != 0 { throw OscTransportError.notAccepted }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        port = UInt16(bigEndian: address.sin_port)
        thread = Thread { [weak self] in self?.loop() }
        thread?.start()
    }

    func stop() { close(fd) }

    private func loop() {
        var buffer = [UInt8](repeating: 0, count: 2048)
        while true {
            var sender = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &sender) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(fd, &buffer, buffer.count, 0, $0, &length) }
            }
            if count <= 0 { return }
            let data = Data(buffer.prefix(count))
            lock.lock(); received.append(data); lock.unlock()
            guard let message = try? decodeOsc(data) else { continue }
            if message.value == nil {
                let stored = values[message.address] ?? .float32(0)
                let reply = encodeOsc(address: message.address, value: stored)
                _ = reply.withUnsafeBytes { raw in
                    withUnsafePointer(to: &sender) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, raw.baseAddress, reply.count, 0, $0, length) }
                    }
                }
            } else if let value = message.value, !refuse.contains(message.address) {
                values[message.address] = value
                let reply = encodeOsc(address: message.address, value: value)
                _ = reply.withUnsafeBytes { raw in
                    withUnsafePointer(to: &sender) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, raw.baseAddress, reply.count, 0, $0, length) }
                    }
                }
            }
        }
    }
}

final class FakeConsoleTests: XCTestCase {
    func testNothingArrivesBeforeConfirmThenDelayAndEqMatchTheSpec() throws {
        let fake = try FakeQuantum225()
        defer { fake.stop() }
        let client = try Quantum225Client(host: "127.0.0.1", port: fake.port)
        defer { client.close() }
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertTrue(fake.received.isEmpty)
        let delay = try delayAddresses(output: 1)
        _ = try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: client)
        let delayPackets = fake.received.compactMap { try? decodeOsc($0) }
        XCTAssertEqual(delayPackets.map(\.address), [delay.delay, delay.delay, delay.fineDelay, delay.fineDelay])
        XCTAssertEqual(delayPackets.map(\.value), [nil, .float32(12.4), nil, .float32(12.4)])
        let beforeEq = fake.received.count
        let band = try eqAddresses(output: 1, band: 1)
        _ = try confirmReplace([
            Replacement(address: band.freq, value: .float32(100)),
            Replacement(address: band.gain, value: .float32(-6)),
            Replacement(address: band.q, value: .float32(4)),
            Replacement(address: band.on, value: .int32(1))
        ], link: client)
        let eqPackets = fake.received.dropFirst(beforeEq).compactMap { try? decodeOsc($0) }
        XCTAssertEqual(eqPackets.map(\.address), [band.freq, band.freq, band.gain, band.gain, band.q, band.q, band.on, band.on])
        XCTAssertFalse(eqPackets.map(\.address).contains(where: { $0.contains("eq_freq_2") }))
    }

    func testRefusedWriteIsNotASuccessAndTheStoredValueStays() throws {
        let fake = try FakeQuantum225()
        defer { fake.stop() }
        let delay = try delayAddresses(output: 1)
        fake.values[delay.delay] = .float32(1)
        fake.values[delay.fineDelay] = .float32(2)
        fake.refuse = [delay.fineDelay]
        let client = try Quantum225Client(host: "127.0.0.1", port: fake.port)
        defer { client.close() }
        XCTAssertThrowsError(try confirmReplace([
            Replacement(address: delay.delay, value: .float32(12.4)),
            Replacement(address: delay.fineDelay, value: .float32(12.4))
        ], link: client)) { error in
            XCTAssertEqual(error as? ConfirmError, .kept)
        }
        XCTAssertEqual(fake.values[delay.delay], .float32(1))
        XCTAssertEqual(fake.values[delay.fineDelay], .float32(2))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FakeConsoleTests`
Expected: FAIL. The build stops with `error: cannot find 'Quantum225Client' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/ConsoleOSC/Quantum225Client.swift`

```swift
import Foundation
import Darwin
import AutoSmaartCore

public enum OscTransportError: Error { case notAccepted, badHost }

public final class Quantum225Client: OscLink {
    private let fd: Int32
    private let timeout: TimeInterval
    private var destination = sockaddr_in()

    public init(host: String, port: UInt16, timeout: TimeInterval = 1.0) throws {
        self.timeout = timeout
        fd = socket(AF_INET, SOCK_DGRAM, 0)
        if fd < 0 { throw OscTransportError.notAccepted }
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = port.bigEndian
        if inet_aton(host, &destination.sin_addr) == 0 { throw OscTransportError.badHost }
        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - floor(timeout)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    public func close() { Darwin.close(fd) }

    public func read(address: String) throws -> OscValue {
        try send(encodeOsc(address: address, value: nil))
        let reply = try receive()
        guard reply.address == address, let value = reply.value else { throw OscTransportError.notAccepted }
        return value
    }

    public func write(address: String, value: OscValue) throws {
        try send(encodeOsc(address: address, value: value))
        let reply = try receive()
        guard reply.address == address, reply.value == value else { throw OscTransportError.notAccepted }
    }

    private func send(_ data: Data) throws {
        let result = data.withUnsafeBytes { raw in
            withUnsafePointer(to: &destination) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, raw.baseAddress, data.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
        }
        if result < 0 { throw OscTransportError.notAccepted }
    }

    private func receive() throws -> (address: String, value: OscValue?) {
        var buffer = [UInt8](repeating: 0, count: 2048)
        let count = recv(fd, &buffer, buffer.count, 0)
        if count <= 0 { throw OscTransportError.notAccepted }
        return try decodeOsc(Data(buffer.prefix(count)))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FakeConsoleTests`
Expected: PASS. `received` is empty before `confirmReplace`. The delay confirm is query, write, query, write on `delay` then `fine_delay`, both writes carrying float 12.4. The EQ confirm never contains `eq_freq_2`. The refused fine-delay write leaves the stored floats at 1 and 2.

- [ ] **Step 5: Commit**

```bash
git add Sources/ConsoleOSC/Quantum225Client.swift Tests/ConsoleOSCTests/FakeConsoleTests.swift
git commit -m "feat: speak Quantum 225 delay and EQ over UDP"
```

---
### Task 8: Pass read, bank, and navigation

**Files:**
- Create: `Sources/AutoSmaartPass/OutputStore.swift`
- Create: `Sources/AutoSmaartPass/Pass.swift`
- Create: `Tests/AutoSmaartPassTests/PassFixtures.swift`
- Create: `Tests/AutoSmaartPassTests/PassReadTests.swift`
- Modify: `Package.swift`

**Interfaces:**
- Consumes: `SmaartReader`, `SmaartCapture`, `SmaartReaderError`, `delaySuggestion(of:)`, `displayedDelayMs(_:)`, `CurveBank`, `CurvePreset`, `OscLink`, `MagnitudePoint`
- Produces:
  - `struct DelaySnapshot: Equatable, Codable { var delay: OscValue; var fineDelay: OscValue }`
  - `struct EqBandSnapshot: Equatable, Codable { var index: Int; var freq: OscValue; var gain: OscValue; var q: OscValue; var on: OscValue }`
  - `struct MatrixOutputRecord: Equatable, Codable { var index: Int; var displayName: String; var lastWrite: String?; var delaySnapshot: DelaySnapshot?; var eqSnapshot: [EqBandSnapshot]? }`
  - `public enum PassStep: Equatable { case pick, delay, eq, compare }`
  - `public enum PassNotice: Equatable { case none, noSmaartTrace, noDelaySuggestion, noSmaartTarget, presetNoOverlap, couldNotRemeasure, writeFailedKept, writeFailedMismatch, noEqNeeded, noEqWritten }`
  - `struct PassState: Equatable`
  - `final class OutputStore`
  - `final class PassController: ObservableObject`
  - `PassController` methods: `setHost(_:)`, `setPort(_:)`, `setDraftName(_:)`, `selectOutput(_:)`, `setDisplayName(_:output:)`, `recall(name:)`, `storeTarget()`, `storeTrace()`, `readTrace()`, `back()`, `openRail(_:)`, `canOpen(_:) -> Bool`, `reloadFromStores()`, `refreshSessionFlag()`
  - Test helper: `@MainActor func makePass(traces: [SmaartCapture], target: [MagnitudePoint]?, link: RecordingLink) -> (PassController, ScriptedReader, RecordingLink, URL)` and `@MainActor func prepare(_ pass: PassController, points: [MagnitudePoint]) throws`

`PassState` fields: `step`, `host`, `port`, `draftName`, `selectedOutput`, `passPresetName`, `outputs`, `presets`, `latestMagnitude`, `suggestionRaw`, `displayedDelayMs`, `postDelayMagnitude`, `bands`, `beforeCurve`, `afterCurve`, `notice`, `smaartLive`, `delayWrittenThisPass`, `compareOpen`, `eqRemeasureFailed`. A new controller has twelve outputs, blank display names, nil last-write, nil snapshots, empty host and port, and step Pick.

- [ ] **Step 1: Write the failing test**

Add the pass targets to `Package.swift` and keep every target already there:

```swift
.target(name: "AutoSmaartPass", dependencies: ["AutoSmaartCore", "ConsoleOSC"]),
.testTarget(
    name: "AutoSmaartPassTests",
    dependencies: ["AutoSmaartPass"],
    resources: [.copy("../Fixtures")]
),
```

`Tests/AutoSmaartPassTests/PassFixtures.swift`

```swift
import XCTest
import AutoSmaartCore
import ConsoleOSC
@testable import AutoSmaartPass

final class ScriptedReader: SmaartReader {
    var isSessionOpen: Bool
    var traces: [SmaartCapture]
    var target: [MagnitudePoint]?
    private(set) var traceReads = 0

    init(traces: [SmaartCapture], target: [MagnitudePoint]? = nil, open: Bool = true) {
        self.traces = traces
        self.target = target
        self.isSessionOpen = open
    }

    func openSession() throws { isSessionOpen = true }
    func closeSession() { isSessionOpen = false }

    func readTrace() throws -> SmaartCapture {
        traceReads += 1
        guard !traces.isEmpty else { throw SmaartReaderError.noTrace }
        return traces.removeFirst()
    }

    func readTargetCurve() throws -> [MagnitudePoint] {
        guard let target, !target.isEmpty else { throw SmaartReaderError.noTarget }
        return target
    }
}

final class RecordingLink: OscLink {
    var values: [String: OscValue]
    private(set) var log: [(op: String, address: String, value: OscValue?)] = []
    var failAddresses: Set<String> = []

    init(values: [String: OscValue] = [:]) { self.values = values }

    func read(address: String) throws -> OscValue {
        log.append(("read", address, nil))
        if failAddresses.contains(address) { throw OscTransportError.notAccepted }
        return values[address] ?? .float32(0)
    }

    func write(address: String, value: OscValue) throws {
        log.append(("write", address, value))
        if failAddresses.contains(address) { throw OscTransportError.notAccepted }
        values[address] = value
    }
}

@MainActor
func makePass(
    traces: [SmaartCapture],
    target: [MagnitudePoint]? = nil,
    link: RecordingLink = RecordingLink()
) -> (PassController, ScriptedReader, RecordingLink, URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let reader = ScriptedReader(traces: traces, target: target)
    let bank = CurveBank(fileURL: directory.appendingPathComponent("bank.json"))
    let outputs = OutputStore(fileURL: directory.appendingPathComponent("outputs.json"))
    let pass = PassController(reader: reader, link: link, bank: bank, outputs: outputs)
    return (pass, reader, link, directory)
}

@MainActor
func prepare(_ pass: PassController, points: [MagnitudePoint]) throws {
    try pass.storePreparedPreset(name: "Main", kind: .reference, points: points)
    try pass.storePreparedPreset(name: "Other", kind: .target, points: points)
    pass.setHost("10.0.0.8")
    pass.setPort("8000")
    pass.selectOutput(1)
    pass.recall(name: "Main")
}

func capture(magnitude: [MagnitudePoint], finder: Double?, impulse: Impulse? = nil) -> SmaartCapture {
    SmaartCapture(magnitude: magnitude, delayFinderMs: finder, impulse: impulse)
}
```

`Tests/AutoSmaartPassTests/PassReadTests.swift`

```swift
import XCTest
import AutoSmaartCore
@testable import AutoSmaartPass

@MainActor
final class PassReadTests: XCTestCase {
    func testTwelveBlankOutputsAndNoOSCOnRead() throws {
        let point = MagnitudePoint(hz: 1000, db: -3, phase: 15)
        let (pass, _, link, _) = makePass(traces: [capture(magnitude: [point], finder: 12.35)])
        XCTAssertEqual(pass.state.outputs.count, 12)
        XCTAssertEqual(pass.state.outputs.map(\.index), Array(1...12))
        XCTAssertTrue(pass.state.outputs.allSatisfy { $0.displayName.isEmpty && $0.lastWrite == nil && $0.delaySnapshot == nil })
        XCTAssertEqual(pass.state.host, "")
        XCTAssertEqual(pass.state.port, "")
        let bank = CurveBank(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        try bank.store(name: "Main", kind: .reference, points: [point])
        pass.reloadFromStores()
        pass.setHost("10.0.0.8")
        pass.setPort("8000")
        pass.selectOutput(1)
        pass.recall(name: "Main")
        pass.readTrace()
        pass.back()
        pass.openRail(.delay)
        pass.openRail(.eq)
        pass.openRail(.compare)
        XCTAssertTrue(link.log.isEmpty)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertEqual(pass.state.displayedDelayMs, 12.4)
        XCTAssertEqual(pass.state.latestMagnitude?.first?.phase, 15)
        XCTAssertFalse(pass.canOpen(.eq))
        XCTAssertNil(pass.state.bands)
    }

    func testNeitherFixtureStaysOnPick() throws {
        let url = Bundle.module.url(forResource: "neither", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "neither", withExtension: "json")
        let neither = try JSONDecoder().decode(SmaartCapture.self, from: Data(contentsOf: try XCTUnwrap(url)))
        let (pass, _, link, _) = makePass(traces: [neither])
        try prepare(pass, points: neither.magnitude)
        pass.readTrace()
        XCTAssertEqual(pass.state.step, .pick)
        XCTAssertEqual(pass.state.notice, .noDelaySuggestion)
        XCTAssertEqual(pass.state.latestMagnitude, neither.magnitude)
        XCTAssertTrue(link.log.isEmpty)
        XCTAssertFalse(pass.canOpen(.delay))
    }

    func testMissingMagnitudeStaysOnPickWithoutASuggestion() throws {
        let url = Bundle.module.url(forResource: "no-magnitude", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "no-magnitude", withExtension: "json")
        let missing = try JSONDecoder().decode(SmaartCapture.self, from: Data(contentsOf: try XCTUnwrap(url)))
        let (pass, _, link, _) = makePass(traces: [missing])
        try prepare(pass, points: [MagnitudePoint(hz: 100, db: 0, phase: 0)])
        pass.readTrace()
        XCTAssertEqual(pass.state.notice, .noSmaartTrace)
        XCTAssertEqual(pass.state.step, .pick)
        XCTAssertNil(pass.state.latestMagnitude)
        XCTAssertNil(pass.state.suggestionRaw)
        XCTAssertTrue(link.log.isEmpty)
    }

    func testStoreTargetStoreTraceBlankNameAndReplace() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 1)
        let target = [MagnitudePoint(hz: 100, db: -1, phase: 0)]
        let (pass, _, _, directory) = makePass(traces: [capture(magnitude: [point], finder: nil)], target: target)
        pass.setDraftName("   ")
        pass.storeTarget()
        XCTAssertTrue(pass.state.presets.isEmpty)
        pass.setDraftName("Main target")
        pass.storeTarget()
        XCTAssertEqual(pass.state.presets.first?.kind, .target)
        pass.storeTrace()
        XCTAssertEqual(pass.state.notice, .noSmaartTrace)
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.setDraftName("Main")
        pass.storeTrace()
        XCTAssertEqual(pass.state.presets.first { $0.name == "Main" }?.kind, .reference)
        pass.setDraftName("Main")
        pass.storeTarget()
        XCTAssertEqual(pass.state.presets.filter { $0.name == "Main" }.count, 1)
        XCTAssertEqual(pass.state.presets.first { $0.name == "Main" }?.kind, .target)
        let reloaded = CurveBank(fileURL: directory.appendingPathComponent("bank.json"))
        try reloaded.reload()
        XCTAssertEqual(reloaded.presets.first { $0.name == "Main" }?.kind, .target)
    }

    func testRecallOfTheCurrentPresetDoesNotResetThePass() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let (pass, _, _, _) = makePass(traces: [capture(magnitude: [point], finder: 4)])
        try prepare(pass, points: [point])
        pass.readTrace()
        XCTAssertEqual(pass.state.step, .delay)
        pass.back()
        pass.recall(name: "Main")
        XCTAssertEqual(pass.state.suggestionRaw, 4)
        pass.recall(name: "Other")
        XCTAssertEqual(pass.state.passPresetName, "Other")
        XCTAssertEqual(pass.state.step, .pick)
        XCTAssertNil(pass.state.suggestionRaw)
    }

    func testChangingOutputStartsAnotherPassWithoutOSC() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let (pass, _, link, _) = makePass(traces: [capture(magnitude: [point], finder: 4)])
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.selectOutput(2)
        XCTAssertEqual(pass.state.step, .pick)
        XCTAssertNil(pass.state.suggestionRaw)
        XCTAssertEqual(pass.state.selectedOutput, 2)
        XCTAssertTrue(link.log.isEmpty)
    }

    func testNoTargetCurveNotice() {
        let (pass, _, _, _) = makePass(traces: [])
        pass.setDraftName("Missing")
        pass.storeTarget()
        XCTAssertEqual(pass.state.notice, .noSmaartTarget)
        XCTAssertTrue(pass.state.presets.isEmpty)
    }
}

```

- [ ] **Step 2: Run test to verify it fails**

Run from the repository root: `swift test --filter PassReadTests`
Expected: FAIL. The build stops with `error: cannot find 'PassController' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AutoSmaartPass/OutputStore.swift`

```swift
import Foundation
import AutoSmaartCore

public struct DelaySnapshot: Equatable, Codable {
    public var delay: OscValue
    public var fineDelay: OscValue
    public init(delay: OscValue, fineDelay: OscValue) {
        self.delay = delay
        self.fineDelay = fineDelay
    }
}

public struct EqBandSnapshot: Equatable, Codable {
    public var index: Int
    public var freq: OscValue
    public var gain: OscValue
    public var q: OscValue
    public var on: OscValue
    public init(index: Int, freq: OscValue, gain: OscValue, q: OscValue, on: OscValue) {
        self.index = index
        self.freq = freq
        self.gain = gain
        self.q = q
        self.on = on
    }
}

public struct MatrixOutputRecord: Equatable, Codable {
    public var index: Int
    public var displayName: String
    public var lastWrite: String?
    public var delaySnapshot: DelaySnapshot?
    public var eqSnapshot: [EqBandSnapshot]?
    public init(index: Int, displayName: String, lastWrite: String?, delaySnapshot: DelaySnapshot?, eqSnapshot: [EqBandSnapshot]?) {
        self.index = index
        self.displayName = displayName
        self.lastWrite = lastWrite
        self.delaySnapshot = delaySnapshot
        self.eqSnapshot = eqSnapshot
    }
}

public final class OutputStore {
    private let fileURL: URL
    public private(set) var outputs: [MatrixOutputRecord]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([MatrixOutputRecord].self, from: data),
           decoded.count == 12 {
            outputs = decoded
        } else {
            outputs = (1...12).map {
                MatrixOutputRecord(index: $0, displayName: "", lastWrite: nil, delaySnapshot: nil, eqSnapshot: nil)
            }
        }
    }

    public func save(_ outputs: [MatrixOutputRecord]) throws {
        self.outputs = outputs
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(outputs).write(to: fileURL, options: .atomic)
    }
}
```

`Sources/AutoSmaartPass/Pass.swift`

```swift
import Foundation
import Combine
import AutoSmaartCore
import ConsoleOSC

public enum PassStep: Equatable { case pick, delay, eq, compare }

public enum PassNotice: Equatable {
    case none
    case noSmaartTrace
    case noDelaySuggestion
    case noSmaartTarget
    case presetNoOverlap
    case couldNotRemeasure
    case writeFailedKept
    case writeFailedMismatch
    case noEqNeeded
    case noEqWritten
}

public struct PassState: Equatable {
    public var step: PassStep = .pick
    public var host = ""
    public var port = ""
    public var draftName = ""
    public var selectedOutput: Int?
    public var passPresetName: String?
    public var outputs: [MatrixOutputRecord] = []
    public var presets: [CurvePreset] = []
    public var latestMagnitude: [MagnitudePoint]?
    public var suggestionRaw: Double?
    public var displayedDelayMs: Double?
    public var postDelayMagnitude: [MagnitudePoint]?
    public var bands: [EqBand]?
    public var beforeCurve: [MagnitudePoint]?
    public var afterCurve: [MagnitudePoint]?
    public var notice: PassNotice = .none
    public var smaartLive = false
    public var delayWrittenThisPass = false
    public var compareOpen = false
    public var eqRemeasureFailed = false

    public init() {}
}


public protocol ConsoleEndpoint: AnyObject {
    func update(host: String, port: String)
}

public final class PassController: ObservableObject {
    @Published public fileprivate(set) var state: PassState
    fileprivate let reader: SmaartReader
    fileprivate let link: OscLink
    private let bank: CurveBank
    fileprivate let outputs: OutputStore
    public weak var endpoint: ConsoleEndpoint?

    public init(reader: SmaartReader, link: OscLink, bank: CurveBank, outputs: OutputStore) {
        self.reader = reader
        self.link = link
        self.bank = bank
        self.outputs = outputs
        var initial = PassState()
        initial.presets = bank.presets
        initial.outputs = outputs.outputs
        initial.smaartLive = reader.isSessionOpen
        state = initial
    }

    public func setHost(_ host: String) { state.host = host; endpoint?.update(host: state.host, port: state.port) }
    public func setPort(_ port: String) { state.port = port; endpoint?.update(host: state.host, port: state.port) }
    public func setDraftName(_ name: String) { state.draftName = name }

    public func refreshSessionFlag() { state.smaartLive = reader.isSessionOpen }

    func reloadFromStores() {
        try? bank.reload()
        state.presets = bank.presets
        state.outputs = outputs.outputs
    }

    func storePreparedPreset(name: String, kind: CurveKind, points: [MagnitudePoint]) throws {
        try bank.store(name: name, kind: kind, points: points)
        state.presets = bank.presets
    }

    public func selectOutput(_ index: Int) {
        guard (1...12).contains(index) else { return }
        if state.selectedOutput == index { return }
        state.selectedOutput = index
        clearPassProgress()
    }

    public func setDisplayName(_ name: String, output: Int) {
        guard (1...12).contains(output) else { return }
        state.outputs[output - 1].displayName = name
        try? outputs.save(state.outputs)
    }

    public func recall(name: String) {
        guard state.presets.contains(where: { $0.name == name }) else { return }
        if state.passPresetName == name { return }
        state.passPresetName = name
        clearPassProgress()
    }

    public func storeTarget() {
        do {
            let points = try reader.readTargetCurve()
            try bank.store(name: state.draftName, kind: .target, points: points)
            state.presets = bank.presets
            state.notice = .none
        } catch is CurveBankError {
            return
        } catch {
            state.notice = .noSmaartTarget
        }
    }

    public func storeTrace() {
        guard let latest = state.latestMagnitude, !latest.isEmpty else {
            state.notice = .noSmaartTrace
            return
        }
        do {
            try bank.store(name: state.draftName, kind: .reference, points: latest)
            state.presets = bank.presets
            state.notice = .none
        } catch {
            return
        }
    }

    public func readTrace() {
        guard state.selectedOutput != nil, state.passPresetName != nil, !state.host.isEmpty, !state.port.isEmpty else { return }
        let capture: SmaartCapture
        do {
            capture = try reader.readTrace()
        } catch {
            refuseTrace()
            return
        }
        if capture.magnitude.isEmpty {
            refuseTrace()
            return
        }
        state.latestMagnitude = capture.magnitude
        switch delaySuggestion(of: capture) {
        case .none:
            state.suggestionRaw = nil
            state.displayedDelayMs = nil
            state.bands = nil
            state.compareOpen = false
            state.notice = .noDelaySuggestion
            state.step = .pick
        case .milliseconds(let raw):
            state.suggestionRaw = raw
            state.displayedDelayMs = displayedDelayMs(raw)
            state.bands = nil
            state.postDelayMagnitude = nil
            state.beforeCurve = nil
            state.afterCurve = nil
            state.compareOpen = false
            state.delayWrittenThisPass = false
            state.eqRemeasureFailed = false
            state.notice = .none
            state.step = .delay
        }
    }

    public func back() {
        if state.step == .delay { state.step = .pick }
    }

    public func canOpen(_ step: PassStep) -> Bool {
        switch step {
        case .pick: return true
        case .delay: return state.suggestionRaw != nil
        case .eq: return state.bands != nil
        case .compare: return state.compareOpen
        }
    }

    public func openRail(_ step: PassStep) {
        guard canOpen(step) else { return }
        state.step = step
    }

    private func refuseTrace() {
        state.notice = .noSmaartTrace
        state.step = .pick
        state.suggestionRaw = nil
        state.displayedDelayMs = nil
    }

    private func clearPassProgress() {
        state.suggestionRaw = nil
        state.displayedDelayMs = nil
        state.latestMagnitude = nil
        state.postDelayMagnitude = nil
        state.bands = nil
        state.beforeCurve = nil
        state.afterCurve = nil
        state.notice = .none
        state.delayWrittenThisPass = false
        state.compareOpen = false
        state.eqRemeasureFailed = false
        state.step = .pick
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run from the repository root: `swift test --filter PassReadTests`
Expected: PASS. The finder read unlocks Delay at 12.4 ms and the link log is empty. `neither.json` stays on Pick with `.noDelaySuggestion` and keeps the magnitude. `no-magnitude.json` stays on Pick with `.noSmaartTrace` and does not keep a magnitude. EQ and Compare stay locked.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/AutoSmaartPass Tests/AutoSmaartPassTests
git commit -m "feat: unlock Delay only after a Smaart suggestion"
```

---

### Task 9: Delay confirm and remeasure

**Files:**
- Modify: `Sources/AutoSmaartPass/Pass.swift`
- Test: `Tests/AutoSmaartPassTests/PassDelayTests.swift`

**Interfaces:**
- Consumes: `confirmReplace(_:link:)`, `delayAddresses(output:)`, `fitEq(measurement:preset:)`, `ConfirmError`, `PassController`, `makePass`, `prepare`
- Produces: `PassController.confirmDelay()`, `PassController.retryRemeasure()`. Both are methods on the existing class, appended in the same file.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import AutoSmaartCore
import ConsoleOSC
@testable import AutoSmaartPass

@MainActor
final class PassDelayTests: XCTestCase {
    func testConfirmSendsTheDisplayedNumberOnBothAddresses() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let link = RecordingLink(values: [
            "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(1.5),
            "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(2.5)
        ])
        let remeasure = capture(magnitude: [point], finder: 1)
        let (pass, _, _, _) = makePass(traces: [capture(magnitude: [point], finder: 12.35), remeasure], link: link)
        try prepare(pass, points: [point])
        pass.readTrace()
        XCTAssertEqual(pass.state.displayedDelayMs, 12.4)
        let writesBefore = link.log.count
        pass.confirmDelay()
        let delay = try delayAddresses(output: 1)
        let writes = link.log.filter { $0.op == "write" }
        XCTAssertEqual(writes.map(\.address), [delay.delay, delay.fineDelay])
        XCTAssertEqual(writes.map(\.value), [.float32(Float(12.4)), .float32(Float(12.4))])
        XCTAssertEqual(pass.state.outputs[0].delaySnapshot?.delay, .float32(1.5))
        XCTAssertEqual(pass.state.outputs[0].delaySnapshot?.fineDelay, .float32(2.5))
        XCTAssertTrue(pass.state.delayWrittenThisPass)
        XCTAssertGreaterThan(link.log.count, writesBefore)
        XCTAssertNil(pass.state.outputs[0].lastWrite)
    }

    func testNegativeSuggestionIsNotClamped() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let link = RecordingLink()
        let (pass, _, _, _) = makePass(
            traces: [capture(magnitude: [point], finder: -1.25), capture(magnitude: [point], finder: 0)],
            link: link
        )
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.confirmDelay()
        let writes = link.log.filter { $0.op == "write" }
        XCTAssertEqual(writes.map(\.value), [.float32(Float(-1.3)), .float32(Float(-1.3))])
    }

    func testMatchingPreviousValueStillRequiresConfirm() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let (pass, _, link, _) = makePass(
            traces: [capture(magnitude: [point], finder: 12.35), capture(magnitude: [point], finder: 1)],
            link: RecordingLink(values: [
                "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(12.4),
                "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(12.4)
            ])
        )
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.openRail(.eq)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertNil(pass.state.bands)
        pass.confirmDelay()
        XCTAssertEqual(pass.state.step, .eq)
        XCTAssertFalse(link.log.isEmpty)
    }

    func testFailedReadWritesNothingAndKeepsTheSnapshot() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let link = RecordingLink()
        link.failAddresses = ["/sd/Matrix_Outputs/1/Channel_Delay/fine_delay"]
        let (pass, reader, _, _) = makePass(traces: [capture(magnitude: [point], finder: 4)], link: link)
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.notice, .writeFailedKept)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertNil(pass.state.outputs[0].delaySnapshot)
        XCTAssertFalse(pass.state.delayWrittenThisPass)
        XCTAssertEqual(reader.traceReads, 1)
        XCTAssertTrue(link.log.allSatisfy { $0.op == "read" })
    }

    func testInvalidPortDoesNotSend() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let (pass, _, link, _) = makePass(traces: [capture(magnitude: [point], finder: 4)])
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.setPort("abc")
        pass.confirmDelay()
        XCTAssertEqual(pass.state.notice, .writeFailedKept)
        XCTAssertTrue(link.log.isEmpty)
    }

    func testRemeasureFailureStaysOnDelayAndRetryDoesNotWrite() throws {
        let point = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let preset = [MagnitudePoint(hz: 20, db: 0, phase: 0), MagnitudePoint(hz: 20000, db: 0, phase: 0)]
        let (pass, reader, link, _) = makePass(traces: [
            capture(magnitude: [point], finder: 4),
            capture(magnitude: [], finder: 4),
            capture(magnitude: [point], finder: 4)
        ])
        try prepare(pass, points: preset)
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.notice, .couldNotRemeasure)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertTrue(pass.state.delayWrittenThisPass)
        XCTAssertNil(pass.state.bands)
        let writes = link.log.filter { $0.op == "write" }.count
        pass.retryRemeasure()
        XCTAssertEqual(link.log.filter { $0.op == "write" }.count, writes)
        XCTAssertEqual(pass.state.step, .eq)
        XCTAssertEqual(reader.traceReads, 3)
        XCTAssertEqual(pass.state.bands?.first?.hz, 100)
    }

    func testPresetThatDoesNotOverlapStaysOnDelay() throws {
        let first = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let outside = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let preset = [MagnitudePoint(hz: 1000, db: 0, phase: 0), MagnitudePoint(hz: 2000, db: 0, phase: 0)]
        let (pass, _, link, _) = makePass(traces: [
            capture(magnitude: [first], finder: 4),
            capture(magnitude: [outside], finder: 4)
        ])
        try prepare(pass, points: preset)
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.notice, .presetNoOverlap)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertNil(pass.state.bands)
        XCTAssertFalse(pass.canOpen(.eq))
        XCTAssertEqual(link.log.filter { $0.op == "write" }.count, 2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from the repository root: `swift test --filter PassDelayTests`
Expected: FAIL. The build stops with `error: value of type 'PassController' has no member 'confirmDelay'`.

- [ ] **Step 3: Write minimal implementation**

Append this extension to the end of `Sources/AutoSmaartPass/Pass.swift`:

```swift
extension PassController {
    public func confirmDelay() {
        guard state.step == .delay, let shown = state.displayedDelayMs, let output = state.selectedOutput else { return }
        guard !state.host.isEmpty, UInt16(state.port) != nil else {
            state.notice = .writeFailedKept
            return
        }
        let addresses: (delay: String, fineDelay: String)
        do { addresses = try delayAddresses(output: output) } catch { return }
        let value = OscValue.float32(Float(shown))
        do {
            let restore = try confirmReplace([
                Replacement(address: addresses.delay, value: value),
                Replacement(address: addresses.fineDelay, value: value)
            ], link: link)
            state.outputs[output - 1].delaySnapshot = DelaySnapshot(delay: restore[0].value, fineDelay: restore[1].value)
            try? outputs.save(state.outputs)
            state.delayWrittenThisPass = true
            state.notice = .none
            remeasureAfterDelay()
        } catch let error as ConfirmError {
            state.notice = error == .mismatch ? .writeFailedMismatch : .writeFailedKept
        } catch {
            state.notice = .writeFailedKept
        }
    }

    public func retryRemeasure() {
        guard state.step == .delay, state.delayWrittenThisPass, state.notice == .couldNotRemeasure else { return }
        remeasureAfterDelay()
    }

    fileprivate func remeasureAfterDelay() {
        let capture: SmaartCapture
        do { capture = try reader.readTrace() } catch {
            state.notice = .couldNotRemeasure
            state.step = .delay
            state.bands = nil
            return
        }
        if capture.magnitude.isEmpty {
            state.notice = .couldNotRemeasure
            state.step = .delay
            state.bands = nil
            return
        }
        guard let name = state.passPresetName, let preset = state.presets.first(where: { $0.name == name }) else {
            state.notice = .couldNotRemeasure
            state.step = .delay
            return
        }
        switch fitEq(measurement: capture.magnitude, preset: preset.points) {
        case .noOverlap:
            state.postDelayMagnitude = capture.magnitude
            state.notice = .presetNoOverlap
            state.step = .delay
            state.bands = nil
        case .bands(let bands):
            state.postDelayMagnitude = capture.magnitude
            state.bands = bands
            state.step = .eq
            state.notice = bands.isEmpty ? .noEqNeeded : .none
        }
    }
}
```

The extension is outside the class. Task 8 declares the stored properties `fileprivate`, which is what this extension needs:

```swift
@Published fileprivate(set) var state: PassState
fileprivate let reader: SmaartReader
fileprivate let link: OscLink
fileprivate let outputs: OutputStore
```

Leave `bank` private. The extension uses `fileprivate` access. `remeasureAfterDelay` is `fileprivate`.

- [ ] **Step 4: Run test to verify it passes**

Run from the repository root: `swift test --filter PassDelayTests`
Expected: PASS. Both delay writes carry the displayed 12.4, not 12.35. The snapshot stores the read values 1.5 and 2.5. The last-write line is still nil. A matching previous value does not open EQ before confirm. A failed fine-delay read sends no write.

- [ ] **Step 5: Commit**

```bash
git add Sources/AutoSmaartPass/Pass.swift Tests/AutoSmaartPassTests/PassDelayTests.swift
git commit -m "feat: confirm delay, then remeasure before EQ"
```

---

### Task 10: EQ confirm, zero bands, and Compare

**Files:**
- Modify: `Sources/AutoSmaartPass/Pass.swift`
- Test: `Tests/AutoSmaartPassTests/PassEqTests.swift`

**Interfaces:**
- Consumes: `eqAddresses(output:band:)`, `confirmReplace(_:link:)`, `PassController.confirmDelay()`, `EqBand`
- Produces: `PassController.confirmEq()`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import AutoSmaartCore
import ConsoleOSC
@testable import AutoSmaartPass

@MainActor
final class PassEqTests: XCTestCase {
    func testEqConfirmWritesOnlyUsedBandsThenRemeasures() throws {
        let loud = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let flat = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 10000, db: 0, phase: 0)]
        let link = RecordingLink()
        let (pass, reader, _, _) = makePass(traces: [
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [MagnitudePoint(hz: 100, db: 1, phase: 2)], finder: 4)
        ], link: link)
        try prepare(pass, points: flat)
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.step, .eq)
        XCTAssertEqual(pass.state.bands?.count, 8)
        let beforeEq = link.log.count
        pass.confirmEq()
        let eqLog = Array(link.log.dropFirst(beforeEq))
        let band = try eqAddresses(output: 1, band: 1)
        XCTAssertEqual(eqLog.prefix(8).map(\.address), [
            band.freq, band.freq, band.gain, band.gain, band.q, band.q, band.on, band.on
        ])
        XCTAssertEqual(eqLog.first { $0.op == "write" && $0.address == band.on }?.value, .int32(1))
        XCTAssertFalse(eqLog.contains { $0.address.contains("eq_freq_9") || $0.address.contains("Channel_Delay") })
        XCTAssertEqual(pass.state.step, .compare)
        XCTAssertEqual(pass.state.afterCurve?.first?.db, 1)
        XCTAssertEqual(pass.state.beforeCurve?.first?.db, 6)
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · 8 bands")
        XCTAssertEqual(pass.state.outputs[0].eqSnapshot?.count, 8)
        XCTAssertEqual(reader.traceReads, 3)
    }

    func testZeroBandsSendNothingAndDoNotReplaceTheEQSnapshot() throws {
        let point = MagnitudePoint(hz: 100, db: 0.4, phase: 0)
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        let existing = EqBandSnapshot(index: 3, freq: .float32(250), gain: .float32(-1), q: .float32(2), on: .int32(1))
        let link = RecordingLink()
        let (pass, reader, _, _) = makePass(traces: [
            capture(magnitude: [point], finder: 4),
            capture(magnitude: [point], finder: 4)
        ], link: link)
        try prepare(pass, points: preset)
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.bands, [])
        XCTAssertEqual(pass.state.notice, .noEqNeeded)
        pass.setSeededEQSnapshot([existing])
        let reads = reader.traceReads
        let logCount = link.log.count
        pass.confirmEq()
        XCTAssertEqual(link.log.count, logCount)
        XCTAssertEqual(reader.traceReads, reads)
        XCTAssertEqual(pass.state.step, .compare)
        XCTAssertEqual(pass.state.beforeCurve, pass.state.afterCurve)
        XCTAssertEqual(pass.state.notice, .noEqWritten)
        XCTAssertEqual(pass.state.outputs[0].eqSnapshot, [existing])
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · no EQ")
    }

    func testEqRemeasureFailureStillOpensCompare() throws {
        let loud = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let flat = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 10000, db: 0, phase: 0)]
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [], finder: nil)
        ])
        try prepare(pass, points: flat)
        pass.readTrace()
        pass.confirmDelay()
        pass.confirmEq()
        XCTAssertEqual(pass.state.step, .compare)
        XCTAssertEqual(pass.state.notice, .couldNotRemeasure)
        XCTAssertEqual(pass.state.beforeCurve?.first?.hz, 100)
        XCTAssertNil(pass.state.afterCurve)
        XCTAssertTrue(pass.state.eqRemeasureFailed)
        XCTAssertNotNil(pass.state.outputs[0].eqSnapshot)
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · 8 bands")
    }

    func testFailedEqWriteKeepsThePreviousSnapshot() throws {
        let loud = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let flat = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 10000, db: 0, phase: 0)]
        let link = RecordingLink()
        link.failAddresses = ["/sd/Matrix_Outputs/1/EQ/eq_gain_1"]
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4)
        ], link: link)
        try prepare(pass, points: flat)
        pass.readTrace()
        pass.confirmDelay()
        let seeded = EqBandSnapshot(index: 1, freq: .float32(80), gain: .float32(1), q: .float32(1), on: .int32(1))
        pass.setSeededEQSnapshot([seeded])
        pass.confirmEq()
        XCTAssertEqual(pass.state.notice, .writeFailedKept)
        XCTAssertEqual(pass.state.step, .eq)
        XCTAssertEqual(pass.state.outputs[0].eqSnapshot, [seeded])
        XCTAssertNil(pass.state.outputs[0].lastWrite)
    }
}
```

Add this internal test hook to `PassController` so the zero-band and failed-write tests can place an existing snapshot without a second pass:

```swift
func setSeededEQSnapshot(_ snapshot: [EqBandSnapshot]) {
    guard let output = state.selectedOutput else { return }
    state.outputs[output - 1].eqSnapshot = snapshot
    try? outputs.save(state.outputs)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from the repository root: `swift test --filter PassEqTests`
Expected: FAIL. The build stops with `error: value of type 'PassController' has no member 'confirmEq'`.

- [ ] **Step 3: Write minimal implementation**

Append to `Sources/AutoSmaartPass/Pass.swift`:

```swift
extension PassController {
    func setSeededEQSnapshot(_ snapshot: [EqBandSnapshot]) {
        guard let output = state.selectedOutput else { return }
        state.outputs[output - 1].eqSnapshot = snapshot
        try? outputs.save(state.outputs)
    }

    public func confirmEq() {
        guard state.step == .eq, let bands = state.bands, let output = state.selectedOutput else { return }
        if bands.isEmpty {
            state.beforeCurve = state.postDelayMagnitude
            state.afterCurve = state.postDelayMagnitude
            state.eqRemeasureFailed = false
            state.notice = .noEqWritten
            openCompare(output: output)
            return
        }
        guard !state.host.isEmpty, UInt16(state.port) != nil else {
            state.notice = .writeFailedKept
            return
        }
        var items: [Replacement] = []
        for band in bands {
            let addresses: (freq: String, gain: String, q: String, on: String)
            do { addresses = try eqAddresses(output: output, band: band.index) } catch { return }
            items.append(Replacement(address: addresses.freq, value: .float32(Float(band.hz))))
            items.append(Replacement(address: addresses.gain, value: .float32(Float(band.gainDb))))
            items.append(Replacement(address: addresses.q, value: .float32(Float(band.q))))
            items.append(Replacement(address: addresses.on, value: .int32(1)))
        }
        do {
            let restore = try confirmReplace(items, link: link)
            var snapshots: [EqBandSnapshot] = []
            for (offset, band) in bands.enumerated() {
                let base = offset * 4
                snapshots.append(EqBandSnapshot(
                    index: band.index,
                    freq: restore[base].value,
                    gain: restore[base + 1].value,
                    q: restore[base + 2].value,
                    on: restore[base + 3].value
                ))
            }
            state.outputs[output - 1].eqSnapshot = snapshots
            try? outputs.save(state.outputs)
            remeasureAfterEq(output: output)
        } catch let error as ConfirmError {
            state.notice = error == .mismatch ? .writeFailedMismatch : .writeFailedKept
        } catch {
            state.notice = .writeFailedKept
        }
    }

    fileprivate func remeasureAfterEq(output: Int) {
        state.beforeCurve = state.postDelayMagnitude
        do {
            let capture = try reader.readTrace()
            if capture.magnitude.isEmpty {
                state.afterCurve = nil
                state.eqRemeasureFailed = true
                state.notice = .couldNotRemeasure
            } else {
                state.afterCurve = capture.magnitude
                state.eqRemeasureFailed = false
                state.notice = .none
            }
        } catch {
            state.afterCurve = nil
            state.eqRemeasureFailed = true
            state.notice = .couldNotRemeasure
        }
        openCompare(output: output)
    }

    fileprivate func openCompare(output: Int) {
        if let shown = state.displayedDelayMs {
            let count = state.bands?.count ?? 0
            state.outputs[output - 1].lastWrite = count == 0
                ? String(format: "%.1f ms · no EQ", shown)
                : String(format: "%.1f ms · %d bands", shown, count)
            try? outputs.save(state.outputs)
        }
        state.compareOpen = true
        state.step = .compare
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run from the repository root: `swift test --filter PassEqTests`
Expected: PASS. The EQ log for band 1 is freq, gain, Q, on, each read then written. No delay address is in that slice. Zero bands leave the seeded EQ snapshot in place, send no OSC, and do not call `readTrace` again. A failed gain read stays on EQ with the seeded snapshot and a nil last-write line.

- [ ] **Step 5: Commit**

```bash
git add Sources/AutoSmaartPass/Pass.swift Tests/AutoSmaartPassTests/PassEqTests.swift
git commit -m "feat: confirm EQ or open Compare when no band is needed"
```

---

### Task 11: Undo and the last-write line

**Files:**
- Modify: `Sources/AutoSmaartPass/Pass.swift`
- Test: `Tests/AutoSmaartPassTests/PassUndoTests.swift`

**Interfaces:**
- Consumes: `writeOnly(_:link:)`, `delayAddresses(output:)`, `eqAddresses(output:band:)`, `DelaySnapshot`, `EqBandSnapshot`
- Produces: `PassController.undoDelay()`, `PassController.undoLastWrite()`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import AutoSmaartCore
import ConsoleOSC
@testable import AutoSmaartPass

@MainActor
final class PassUndoTests: XCTestCase {
    func testUndoDelayWritesOnlyTheDelaySnapshot() throws {
        let point = MagnitudePoint(hz: 100, db: 0.2, phase: 0)
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        let link = RecordingLink(values: [
            "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(0),
            "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(7)
        ])
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [point], finder: 4),
            capture(magnitude: [point], finder: 4)
        ], link: link)
        try prepare(pass, points: preset)
        pass.readTrace()
        XCTAssertNil(pass.state.outputs[0].delaySnapshot)
        pass.undoDelay()
        XCTAssertTrue(link.log.isEmpty)
        pass.confirmDelay()
        let beforeUndo = link.log.count
        pass.undoDelay()
        let delay = try delayAddresses(output: 1)
        let undo = Array(link.log.dropFirst(beforeUndo))
        XCTAssertEqual(undo.map(\.address), [delay.delay, delay.fineDelay])
        XCTAssertEqual(undo.map(\.value), [.float32(0), .float32(7)])
        XCTAssertEqual(pass.state.outputs[0].delaySnapshot?.fineDelay, .float32(7))
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · no EQ")
    }

    func testCompareUndoWritesDelayAndOnlySnapshotBands() throws {
        let loud = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let flat = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 10000, db: 0, phase: 0)]
        let link = RecordingLink(values: [
            "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(1),
            "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(1)
        ])
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4)
        ], link: link)
        try prepare(pass, points: flat)
        pass.readTrace()
        pass.confirmDelay()
        pass.confirmEq()
        let lastWrite = pass.state.outputs[0].lastWrite
        let before = link.log.count
        pass.undoLastWrite()
        let undo = Array(link.log.dropFirst(before))
        let delay = try delayAddresses(output: 1)
        XCTAssertEqual(Array(undo.prefix(2).map(\.address)), [delay.delay, delay.fineDelay])
        XCTAssertEqual(undo.prefix(2).map(\.value), [.float32(1), .float32(1)])
        XCTAssertEqual(undo.filter { $0.address.contains("/EQ/") }.count, 32)
        XCTAssertFalse(undo.contains { $0.address.contains("eq_freq_9") })
        XCTAssertEqual(pass.state.outputs[0].lastWrite, lastWrite)
        XCTAssertNotNil(pass.state.outputs[0].eqSnapshot)
    }

    func testUndoFailureDoesNotChangeTheSnapshotOrLastWrite() throws {
        let point = MagnitudePoint(hz: 100, db: 0.2, phase: 0)
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        let link = RecordingLink(values: [
            "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(3),
            "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(3)
        ])
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [point], finder: 4),
            capture(magnitude: [point], finder: 4)
        ], link: link)
        try prepare(pass, points: preset)
        pass.readTrace()
        pass.confirmDelay()
        link.failAddresses = ["/sd/Matrix_Outputs/1/Channel_Delay/fine_delay"]
        pass.undoDelay()
        XCTAssertEqual(pass.state.notice, .writeFailedMismatch)
        XCTAssertEqual(pass.state.outputs[0].delaySnapshot?.delay, .float32(3))
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · no EQ")
    }
}
```

`undoDelay` after a zero-band confirm is on Compare, and the test still calls `undoDelay`. That is allowed: the method writes the delay snapshot from any step. The first `undoDelay` in the test is before confirm, with a nil snapshot, and must not touch the link.

The 32 EQ writes are 8 bands × 4 parameters. `needs-eq` style input of one bin at +6 dB produces 8 bands, so the snapshot has 8 bands.

- [ ] **Step 2: Run test to verify it fails**

Run from the repository root: `swift test --filter PassUndoTests`
Expected: FAIL. The build stops with `error: value of type 'PassController' has no member 'undoDelay'`.

- [ ] **Step 3: Write minimal implementation**

Append to `Sources/AutoSmaartPass/Pass.swift`:

```swift
extension PassController {
    public func undoDelay() {
        guard let output = state.selectedOutput, let snapshot = state.outputs[output - 1].delaySnapshot else { return }
        let addresses: (delay: String, fineDelay: String)
        do { addresses = try delayAddresses(output: output) } catch { return }
        sendUndo([
            Replacement(address: addresses.delay, value: snapshot.delay),
            Replacement(address: addresses.fineDelay, value: snapshot.fineDelay)
        ])
    }

    public func undoLastWrite() {
        guard let output = state.selectedOutput else { return }
        let lastWrite = state.outputs[output - 1].lastWrite
        var items: [Replacement] = []
        if let snapshot = state.outputs[output - 1].delaySnapshot, let addresses = try? delayAddresses(output: output) {
            items.append(Replacement(address: addresses.delay, value: snapshot.delay))
            items.append(Replacement(address: addresses.fineDelay, value: snapshot.fineDelay))
        }
        for band in (state.outputs[output - 1].eqSnapshot ?? []).sorted(by: { $0.index < $1.index }) {
            guard let addresses = try? eqAddresses(output: output, band: band.index) else { continue }
            items.append(Replacement(address: addresses.freq, value: band.freq))
            items.append(Replacement(address: addresses.gain, value: band.gain))
            items.append(Replacement(address: addresses.q, value: band.q))
            items.append(Replacement(address: addresses.on, value: band.on))
        }
        sendUndo(items)
        state.outputs[output - 1].lastWrite = lastWrite
    }

    fileprivate func sendUndo(_ items: [Replacement]) {
        let snapshots = state.outputs
        do {
            try writeOnly(items, link: link)
            state.notice = .none
        } catch let error as ConfirmError {
            state.outputs = snapshots
            state.notice = error == .mismatch ? .writeFailedMismatch : .writeFailedKept
        } catch {
            state.outputs = snapshots
            state.notice = .writeFailedKept
        }
    }
}
```

`writeOnly` throws `.mismatch` when the fine-delay undo write fails after the delay undo write was accepted. The snapshot struct is left as it was because `sendUndo` restores `state.outputs` from the copy taken before the writes. `lastWrite` is part of that copy.

- [ ] **Step 4: Run test to verify it passes**

Run from the repository root: `swift test --filter PassUndoTests`
Expected: PASS. Undo before a snapshot sends nothing. Undo delay sends the saved pair and no EQ address. Compare undo sends the delay pair plus 32 EQ values and the last-write string is unchanged. A failed undo keeps the snapshot.

- [ ] **Step 5: Commit**

```bash
git add Sources/AutoSmaartPass/Pass.swift Tests/AutoSmaartPassTests/PassUndoTests.swift
git commit -m "feat: undo delay and the last confirmed write"
```

---

### Task 12: Presenter copy

**Files:**
- Create: `Sources/AutoSmaartPass/Presenter.swift`
- Test: `Tests/AutoSmaartPassTests/PresenterTests.swift`

**Interfaces:**
- Consumes: `PassState`, `PassNotice`, `EqBand`, `MatrixOutputRecord`, `formatFrequency(_:)`
- Produces: `enum PassPresenter` with the static members used by the tests below. Views in the next task call these members and do not invent their own sentences.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import AutoSmaartCore
@testable import AutoSmaartPass

final class PresenterTests: XCTestCase {
    func testCopyMatchesTheSpec() {
        XCTAssertEqual(PassPresenter.pickTitle, "Pick output")
        XCTAssertEqual(PassPresenter.pickSupporting, "One Matrix output. One curve. The console is not written on this step.")
        XCTAssertEqual(PassPresenter.delayTitle, "Delay")
        XCTAssertEqual(PassPresenter.delaySupporting, "Smaart delay suggestion. Not from the target or the reference.")
        XCTAssertFalse(PassPresenter.delaySupporting.contains("Suggested from"))
        XCTAssertEqual(PassPresenter.confirmWarning, "Nothing is sent until you confirm.")
        XCTAssertEqual(PassPresenter.eqSupporting(bandCount: 0), "No EQ is needed.")
        XCTAssertEqual(PassPresenter.eqSupporting(bandCount: 3), "After delay write and remeasure. 3 of 8 bands used. Unused bands stay empty.")
        XCTAssertEqual(PassPresenter.noticeText(.noSmaartTrace), "No Smaart trace.")
        XCTAssertEqual(PassPresenter.noticeText(.noDelaySuggestion), "No delay suggestion.")
        XCTAssertEqual(PassPresenter.noticeText(.noSmaartTarget), "No Smaart target curve.")
        XCTAssertEqual(PassPresenter.noticeText(.presetNoOverlap), "Preset does not overlap the trace.")
        XCTAssertEqual(PassPresenter.noticeText(.couldNotRemeasure), "Could not remeasure.")
        XCTAssertEqual(PassPresenter.noticeText(.writeFailedKept), "Write failed. Previous value kept.")
        XCTAssertEqual(PassPresenter.noticeText(.writeFailedMismatch), "Write failed. Console may not match the previous value.")
        XCTAssertEqual(PassPresenter.noticeText(.noEqNeeded), "No EQ is needed.")
        XCTAssertEqual(PassPresenter.noticeText(.noEqWritten), "No EQ was written.")
        XCTAssertNil(PassPresenter.noticeText(.none))
        XCTAssertEqual(PassPresenter.previousDelayLine(snapshot: nil), "No previous value yet")
        XCTAssertEqual(PassPresenter.eqUndoNote(hasSnapshot: false), "Previous bands are read on confirm.")
        XCTAssertEqual(PassPresenter.eqUndoNote(hasSnapshot: true), "Last undo snapshot")
        XCTAssertEqual(PassPresenter.lastWriteLabel(nil), "not written")
        XCTAssertEqual(PassPresenter.lastWriteLabel("4.0 ms · no EQ"), "4.0 ms · no EQ")
        XCTAssertEqual(PassPresenter.oscStatus(armed: true), "OSC armed")
        XCTAssertEqual(PassPresenter.oscStatus(armed: false), "OSC idle")
        XCTAssertEqual(PassPresenter.smaartLabel, "Smaart API")
        XCTAssertEqual(PassPresenter.readTrace, "Read trace")
        XCTAssertEqual(PassPresenter.storeTarget, "Store target")
        XCTAssertEqual(PassPresenter.storeTrace, "Store trace")
        XCTAssertEqual(PassPresenter.recall, "Recall")
        XCTAssertEqual(PassPresenter.confirmDelay, "Confirm delay write")
        XCTAssertEqual(PassPresenter.confirmEq, "Confirm EQ write")
        XCTAssertEqual(PassPresenter.back, "Back")
        XCTAssertEqual(PassPresenter.undoDelay, "Undo delay")
        XCTAssertEqual(PassPresenter.undoLastWrite, "Undo last write")
        XCTAssertEqual(PassPresenter.retryRemeasure, "Retry remeasure")
        XCTAssertEqual(PassPresenter.frequencyCell(nil), "—")
        XCTAssertEqual(PassPresenter.gainCell(nil), "—")
        XCTAssertEqual(PassPresenter.qCell(nil), "—")
        let band = EqBand(index: 1, hz: 3150, gainDb: -1.5, q: 4)
        XCTAssertEqual(PassPresenter.frequencyCell(band), "3.15 kHz")
        XCTAssertEqual(PassPresenter.gainCell(band), "−1.5 dB")
        XCTAssertEqual(PassPresenter.qCell(band), "4.00")
        XCTAssertEqual(PassPresenter.suggestedDelay(12.4), "12.4 ms")
        XCTAssertNotEqual(PassPresenter.suggestedDelay(12.4), "18.6 ms")
    }

    func testOscArmedOnlyWhenThatConfirmCanSend() {
        var state = PassState()
        state.host = "10.0.0.8"
        state.port = "8000"
        state.step = .pick
        XCTAssertFalse(PassPresenter.oscArmed(state))
        state.step = .delay
        state.displayedDelayMs = 12.4
        XCTAssertTrue(PassPresenter.oscArmed(state))
        state.step = .eq
        state.bands = []
        XCTAssertFalse(PassPresenter.oscArmed(state))
        state.bands = [EqBand(index: 1, hz: 100, gainDb: -6, q: 4)]
        XCTAssertTrue(PassPresenter.oscArmed(state))
        state.step = .compare
        XCTAssertFalse(PassPresenter.oscArmed(state))
        state.step = .delay
        state.host = ""
        XCTAssertFalse(PassPresenter.oscArmed(state))
    }

    func testReadAndStoreEnablement() {
        var state = PassState()
        XCTAssertFalse(PassPresenter.readEnabled(state))
        XCTAssertFalse(PassPresenter.storeEnabled(state))
        state.host = "10.0.0.8"
        state.port = "8000"
        state.selectedOutput = 1
        state.passPresetName = "Main"
        state.draftName = "Main"
        XCTAssertTrue(PassPresenter.readEnabled(state))
        XCTAssertTrue(PassPresenter.storeEnabled(state))
        state.draftName = " "
        XCTAssertFalse(PassPresenter.storeEnabled(state))
        state.step = .eq
        state.bands = []
        XCTAssertTrue(PassPresenter.confirmEqEnabled(state))
        state.bands = nil
        XCTAssertFalse(PassPresenter.confirmEqEnabled(state))
    }

    func testCompareReadout() {
        var state = PassState()
        state.selectedOutput = 1
        state.outputs = [MatrixOutputRecord(index: 1, displayName: "", lastWrite: nil, delaySnapshot: DelaySnapshot(delay: .float32(0), fineDelay: .float32(0)), eqSnapshot: nil)]
        state.displayedDelayMs = 4
        state.bands = []
        state.notice = .noEqWritten
        XCTAssertEqual(PassPresenter.compareLines(state), [
            "Delay 0.0 ms → 4.0 ms",
            "Bands written: 0. Bands left empty: 8.",
            "No EQ was written."
        ])
        state.eqRemeasureFailed = true
        state.bands = [EqBand(index: 1, hz: 100, gainDb: -6, q: 4)]
        XCTAssertTrue(PassPresenter.compareLines(state).contains("Could not remeasure."))
        XCTAssertTrue(PassPresenter.compareLines(state).contains("Bands written: 1. Bands left empty: 7."))
    }

    func testUndoControlsFollowTheSnapshot() {
        var state = PassState()
        state.selectedOutput = 1
        state.outputs = [MatrixOutputRecord(index: 1, displayName: "", lastWrite: nil, delaySnapshot: nil, eqSnapshot: nil)]
        XCTAssertFalse(PassPresenter.showsUndoDelay(state))
        XCTAssertFalse(PassPresenter.showsUndoLastWrite(state))
        state.outputs[0].delaySnapshot = DelaySnapshot(delay: .float32(1), fineDelay: .float32(1))
        XCTAssertTrue(PassPresenter.showsUndoDelay(state))
        state.step = .compare
        state.compareOpen = true
        XCTAssertTrue(PassPresenter.showsUndoLastWrite(state))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from the repository root: `swift test --filter PresenterTests`
Expected: FAIL. The build stops with `error: cannot find 'PassPresenter' in scope`.

- [ ] **Step 3: Write minimal implementation**

`Sources/AutoSmaartPass/Presenter.swift`

```swift
import Foundation
import AutoSmaartCore

public enum PassPresenter {
    public static let pickTitle = "Pick output"
    public static let pickSupporting = "One Matrix output. One curve. The console is not written on this step."
    public static let delayTitle = "Delay"
    public static let delaySupporting = "Smaart delay suggestion. Not from the target or the reference."
    public static let eqTitle = "EQ"
    public static let compareTitle = "Compare"
    public static let confirmWarning = "Nothing is sent until you confirm."
    public static let smaartLabel = "Smaart API"
    public static let readTrace = "Read trace"
    public static let storeTarget = "Store target"
    public static let storeTrace = "Store trace"
    public static let recall = "Recall"
    public static let confirmDelay = "Confirm delay write"
    public static let confirmEq = "Confirm EQ write"
    public static let back = "Back"
    public static let undoDelay = "Undo delay"
    public static let undoLastWrite = "Undo last write"
    public static let retryRemeasure = "Retry remeasure"
    public static let emDash = "—"

    public static func eqSupporting(bandCount: Int) -> String {
        if bandCount == 0 { return "No EQ is needed." }
        return "After delay write and remeasure. \(bandCount) of 8 bands used. Unused bands stay empty."
    }

    public static func noticeText(_ notice: PassNotice) -> String? {
        switch notice {
        case .none: return nil
        case .noSmaartTrace: return "No Smaart trace."
        case .noDelaySuggestion: return "No delay suggestion."
        case .noSmaartTarget: return "No Smaart target curve."
        case .presetNoOverlap: return "Preset does not overlap the trace."
        case .couldNotRemeasure: return "Could not remeasure."
        case .writeFailedKept: return "Write failed. Previous value kept."
        case .writeFailedMismatch: return "Write failed. Console may not match the previous value."
        case .noEqNeeded: return "No EQ is needed."
        case .noEqWritten: return "No EQ was written."
        }
    }

    public static func previousDelayLine(snapshot: DelaySnapshot?) -> String {
        guard let snapshot else { return "No previous value yet" }
        return "delay \(oneDecimal(snapshot.delay)) · fine_delay \(oneDecimal(snapshot.fineDelay))"
    }

    public static func eqUndoNote(hasSnapshot: Bool) -> String {
        hasSnapshot ? "Last undo snapshot" : "Previous bands are read on confirm."
    }

    public static func lastWriteLabel(_ value: String?) -> String { value ?? "not written" }

    public static func oscStatus(armed: Bool) -> String { armed ? "OSC armed" : "OSC idle" }

    public static func frequencyCell(_ band: EqBand?) -> String {
        guard let band else { return emDash }
        return formatFrequency(band.hz)
    }

    public static func gainCell(_ band: EqBand?) -> String {
        guard let band else { return emDash }
        let rounded = roundHalfAwayFromZero(band.gainDb, places: 1)
        let sign = rounded > 0 ? "+" : (rounded < 0 ? "−" : "")
        return "\(sign)\(String(format: "%.1f", abs(rounded))) dB"
    }

    public static func qCell(_ band: EqBand?) -> String {
        guard let band else { return emDash }
        return String(format: "%.2f", band.q)
    }

    public static func suggestedDelay(_ displayed: Double) -> String {
        String(format: "%.1f ms", displayed)
    }

    public static func oscArmed(_ state: PassState) -> Bool {
        guard !state.host.isEmpty, !state.port.isEmpty else { return false }
        if state.step == .delay, state.displayedDelayMs != nil { return true }
        if state.step == .eq, let bands = state.bands, !bands.isEmpty { return true }
        return false
    }

    public static func readEnabled(_ state: PassState) -> Bool {
        state.selectedOutput != nil && state.passPresetName != nil && !state.host.isEmpty && !state.port.isEmpty
    }

    public static func storeEnabled(_ state: PassState) -> Bool {
        !state.draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func confirmEqEnabled(_ state: PassState) -> Bool {
        state.step == .eq && state.bands != nil && !state.host.isEmpty && UInt16(state.port) != nil
    }

    public static func confirmDelayEnabled(_ state: PassState) -> Bool {
        state.step == .delay && state.displayedDelayMs != nil && !state.host.isEmpty && UInt16(state.port) != nil
    }

    public static func compareLines(_ state: PassState) -> [String] {
        var lines: [String] = []
        if let output = state.selectedOutput,
           state.outputs.indices.contains(output - 1),
           let snapshot = state.outputs[output - 1].delaySnapshot,
           let shown = state.displayedDelayMs {
            lines.append("Delay \(oneDecimal(snapshot.delay)) ms → \(String(format: "%.1f", shown)) ms")
        }
        let count = state.bands?.count ?? 0
        lines.append("Bands written: \(count). Bands left empty: \(8 - count).")
        if count == 0 { lines.append("No EQ was written.") }
        if state.eqRemeasureFailed { lines.append("Could not remeasure.") }
        return lines
    }

    public static func showsUndoDelay(_ state: PassState) -> Bool {
        guard let output = state.selectedOutput, state.outputs.indices.contains(output - 1) else { return false }
        return state.outputs[output - 1].delaySnapshot != nil
    }

    public static func showsUndoLastWrite(_ state: PassState) -> Bool {
        guard state.step == .compare, let output = state.selectedOutput, state.outputs.indices.contains(output - 1) else { return false }
        let row = state.outputs[output - 1]
        return row.delaySnapshot != nil || row.eqSnapshot != nil
    }

    public static func selectionSummary(_ state: PassState) -> String {
        let output = state.selectedOutput.map { "Matrix \($0)" } ?? "No output"
        let preset = state.passPresetName ?? "No preset"
        return "\(output) · \(preset)"
    }

    public static func kindLabel(_ kind: CurveKind) -> String {
        kind == .target ? "Target" : "Reference"
    }

    private static func oneDecimal(_ value: OscValue) -> String {
        switch value {
        case .float32(let number):
            return String(format: "%.1f", roundHalfAwayFromZero(Double(number), places: 1))
        case .int32(let number):
            return String(number)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run from the repository root: `swift test --filter PresenterTests`
Expected: PASS. The delay supporting line is the Smaart sentence. A 12.4 ms suggestion does not render as 18.6 ms. Zero-band EQ is not OSC armed. Empty EQ cells are `—`.

- [ ] **Step 5: Commit**

```bash
git add Sources/AutoSmaartPass/Presenter.swift Tests/AutoSmaartPassTests/PresenterTests.swift
git commit -m "feat: lock the calibration screen copy"
```

---

### Task 13: Mac window

**Files:**
- Create: `Sources/AutoSmaartUI/Theme.swift`
- Create: `Sources/AutoSmaartUI/ShellView.swift`
- Create: `Sources/AutoSmaartUI/PickView.swift`
- Create: `Sources/AutoSmaartUI/DelayView.swift`
- Create: `Sources/AutoSmaartUI/EQView.swift`
- Create: `Sources/AutoSmaartUI/CompareView.swift`
- Create: `Sources/AutoSmaartUI/MagnitudePlot.swift`
- Create: `Sources/AutoSmaartApp/AutoSmaartApp.swift`
- Delete: `Sources/AutoSmaartApp/Placeholder.swift`
- Modify: `Package.swift`
- Test: `Tests/AutoSmaartUITests/ShellTests.swift`

**Interfaces:**
- Consumes: `PassController`, `PassPresenter`, `PassState`, `MagnitudePoint`
- Produces: `Theme`, `ThemeMetrics`, `ShellView`, `PickView`, `DelayView`, `EQView`, `CompareView`, `MagnitudePlot`. The executable target's `@main` struct shows `ShellView` at 1440×900.

The UI calls presenter strings and pass methods. It does not build OSC addresses and it does not call `fitEq`. Plot horizontal range is 20 Hz through 20 kHz on a log axis. Before is `#a78b71` at 70% opacity. After is `#e8d5b7` and is omitted when `afterCurve` is nil. Phase is not a plot series. Fonts are the variable files downloaded in this task. Wordmark is Playfair Display italic 18. Every other text style is Inter.

- [ ] **Step 1: Write the failing test**

Add to `Package.swift`:

```swift
.target(
    name: "AutoSmaartUI",
    dependencies: ["AutoSmaartPass", "AutoSmaartCore"],
    resources: [.process("Resources")]
),
.executableTarget(name: "AutoSmaartApp", dependencies: ["AutoSmaartUI"]),
.testTarget(name: "AutoSmaartUITests", dependencies: ["AutoSmaartUI", "AutoSmaartPass", "AutoSmaartCore"]),
```

Remove the `resources` entry from the `AutoSmaartApp` target added in Task 1. Keep the executable target as the replacement above.

```swift
import XCTest
import SwiftUI
import AutoSmaartCore
@testable import AutoSmaartUI
@testable import AutoSmaartPass

@MainActor
final class ShellTests: XCTestCase {
    func testMetricsAndColors() {
        XCTAssertEqual(ThemeMetrics.windowWidth, 1440)
        XCTAssertEqual(ThemeMetrics.windowHeight, 900)
        XCTAssertEqual(ThemeMetrics.titleBar, 56)
        XCTAssertEqual(ThemeMetrics.rail, 220)
        XCTAssertEqual(ThemeMetrics.bottomBar, 64)
        XCTAssertEqual(Theme.backgroundHex, "0a0a0a")
        XCTAssertEqual(Theme.textHex, "ffffff")
        XCTAssertEqual(Theme.secondaryHex, "a3a3a3")
        XCTAssertEqual(Theme.goldHex, "a78b71")
        XCTAssertEqual(Theme.lightGoldHex, "c9b8a0")
        XCTAssertEqual(Theme.hoverGoldHex, "e8d5b7")
        XCTAssertEqual(Theme.liveHex, "4ade80")
        XCTAssertEqual(Theme.beforeHex, "a78b71")
        XCTAssertEqual(Theme.afterHex, "e8d5b7")
    }

    func testScreensRenderThePresenterCopy() throws {
        let point = MagnitudePoint(hz: 1000, db: -3, phase: 0)
        let (pass, _, _, _) = makePass(traces: [capture(magnitude: [point], finder: 12.35)])
        try prepare(pass, points: [point])
        let pick = PickView(controller: pass)
        let delay = DelayView(controller: pass)
        let eq = EQView(controller: pass)
        let compare = CompareView(controller: pass)
        _ = pick.body
        _ = delay.body
        _ = eq.body
        _ = compare.body
        pass.readTrace()
        let shell = ShellView(controller: pass)
        _ = shell.body
        XCTAssertEqual(pass.state.step, .delay)
        let plot = MagnitudePlot(before: [point], after: nil)
        _ = plot.body
    }

    func testUISourceDoesNotHardcodeTheDraftNumbers() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Sources/AutoSmaartUI")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let source = try files.filter { $0.pathExtension == "swift" }.map { try String(contentsOf: $0) }.joined(separator: "\n")
        for forbidden in ["18.6", "Suggested from the Main target", "unlock your mix", "CGWindowListCreateImage", "screencapture"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
        XCTAssertTrue(source.contains("PassPresenter"))
        XCTAssertFalse(source.contains("fitEq"))
        XCTAssertFalse(source.contains("/sd/Matrix_Outputs"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from the repository root: `swift test --filter ShellTests`
Expected: FAIL. The build stops with `error: no such module 'AutoSmaartUI'`.

- [ ] **Step 3: Write minimal implementation**

Download the fonts from the repository root:

```bash
mkdir -p Sources/AutoSmaartUI/Resources
curl -fsSL -o Sources/AutoSmaartUI/Resources/Inter-VariableFont.ttf \
  "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf"
curl -fsSL -o Sources/AutoSmaartUI/Resources/PlayfairDisplay-Italic-VariableFont.ttf \
  "https://github.com/google/fonts/raw/main/ofl/playfairdisplay/PlayfairDisplay-Italic%5Bwght%5D.ttf"
```

`Sources/AutoSmaartUI/Theme.swift`

```swift
import CoreText
import SwiftUI

public enum ThemeMetrics {
    public static let windowWidth: CGFloat = 1440
    public static let windowHeight: CGFloat = 900
    public static let titleBar: CGFloat = 56
    public static let rail: CGFloat = 220
    public static let bottomBar: CGFloat = 64
    public static let row: CGFloat = 36
    public static let pagePadding: CGFloat = 20
    public static let groupGap: CGFloat = 16
}

public enum Theme {
    static let backgroundHex = "0a0a0a"
    static let textHex = "ffffff"
    static let secondaryHex = "a3a3a3"
    static let goldHex = "a78b71"
    static let lightGoldHex = "c9b8a0"
    static let hoverGoldHex = "e8d5b7"
    static let liveHex = "4ade80"
    static let beforeHex = "a78b71"
    static let afterHex = "e8d5b7"

    static let background = Color(hex: 0x0a0a0a)
    static let text = Color(hex: 0xffffff)
    static let secondary = Color(hex: 0xa3a3a3)
    static let dim = Color.white.opacity(0.45)
    static let gold = Color(hex: 0xa78b71)
    static let lightGold = Color(hex: 0xc9b8a0)
    static let hoverGold = Color(hex: 0xe8d5b7)
    static let live = Color(hex: 0x4ade80)
    static let grid = Color.white.opacity(0.12)
    static let selectedRow = Color(hex: 0xa78b71).opacity(0.16)
    static let raised = Color.white.opacity(0.03)
    static let stroke = Color.white.opacity(0.1)
    static let beforeTrace = Color(hex: 0xa78b71).opacity(0.7)
    static let afterTrace = Color(hex: 0xe8d5b7)

    static func registerFonts() {
        for name in ["Inter-VariableFont", "PlayfairDisplay-Italic-VariableFont"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xff) / 255
        let green = Double((hex >> 8) & 0xff) / 255
        let blue = Double(hex & 0xff) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Inter", size: 13).weight(.medium))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: ThemeMetrics.row)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(.plain)
    }
}

struct QuietButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Inter", size: 13))
                .foregroundStyle(Theme.secondary)
        }
        .buttonStyle(.plain)
    }
}
```

`Sources/AutoSmaartUI/ShellView.swift`

```swift
import SwiftUI
import AutoSmaartPass

public struct ShellView: View {
    @ObservedObject var controller: PassController

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            HStack(spacing: 0) {
                rail
                screen
            }
            bottomBar
        }
        .frame(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .onAppear { Theme.registerFonts() }
    }

    private var titleBar: some View {
        HStack {
            Text("Auto-Smaart")
                .font(.custom("Playfair Display", size: 18).italic())
                .padding(.leading, 78)
            Text("Quantum 225")
                .font(.custom("Inter", size: 13))
                .foregroundStyle(Theme.secondary)
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(controller.state.smaartLive ? Theme.live : Theme.dim).frame(width: 8, height: 8)
                Text(PassPresenter.smaartLabel).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
                Text(PassPresenter.oscStatus(armed: PassPresenter.oscArmed(controller.state)))
                    .font(.custom("Inter", size: 13))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.trailing, ThemeMetrics.pagePadding)
        }
        .frame(height: ThemeMetrics.titleBar)
    }

    private var rail: some View {
        VStack(alignment: .leading, spacing: 0) {
            railRow(.pick, title: "Pick", done: controller.canOpen(.delay))
            railRow(.delay, title: "Delay", done: controller.state.delayWrittenThisPass)
            railRow(.eq, title: "EQ", done: controller.state.compareOpen)
            railRow(.compare, title: "Compare", done: false)
            Spacer()
        }
        .frame(width: ThemeMetrics.rail)
        .background(Theme.raised)
    }

    private func railRow(_ step: PassStep, title: String, done: Bool) -> some View {
        Button { controller.openRail(step) } label: {
            HStack {
                Rectangle().fill(controller.state.step == step ? Theme.gold : Color.clear).frame(width: 2)
                Text(title)
                    .font(.custom("Inter", size: 13).weight(.medium))
                    .foregroundStyle(controller.state.step == step ? Theme.lightGold : Theme.dim)
                Spacer()
                if done { Image(systemName: "checkmark").foregroundStyle(Theme.gold).font(.system(size: 11)) }
            }
            .frame(height: ThemeMetrics.row)
        }
        .buttonStyle(.plain)
        .disabled(!controller.canOpen(step))
    }

    @ViewBuilder private var screen: some View {
        switch controller.state.step {
        case .pick: PickView(controller: controller)
        case .delay: DelayView(controller: controller)
        case .eq: EQView(controller: controller)
        case .compare: CompareView(controller: controller)
        }
    }

    private var bottomBar: some View {
        HStack {
            Text(PassPresenter.selectionSummary(controller.state))
                .font(.custom("Inter", size: 13))
                .foregroundStyle(Theme.secondary)
            Spacer()
            if let notice = PassPresenter.noticeText(controller.state.notice) {
                Text(notice).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            }
            bottomAction
        }
        .padding(.horizontal, ThemeMetrics.pagePadding)
        .frame(height: ThemeMetrics.bottomBar)
    }

    @ViewBuilder private var bottomAction: some View {
        switch controller.state.step {
        case .pick:
            PrimaryButton(title: PassPresenter.readTrace) { controller.readTrace() }
                .disabled(!PassPresenter.readEnabled(controller.state))
        case .delay:
            HStack(spacing: 16) {
                QuietButton(title: PassPresenter.back) { controller.back() }
                if controller.state.notice == .couldNotRemeasure {
                    QuietButton(title: PassPresenter.retryRemeasure) { controller.retryRemeasure() }
                }
                PrimaryButton(title: PassPresenter.confirmDelay) { controller.confirmDelay() }
                    .disabled(!PassPresenter.confirmDelayEnabled(controller.state))
            }
        case .eq:
            PrimaryButton(title: PassPresenter.confirmEq) { controller.confirmEq() }
                .disabled(!PassPresenter.confirmEqEnabled(controller.state))
        case .compare:
            if PassPresenter.showsUndoLastWrite(controller.state) {
                QuietButton(title: PassPresenter.undoLastWrite) { controller.undoLastWrite() }
            }
        }
    }
}
```

`ShellView` uses `PassStep` through `import AutoSmaartPass`. The pass and core declarations the UI calls are already `public` in Tasks 2, 6, 8, and 12. The UI target does not use `@testable`.

`Sources/AutoSmaartUI/PickView.swift`

```swift
import SwiftUI
import AutoSmaartPass

public struct PickView: View {
    @ObservedObject var controller: PassController

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeMetrics.groupGap) {
            Text(PassPresenter.pickTitle).font(.custom("Inter", size: 18).weight(.semibold))
            Text(PassPresenter.pickSupporting).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            HStack(alignment: .top, spacing: ThemeMetrics.groupGap) {
                matrixTable
                presetTable
            }
            HStack {
                TextField("Console IP", text: host)
                TextField("OSC port", text: port)
                TextField("Name", text: draft)
            }
            .textFieldStyle(.plain)
            .font(.custom("Inter", size: 13))
            HStack {
                QuietButton(title: PassPresenter.storeTarget) { controller.storeTarget() }
                    .disabled(!PassPresenter.storeEnabled(controller.state))
                QuietButton(title: PassPresenter.storeTrace) { controller.storeTrace() }
                    .disabled(!PassPresenter.storeEnabled(controller.state))
                QuietButton(title: PassPresenter.recall) { recallSelected() }
            }
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }

    private var host: Binding<String> { Binding(get: { controller.state.host }, set: { controller.setHost($0) }) }
    private var port: Binding<String> { Binding(get: { controller.state.port }, set: { controller.setPort($0) }) }
    private var draft: Binding<String> { Binding(get: { controller.state.draftName }, set: { controller.setDraftName($0) }) }

    private var matrixTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Output", "Name", "Last write")
            ForEach(controller.state.outputs, id: \.index) { row in
                Button { controller.selectOutput(row.index) } label: {
                    HStack {
                        Text("Matrix \(row.index)").frame(maxWidth: .infinity, alignment: .leading)
                        TextField("", text: name(row.index)).frame(maxWidth: .infinity)
                        Text(PassPresenter.lastWriteLabel(row.lastWrite)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.custom("Inter", size: 13))
                    .frame(height: ThemeMetrics.row)
                    .padding(.leading, 8)
                    .background(controller.state.selectedOutput == row.index ? Theme.selectedRow : Color.clear)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(controller.state.selectedOutput == row.index ? Theme.gold : Color.clear).frame(width: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var presetTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Preset", "Type", "Source")
            ForEach(controller.state.presets, id: \.name) { preset in
                Button { controller.recall(name: preset.name) } label: {
                    HStack {
                        Text(preset.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(PassPresenter.kindLabel(preset.kind)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(preset.kind == .target ? "Smaart target" : "Captured trace").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.custom("Inter", size: 13))
                    .frame(height: ThemeMetrics.row)
                    .background(controller.state.passPresetName == preset.name ? Theme.selectedRow : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func header(_ a: String, _ b: String, _ c: String) -> some View {
        HStack {
            Text(a).frame(maxWidth: .infinity, alignment: .leading)
            Text(b).frame(maxWidth: .infinity, alignment: .leading)
            Text(c).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.custom("Inter", size: 11).weight(.medium))
        .tracking(0.88)
        .foregroundStyle(Theme.lightGold)
        .frame(height: ThemeMetrics.row)
    }

    private func name(_ index: Int) -> Binding<String> {
        Binding(
            get: { controller.state.outputs[index - 1].displayName },
            set: { controller.setDisplayName($0, output: index) }
        )
    }

    private func recallSelected() {
        if let name = controller.state.passPresetName { controller.recall(name: name) }
    }
}
```

The preset table's row button recalls immediately, which matches Recall for the selected row. The quiet Recall button recalls the current pass preset and therefore changes nothing when that row is already selected.

`Sources/AutoSmaartUI/DelayView.swift`

```swift
import SwiftUI
import AutoSmaartPass

public struct DelayView: View {
    @ObservedObject var controller: PassController

    var body: some View {
        HStack(alignment: .top, spacing: ThemeMetrics.groupGap) {
            VStack(alignment: .leading) {
                MagnitudePlot(before: controller.state.latestMagnitude ?? [], after: nil)
                Text("Smaart delay read").font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(PassPresenter.delayTitle).font(.custom("Inter", size: 18).weight(.semibold))
                Text(PassPresenter.delaySupporting).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
                if let shown = controller.state.displayedDelayMs {
                    Text(PassPresenter.suggestedDelay(shown))
                        .font(.custom("Inter", size: 13).weight(.medium))
                        .monospacedDigit()
                }
                let snapshot = controller.state.selectedOutput.flatMap { index in
                    controller.state.outputs[index - 1].delaySnapshot
                }
                Text(PassPresenter.previousDelayLine(snapshot: snapshot))
                    .font(.custom("Inter", size: 13))
                    .foregroundStyle(Theme.secondary)
                Text(PassPresenter.confirmWarning).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
                if PassPresenter.showsUndoDelay(controller.state) {
                    QuietButton(title: PassPresenter.undoDelay) { controller.undoDelay() }
                }
            }
            .padding(ThemeMetrics.pagePadding)
            .background(Theme.raised)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }
}
```

`Sources/AutoSmaartUI/EQView.swift`

```swift
import SwiftUI
import AutoSmaartPass
import AutoSmaartCore

public struct EQView: View {
    @ObservedObject var controller: PassController

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeMetrics.groupGap) {
            Text(PassPresenter.eqTitle).font(.custom("Inter", size: 18).weight(.semibold))
            Text(PassPresenter.eqSupporting(bandCount: controller.state.bands?.count ?? 0))
                .font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            VStack(spacing: 0) {
                ForEach(1...8, id: \.self) { index in
                    let band = controller.state.bands?.first { $0.index == index }
                    HStack {
                        Text("\(index)").frame(width: 40, alignment: .leading)
                        Text(PassPresenter.frequencyCell(band)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(PassPresenter.gainCell(band)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(PassPresenter.qCell(band)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.custom("Inter", size: 13).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(band == nil ? Theme.dim : Theme.text)
                    .frame(height: ThemeMetrics.row)
                }
            }
            Text(PassPresenter.eqUndoNote(hasSnapshot: controller.state.selectedOutput.flatMap { controller.state.outputs[$0 - 1].eqSnapshot } != nil))
                .font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            Text(PassPresenter.confirmWarning).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }
}
```

`Sources/AutoSmaartUI/CompareView.swift`

```swift
import SwiftUI
import AutoSmaartPass

public struct CompareView: View {
    @ObservedObject var controller: PassController

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeMetrics.groupGap) {
            Text(PassPresenter.compareTitle).font(.custom("Inter", size: 18).weight(.semibold))
            MagnitudePlot(before: controller.state.beforeCurve ?? [], after: controller.state.afterCurve)
            ForEach(PassPresenter.compareLines(controller.state), id: \.self) { line in
                Text(line).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            }
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }
}
```

`Sources/AutoSmaartUI/MagnitudePlot.swift`

```swift
import SwiftUI
import AutoSmaartCore

public struct MagnitudePlot: View {
    var before: [MagnitudePoint]
    var after: [MagnitudePoint]?

    var body: some View {
        Canvas { context, size in
            let grid = Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: 0))
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
            }
            context.stroke(grid, with: .color(Theme.grid), lineWidth: 1)
            stroke(context, size, before, Theme.beforeTrace)
            if let after { stroke(context, size, after, Theme.afterTrace) }
        }
        .frame(minHeight: 220)
        .overlay(alignment: .bottomLeading) {
            HStack {
                Text("20 Hz")
                Spacer()
                Text("20 kHz")
            }
            .font(.custom("Inter", size: 11))
            .foregroundStyle(Theme.dim)
        }
    }

    private func stroke(_ context: GraphicsContext, _ size: CGSize, _ points: [MagnitudePoint], _ color: Color) {
        let kept = points.filter { $0.hz >= 20 && $0.hz <= 20000 }.sorted { $0.hz < $1.hz }
        guard kept.count > 1 else { return }
        let lows = kept.map(\.db).min() ?? -6
        let highs = kept.map(\.db).max() ?? 6
        let span = max(1, highs - lows)
        var path = Path()
        for (index, point) in kept.enumerated() {
            let x = (log10(point.hz) - log10(20)) / (log10(20000) - log10(20)) * size.width
            let y = (1 - (point.db - lows) / span) * size.height
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
}
```

`Sources/AutoSmaartApp/AutoSmaartApp.swift`

```swift
import SwiftUI
import AutoSmaartUI

@main
struct AutoSmaartApp: App {
    var body: some Scene {
        WindowGroup {
            ShellView(controller: AppRuntime.controller)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
    }
}
```

`AppRuntime` is added in Task 14. This task's compile of `ShellTests` does not require `AppRuntime`. The executable will not compile until Task 14. That is expected. Do not run `swift build` of the executable in this task. `swift test --filter ShellTests` builds the UI library and the tests.

- [ ] **Step 4: Run test to verify it passes**

Run from the repository root: `swift test --filter ShellTests`
Expected: PASS. The four screen bodies and the shell body evaluate. The UI sources do not contain `18.6`, a screen-capture call, or an OSC address.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/AutoSmaartUI Sources/AutoSmaartApp Tests/AutoSmaartUITests
git commit -m "feat: add the four-step Mac window"
```

---

### Task 14: App wiring, source guard, and the hardware pass

**Files:**
- Create: `Sources/AutoSmaartUI/AppRuntime.swift`
- Modify: `Sources/AutoSmaartApp/AutoSmaartApp.swift`
- Modify: `README.md`
- Delete: `Tests/HardwareTests/EmptyTests.swift`
- Test: `Tests/HardwareTests/Quantum225HardwareTests.swift`
- Test: `Tests/AutoSmaartPassTests/SourceGuardTests.swift`

**Interfaces:**
- Consumes: `OfficialSmaartSession`, `URLSessionSmaartWire`, `Quantum225Client`, `PassController`, `CurveBank`, `OutputStore`, `ShellView`, `ConsoleEndpoint`
- Produces: `public enum AppRuntime` with `public static let controller: PassController`. Launch opens the local Smaart session, stores the bank and the twelve output rows under `~/Library/Application Support/Auto-Smaart/`, and uses a live OSC link that opens a UDP client from the current host and port on each read or write.

- [ ] **Step 1: Write the failing test**

`Tests/AutoSmaartPassTests/SourceGuardTests.swift`

```swift
import XCTest

final class SourceGuardTests: XCTestCase {
    func testSourcesStayInsideTheSpec() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        var text = ""
        let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)!
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            text += try String(contentsOf: url)
        }
        for forbidden in ["CGWindowListCreateImage", "screencapture", "openai", "Double.random", "Yamaha", "PM10", "X32"] {
            XCTAssertFalse(text.contains(forbidden), forbidden)
        }
        XCTAssertTrue(text.contains("ws://127.0.0.1:26000/api/v4/"))
        XCTAssertTrue(text.contains("/sd/Matrix_Outputs/"))
    }
}
```

`Tests/HardwareTests/Quantum225HardwareTests.swift`

```swift
import XCTest
import AutoSmaartCore
import SmaartAPI
import ConsoleOSC
@testable import AutoSmaartPass

@MainActor
final class Quantum225HardwareTests: XCTestCase {
    func testOneMatrixDelayThenEqThenRemeasure() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["AUTO_SMAART_HARDWARE"] == "1" else {
            throw XCTSkip("Set AUTO_SMAART_HARDWARE=1, AUTO_SMAART_CONSOLE_HOST, AUTO_SMAART_CONSOLE_PORT, and AUTO_SMAART_MATRIX to run one Quantum 225 pass.")
        }
        let host = try XCTUnwrap(env["AUTO_SMAART_CONSOLE_HOST"])
        let portText = try XCTUnwrap(env["AUTO_SMAART_CONSOLE_PORT"])
        let port = try XCTUnwrap(UInt16(portText))
        let matrix = try XCTUnwrap(Int(env["AUTO_SMAART_MATRIX"] ?? ""))
        XCTAssertTrue((1...12).contains(matrix))
        let session = OfficialSmaartSession(wire: URLSessionSmaartWire())
        try session.openSession()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bank = CurveBank(fileURL: directory.appendingPathComponent("bank.json"))
        let outputs = OutputStore(fileURL: directory.appendingPathComponent("outputs.json"))
        let link = try Quantum225Client(host: host, port: port)
        defer { link.close() }
        let pass = PassController(reader: session, link: link, bank: bank, outputs: outputs)
        pass.setHost(host)
        pass.setPort(portText)
        pass.selectOutput(matrix)
        try pass.storePreparedPreset(name: "Hardware target", kind: .target, points: [
            MagnitudePoint(hz: 20, db: 40, phase: 0),
            MagnitudePoint(hz: 20000, db: 40, phase: 0)
        ])
        pass.recall(name: "Hardware target")
        pass.readTrace()
        XCTAssertEqual(pass.state.step, .delay, PassPresenter.noticeText(pass.state.notice) ?? "")
        pass.confirmDelay()
        if pass.state.notice == .couldNotRemeasure { pass.retryRemeasure() }
        XCTAssertEqual(pass.state.step, .eq, PassPresenter.noticeText(pass.state.notice) ?? "")
        XCTAssertFalse(pass.state.bands?.isEmpty ?? true)
        pass.confirmEq()
        XCTAssertEqual(pass.state.step, .compare)
        XCTAssertNotNil(pass.state.afterCurve)
        let snapshot = try XCTUnwrap(pass.state.outputs[matrix - 1].delaySnapshot)
        pass.undoLastWrite()
        let addresses = try delayAddresses(output: matrix)
        XCTAssertEqual(try link.read(address: addresses.delay), snapshot.delay)
        XCTAssertEqual(try link.read(address: addresses.fineDelay), snapshot.fineDelay)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from the repository root: `swift build --target AutoSmaartApp`
Expected: FAIL. The build stops with `error: cannot find 'AppRuntime' in scope`.

Run from the repository root: `swift test --filter Quantum225HardwareTests`
Expected: the test is skipped. The skip message contains `Set AUTO_SMAART_HARDWARE=1`. The console is not written.

- [ ] **Step 3: Write minimal implementation**

`Sources/AutoSmaartUI/AppRuntime.swift`

```swift
import Foundation
import AutoSmaartCore
import AutoSmaartPass
import SmaartAPI
import ConsoleOSC

public final class HostPortBox: ConsoleEndpoint {
    public var host = ""
    public var port = ""
    public init() {}
    public func update(host: String, port: String) {
        self.host = host
        self.port = port
    }
}

public enum AppRuntime {
    public static let box = HostPortBox()
    public static let controller: PassController = make()

    private static func make() -> PassController {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Auto-Smaart", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let session = OfficialSmaartSession(wire: URLSessionSmaartWire())
        try? session.openSession()
        let bank = CurveBank(fileURL: root.appendingPathComponent("bank.json"))
        let outputs = OutputStore(fileURL: root.appendingPathComponent("outputs.json"))
        let link = LiveConsoleLink { box.host } port: { box.port }
        let pass = PassController(reader: session, link: link, bank: bank, outputs: outputs)
        pass.endpoint = box
        pass.refreshSessionFlag()
        return pass
    }
}

final class LiveConsoleLink: OscLink {
    private let host: () -> String
    private let port: () -> String
    init(host: @escaping () -> String, port: @escaping () -> String) {
        self.host = host
        self.port = port
    }
    public func read(address: String) throws -> OscValue {
        let client = try open()
        defer { client.close() }
        return try client.read(address: address)
    }
    public func write(address: String, value: OscValue) throws {
        let client = try open()
        defer { client.close() }
        try client.write(address: address, value: value)
    }
    private func open() throws -> Quantum225Client {
        guard let port = UInt16(port()), !host().isEmpty else { throw OscTransportError.badHost }
        return try Quantum225Client(host: host(), port: port)
    }
}
```

`ConsoleEndpoint` is declared in Task 8. `setHost` and `setPort` already call `endpoint?.update`.

`README.md`

~~~~markdown
# Auto-Smaart

Mac app for one DiGiCo Quantum 225 Matrix output per pass. It reads Rational Acoustics Smaart through the local official API and writes delay and EQ only after confirm.

## Run the tests

On a Mac, from this directory:

```bash
swift test
```

`swift test --filter Quantum225HardwareTests` skips unless all of these are set:

- `AUTO_SMAART_HARDWARE=1`
- `AUTO_SMAART_CONSOLE_HOST` — the console IP typed into Pick
- `AUTO_SMAART_CONSOLE_PORT` — the console OSC port
- `AUTO_SMAART_MATRIX` — one output from 1 through 12

That test writes delay to both delay addresses, writes at least one EQ band, remeasures, then undoes the write. Smaart must be open with the API enabled on port 26000.

## Run the app

```bash
swift run AutoSmaart
```

There is no default console address. Nothing is sent before Confirm delay write or Confirm EQ write.
~~~~

- [ ] **Step 4: Run test to verify it passes**

Run from the repository root:

```bash
swift test --filter 'PassReadTests|PassDelayTests|PassEqTests|PassUndoTests|PresenterTests|ShellTests|SourceGuardTests|RoundingTests|DelaySuggestionTests|SessionTests|CurveBankTests|FitTests|OscTests|FakeConsoleTests'
swift test --filter Quantum225HardwareTests
swift build --target AutoSmaartApp
```

Expected: the filtered suite passes. `Quantum225HardwareTests` skips with the hardware message when the variables are unset. `swift build --target AutoSmaartApp` succeeds. Do not claim the hardware pass passed unless `AUTO_SMAART_HARDWARE=1` and the assertions ran.

- [ ] **Step 5: Commit**

```bash
git add Sources/AutoSmaartUI/AppRuntime.swift Sources/AutoSmaartPass/Pass.swift Sources/AutoSmaartApp/AutoSmaartApp.swift README.md Tests/HardwareTests Tests/AutoSmaartPassTests/SourceGuardTests.swift
git commit -m "feat: wire the Mac app and the Quantum 225 hardware pass"
```

---

## Spec coverage

The implementer does not need to expand this list. It is the check used to write the tasks.

- Smaart reader, finder-then-impulse, recorded fixtures: Tasks 2 and 3.
- Curve bank, blank name, replace, relaunch: Tasks 4 and 8.
- Deterministic fit, 1.0 dB, no overlap, phase ignored, 48 kHz model: Task 5.
- Addresses, silence before confirm, restore, fake UDP console: Tasks 6 and 7.
- One of twelve outputs, no default host, no OSC on navigation: Task 8.
- Delay confirm, both arguments, no range clamp, remeasure, retry, no skip: Task 9.
- EQ order, unused bands, zero-band Compare, remeasure failure: Task 10.
- Undo and last-write line: Task 11.
- Copy, OSC armed, em dash: Task 12.
- Four screens and the design-system tokens: Task 13.
- One real Quantum 225 pass: Task 14.
