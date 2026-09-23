import AppKit
import AVFoundation
import ApplicationServices

struct PermissionStatus {
    let microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    let accessibility = AXIsProcessTrusted()
    let listening = CGPreflightListenEventAccess()
    let posting = CGPreflightPostEventAccess()
    var canDictate: Bool { microphone == .authorized && accessibility }
    var summary: String {
        let mic: String
        switch microphone { case .authorized: mic = "Granted"; case .denied: mic = "Denied"; case .restricted: mic = "Restricted"; default: mic = "Not requested" }
        return "Microphone: \(mic) · Accessibility: \(accessibility ? "Granted" : "Required") · Clipboard event posting: \(posting ? "Available" : "Unavailable") · Listen preflight: \(listening ? "Available" : "Unavailable")"
    }
    @MainActor static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)") { NSWorkspace.shared.open(url) }
    }
    static func requestMicrophone() async -> Bool {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }
}
