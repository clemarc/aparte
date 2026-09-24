import AppKit

// Only the stable installed Aparté; no AX, automation permissions or force-kill.
let expected = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Aparte.app").standardizedFileURL
let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.aparte.Aparte").filter { $0.bundleURL?.standardizedFileURL == expected }
if CommandLine.arguments.dropFirst().first == "--quit" {
    for app in apps {
        guard app.terminate() else { fputs("Aparté refused orderly quit. Finish the current operation and quit it manually.\n", stderr); exit(2) }
    }
    let deadline = Date().addingTimeInterval(8)
    while apps.contains(where: { !$0.isTerminated }) && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    guard apps.allSatisfy({ $0.isTerminated }) else { fputs("Aparté has not quit; it was not force-killed.\n", stderr); exit(2) }
} else if !apps.isEmpty {
    fputs("Aparté is running. Quit it before installation, or explicitly run xcrun swift scripts/app-lifecycle.swift --quit.\n", stderr)
    exit(2)
}
