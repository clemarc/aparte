import AppKit
import SwiftUI
import AparteCore

extension Shortcut {
    var displayLabel: String {
        let modifiers = Self.modifierLabel(self.modifiers)
        let names: [UInt16: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",10:"§",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",37:"L",38:"J",39:"’",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",49:"Space",50:"`"]
        return modifiers + (names[key] ?? "Key \(key)")
    }
    static func modifierLabel(_ flags: UInt64) -> String {
        [(Self.control,"⌃"),(Self.option,"⌥"),(Self.shift,"⇧"),(Self.command,"⌘")].filter { flags & $0.0 != 0 }.map(\.1).joined()
    }
}

/// An actual first responder receives modifier changes and Command key equivalents.
struct ShortcutRecorder: NSViewRepresentable {
    var preview: (String) -> Void
    var accept: (Shortcut?) -> Void
    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView(); view.preview = preview; view.accept = accept; return view
    }
    func updateNSView(_ view: CaptureView, context: Context) { view.preview = preview; view.accept = accept }
    static func dismantleNSView(_ view: CaptureView, coordinator: ()) { view.stop() }
    final class CaptureView: NSView {
        private var monitor: Any?
        private var pending: Shortcut?
        var preview: ((String) -> Void)?
        var accept: ((Shortcut?) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            if window != nil {
                // Intercept before menu key-equivalent dispatch (e.g. reserved Cmd-Q).
                // Unlike a SwiftUI value-owned monitor, this follows the real responder.
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
                    guard let self, self.window?.isKeyWindow == true, self.window?.firstResponder === self else { return event }
                    if event.type == .flagsChanged { self.flagsChanged(with: event); return event }
                    if event.type == .keyUp { self.keyUp(with: event); return nil }
                    self.keyDown(with: event); return nil
                }
            }
            DispatchQueue.main.async { [weak self] in guard let self, let window = self.window else { return }; window.makeFirstResponder(self) }
            setAccessibilityElement(true); setAccessibilityLabel("Shortcut recorder. Press modifiers and a key. Escape cancels.")
        }
        func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.controlBackgroundColor.setFill(); NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
            ("Press a shortcut here · Esc cancels" as NSString).draw(at: NSPoint(x: 10, y: 12), withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor])
        }
        override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
        override func flagsChanged(with event: NSEvent) {
            guard pending == nil else { return }
            if event.modifierFlags.contains(.function) { preview?("Fn / Globe cannot be used by this version. Try Control or Option plus a key."); return }
            let modifiers = UInt64(event.modifierFlags.rawValue) & Shortcut.mask
            // Keep a rejection readable after the user releases the chord.
            guard modifiers != 0 else { return }
            preview?(Shortcut.modifierLabel(modifiers) + " … add a letter, number or Space")
        }
        override func keyDown(with event: NSEvent) {
            guard !event.isARepeat else { return }
            if event.keyCode == 53 { accept?(nil); return }
            guard !event.modifierFlags.contains(.function) else {
                preview?("Fn / Globe cannot be used by this version. Try Control or Option plus a key."); return
            }
            let chord = Shortcut(key: event.keyCode, modifiers: UInt64(event.modifierFlags.rawValue) & Shortcut.mask)
            if chord.isValid { pending = chord; preview?("\(chord.displayLabel) — release to review") }
            else { preview?(chord.validationMessage ?? "Try another shortcut.") }
        }
        override func keyUp(with event: NSEvent) {
            guard let chord = pending, event.keyCode == chord.key else { return }
            pending = nil; accept?(chord)
        }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window?.firstResponder === self else { return false }; keyDown(with: event); return true
        }
    }
}

/// This editor belongs to Aparté. It tests capture/ASR and exact selected-range insertion,
/// without claiming that another application's AX or clipboard adapter was validated.
final class SetupTextView: NSTextView, NSTextViewDelegate {
    private(set) var revision: UInt64 = 0
    var onInteraction: (() -> Void)?
    var onClose: (() -> Void)?
    var isFocused: Bool { NSApp.isActive && window?.isKeyWindow == true && window?.firstResponder === self }
    func textDidChange(_ notification: Notification) { revision &+= 1; onInteraction?() }
    func textViewDidChangeSelection(_ notification: Notification) { revision &+= 1; onInteraction?() }
    override func viewWillMove(toWindow newWindow: NSWindow?) { if newWindow == nil { onClose?() }; super.viewWillMove(toWindow: newWindow) }
    func receipt() -> TestInsertionReceipt? { isFocused ? TestInsertionReceipt(revision: revision, selection: selectedRange()) : nil }
    func apply(_ text: String, receipt: TestInsertionReceipt) -> Bool {
        guard receipt.matches(revision: revision, selection: selectedRange(), isFocused: isFocused, textLength: (string as NSString).length) else { return false }
        insertText(text, replacementRange: selectedRange())
        return true
    }
    func clear() { string = ""; revision &+= 1; undoManager?.removeAllActions() }
}
struct SetupEditor: NSViewRepresentable {
    let model: Coordinator
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        let editor = SetupTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 120))
        editor.minSize = NSSize(width: 0, height: 120)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.containerSize = NSSize(width: 500, height: CGFloat.greatestFiniteMagnitude)
        editor.isRichText = false; editor.isAutomaticQuoteSubstitutionEnabled = false; editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false; editor.isAutomaticSpellingCorrectionEnabled = false
        editor.font = .systemFont(ofSize: 14); editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]; editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 8, height: 8); editor.delegate = editor; editor.allowsUndo = false
        editor.setAccessibilityLabel("End-to-end dictation test text box")
        editor.onInteraction = { [weak model] in model?.invalidateTestTarget() }
        editor.onClose = { [weak model] in model?.closeSetupTests() }
        scroll.documentView = editor; model.testEditor = editor
        return scroll
    }
    func updateNSView(_ view: NSScrollView, context: Context) {}
}
