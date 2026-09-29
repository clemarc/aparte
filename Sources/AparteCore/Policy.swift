import Foundation

public enum AparteError: String, Error, LocalizedError, Sendable {
    case invalidAsset, insufficientSpace, unavailableModel, unsupportedLanguage, invalidAudio, unavailableDevice, permissions, busy, timeout, cancelled, unsafeTarget, clipboardUnavailable, inference
    public var errorDescription: String? {
        switch self {
        case .invalidAsset: return "Model verification failed. Import a matching model or download again."
        case .insufficientSpace: return "Not enough disk space for a verified model installation."
        case .unavailableModel: return "Install and prepare a model in Settings."
        case .unsupportedLanguage: return "This model cannot use the selected language. Choose Auto or another supported language."
        case .invalidAudio: return "No usable audio was captured."
        case .unavailableDevice: return "Microphone unavailable or changed. Recheck the default input."
        case .permissions: return "Permission required. Open Settings and recheck access."
        case .busy: return "Busy — wait for the current operation to finish."
        case .timeout: return "Transcription exceeded 30 seconds. Please retry with a shorter recording."
        case .cancelled: return "Cancelled."
        case .unsafeTarget: return "Target changed or cannot be safely edited. Use Recovery."
        case .clipboardUnavailable: return "Clipboard cannot be preserved. Use explicit Copy in Recovery."
        case .inference: return "Transcription failed. Retry or prepare the model again."
        }
    }
}

public enum TranscriptPolicy {
    public static func sanitize(_ text: String) -> String {
        let separators = CharacterSet(charactersIn: "\t\n\r\u{0085}\u{2028}\u{2029}")
        let cleaned = text.unicodeScalars.compactMap { scalar -> String? in
            if separators.contains(scalar) { return " " }
            if scalar.properties.generalCategory == .control || (scalar.properties.generalCategory == .format && scalar.value != 0x200C && scalar.value != 0x200D) { return nil }
            return String(scalar)
        }.joined()
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// Reject a whole failed result; never delete individual uncertain words.
    public static func isRepetitive(_ text: String) -> Bool {
        let words = text.lowercased().split(whereSeparator: { $0.isWhitespace })
        guard words.count >= 12 else { return false }
        for width in 1...min(8, words.count / 4) {
            for start in 0...(words.count - width * 4) {
                let phrase = Array(words[start..<start+width])
                if (1..<4).allSatisfy({ Array(words[(start+$0*width)..<(start+($0+1)*width)]) == phrase }) { return true }
            }
        }
        return false
    }
    public static func hasSpeechEnergy(_ audio: [Float]) -> Bool {
        guard audio.count >= 4_000, audio.allSatisfy(\.isFinite) else { return false }
        // Low floor (-60 dBFS); neural no-speech filtering supplies the second gate.
        let square = audio.reduce(0.0) { $0 + Double($1) * Double($1) }
        return sqrt(square / Double(audio.count)) >= 0.001
    }
}

public enum SessionState: String, Sendable {
    case needsSetup = "Needs setup", preparing = "Preparing", ready = "Ready", startingCapture = "Starting", recording = "Recording", transcribing = "Transcribing", inserting = "Inserting", recovery = "Recovery", error = "Error"
}

/// Pure transaction reducer. A cancelled operation keeps its engine lease until unwind.
public struct SessionMachine: Sendable {
    public private(set) var state: SessionState = .needsSetup
    public private(set) var id: UUID?
    public private(set) var engineBusy = false
    public private(set) var invalidatedTarget = false
    public init() {}
    public mutating func prepared(_ ready: Bool, clearError: Bool = false) { guard id == nil, !engineBusy, state != .error || clearError || !ready else { return }; state = ready ? .ready : .needsSetup }
    public mutating func preparing() { guard id == nil, !engineBusy else { return }; state = .preparing }
    public mutating func begin() -> UUID? {
        guard (state == .ready || state == .recovery), !engineBusy else { return nil }
        let next = UUID(); id = next; invalidatedTarget = false; state = .startingCapture; return next
    }
    public mutating func started(_ token: UUID) -> Bool { guard id == token, state == .startingCapture else { return false }; state = .recording; return true }
    public func isCapturing(_ token: UUID) -> Bool {
        id == token && (state == .startingCapture || state == .recording)
    }
    public mutating func release(_ token: UUID) -> Bool {
        guard id == token else { return false }
        if state == .startingCapture { cancel(); return false }
        guard state == .recording else { return false }
        state = .transcribing; engineBusy = true; return true
    }
    public mutating func invalidateTarget() { if id != nil { invalidatedTarget = true } }
    public mutating func decoded(_ token: UUID) -> Bool { guard id == token, state == .transcribing else { return false }; engineBusy = false; state = .inserting; return true }
    public mutating func unwind() { engineBusy = false; if id == nil && state != .error { state = .ready } }
    public mutating func finish(_ token: UUID, recovery: Bool = false) { guard id == token else { return }; id = nil; state = recovery ? .recovery : .ready }
    public mutating func cancel() { id = nil; invalidatedTarget = true; state = engineBusy ? .transcribing : .ready }
    public mutating func fail() { id = nil; state = .error }
}

public struct Shortcut: Codable, Equatable, Sendable {
    public var key: UInt16
    public var modifiers: UInt64
    public static let control: UInt64 = 1 << 18, option: UInt64 = 1 << 19, command: UInt64 = 1 << 20, shift: UInt64 = 1 << 17, function: UInt64 = 1 << 23
    public static let mask = control | option | command | shift | function
    public static let modifierOnlyKey = UInt16.max
    public static let standard = Shortcut(key: 49, modifiers: control | option)
    public init(key: UInt16, modifiers: UInt64) { self.key = key; self.modifiers = modifiers }
    public var isValid: Bool {
        validationMessage == nil
    }
    /// A single policy supplies both persisted-binding validation and recorder guidance.
    public var validationMessage: String? {
        guard modifiers & ~Self.mask == 0 else { return "This modifier is unsupported." }
        if key == Self.modifierOnlyKey { return modifiers != 0 && modifiers.nonzeroBitCount == 1 ? nil : "Choose one modifier by itself." }
        // Explicit keys only: letters, numbers, punctuation, space. No Fn, Return, Escape, Tab, deletion or modifier keys.
        let keys: Set<UInt16> = Set(0...35).union([37,38,39,40,41,42,43,44,45,46,47,49,50])
        guard keys.contains(key) else { return "Use a letter, number, punctuation key or Space." }
        if modifiers == Self.command && [0,6,7,8,9,12,13,35,49].contains(key) { return "That shortcut is reserved for a common app or macOS action. Add Control or Option, or choose another key." }
        if key == 49 && (modifiers == Self.control || modifiers == Self.command || modifiers == Self.option | Self.command || modifiers == Self.function) { return "That Space shortcut is reserved by macOS. Try another key." }
        return nil
    }
}

public enum RecordingGesture: String, Codable, Sendable, CaseIterable { case hold, doubleTap }

/// Monotonic-time double-tap recognizer. A lone tap never requests microphone capture.
public struct DoubleTapGesture: Sendable {
    public enum Event: Equatable { case none, start, stop }
    private var firstDown: TimeInterval?
    private var firstUp: TimeInterval?
    private var recording = false
    public init() {}
    public mutating func press(at time: TimeInterval) -> Event {
        if recording { recording = false; firstDown = nil; firstUp = nil; return .stop }
        if let firstUp, time >= firstUp, time - firstUp <= 0.35 {
            self.firstUp = nil; firstDown = nil; recording = true; return .start
        }
        firstUp = nil; firstDown = time
        return .none
    }
    public mutating func release(at time: TimeInterval) {
        guard let firstDown else { return }
        firstUp = time >= firstDown && time - firstDown <= 0.35 ? time : nil
        self.firstDown = nil
    }
    public mutating func reset() { firstDown = nil; firstUp = nil; recording = false }
}

/// Codes from WhisperKit 1.1.0 Constants.languages, with aliases removed.
public enum SpeechLanguages {
    public static let codes = Set("en zh de es ru ko fr ja pt tr pl ca nl ar sv it id hi fi vi he uk el ms cs ro da hu ta no th ur hr bg lt la mi ml cy sk te fa lv bn sr az sl kn et mk br eu is hy ne mn bs kk sq sw gl mr pa si km sn yo so af oc ka be tg sd gu am yi lo uz fo ht ps tk nn mt sa lb my bo tl mg as tt haw ln ha ba jw su yue".split(separator: " ").map(String.init))
    public static func supports(_ code: String, model: String) -> Bool { code == "auto" || (codes.contains(code) && (model == "turbo" || code != "yue") && !model.hasSuffix(".en")) || (code == "en" && model.hasSuffix(".en")) }
}

/// Gesture ownership survives cancellation and rebinding until the original key-up.
public struct GestureMatcher: Sendable {
    public enum Action: Equatable { case pass, consume, down, up, escape, interaction }
    public var binding = Shortcut.standard
    private var ownedKey: UInt16?
    private var ownedModifiers: UInt64 = 0
    private var holding = false
    private var modifierSuppressedUntilClear = false
    private var escapeOwned = false
    public var ownsGesture: Bool { ownedKey != nil || escapeOwned }
    public init() {}
    public mutating func key(_ key: UInt16, down: Bool, flags: UInt64, repeated: Bool = false, active: Bool, ownEvent: Bool = false, allowNewBinding: Bool = true) -> Action {
        if ownEvent { return .pass }
        if key == 53 {
            if down && escapeOwned { return .consume }
            if !down && escapeOwned { escapeOwned = false; return .consume }
            if down && active { escapeOwned = true; return .escape }
        }
        if key == ownedKey {
            if down { return .consume }
            ownedKey = nil; let ended = holding; holding = false; return ended ? .up : .consume
        }
        if down && holding && binding.key == Shortcut.modifierOnlyKey {
            holding = false; modifierSuppressedUntilClear = true
            return .up
        }
        if allowNewBinding && down && !repeated && key == binding.key && flags & Shortcut.mask == binding.modifiers {
            ownedKey = key; ownedModifiers = binding.modifiers; holding = true; return .down
        }
        return down && active ? .interaction : .pass
    }
    public mutating func flags(_ flags: UInt64) -> Action {
        if binding.key == Shortcut.modifierOnlyKey {
            if modifierSuppressedUntilClear {
                if flags & binding.modifiers == 0 { modifierSuppressedUntilClear = false }
                return .pass
            }
            if holding && flags & Shortcut.mask != binding.modifiers { holding = false; modifierSuppressedUntilClear = flags & binding.modifiers != 0; return .up }
            if !holding && flags & binding.modifiers != 0 && flags & Shortcut.mask != binding.modifiers { modifierSuppressedUntilClear = true; return .pass }
            if !holding && flags & Shortcut.mask == binding.modifiers { holding = true; return .down }
        }
        if holding && flags & ownedModifiers != ownedModifiers { holding = false; return .up }
        return .pass
    }
}

public struct Preferences: Codable, Sendable {
    public var schema = 1
    public var shortcut = Shortcut.standard
    public var language = "auto"
    public var model = "small"
    public var gesture: RecordingGesture = .hold
    public init() {}
    private enum CodingKeys: String, CodingKey { case schema, shortcut, language, model, gesture }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schema = try values.decode(Int.self, forKey: .schema)
        shortcut = try values.decode(Shortcut.self, forKey: .shortcut)
        language = try values.decode(String.self, forKey: .language)
        model = try values.decode(String.self, forKey: .model)
        gesture = (try? values.decode(RecordingGesture.self, forKey: .gesture)) ?? .hold
    }
    public static func decode(_ data: Data?) -> Preferences {
        guard let data, var p = try? JSONDecoder().decode(Self.self, from: data), p.schema == 1 else { return .init() }
        if !p.shortcut.isValid { p.shortcut = .standard }
        if !["base", "small", "medium", "turbo", "base.en"].contains(p.model) { p.model = "small" }
        if !SpeechLanguages.supports(p.language, model: p.model) { p.language = "auto" }
        return p
    }
}
