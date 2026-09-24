import AppKit

// Exact bundle/path matching; no AX, automation permissions or force-kill.
let expected = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Aparte.app").standardizedFileURL
let allApps = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.aparte.Aparte")
let installedApps = allApps.filter { $0.bundleURL?.standardizedFileURL == expected }
let projectArtifacts = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("artifacts", isDirectory: true).standardizedFileURL.path + "/"
let projectCopies = allApps.filter { app in
    guard let path = app.bundleURL?.standardizedFileURL.path else { return false }
    return path.hasPrefix(projectArtifacts)
}
let action = CommandLine.arguments.dropFirst().first
if action == "--quit" || action == "--quit-project-copies" {
    let apps = action == "--quit" ? installedApps : projectCopies
    for app in apps {
        guard app.terminate() else { fputs("Aparté refused orderly quit. Finish the current operation and quit it manually.\n", stderr); exit(2) }
    }
    let deadline = Date().addingTimeInterval(8)
    while apps.contains(where: { !$0.isTerminated }) && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    guard apps.allSatisfy({ $0.isTerminated }) else { fputs("Aparté has not quit; it was not force-killed.\n", stderr); exit(2) }
} else if !installedApps.isEmpty {
    fputs("The installed Aparté is running. Quit it before installation, or run xcrun swift scripts/app-lifecycle.swift --quit.\n", stderr)
    exit(2)
} else if !allApps.isEmpty {
    fputs("Another Aparté copy is running. Quit it before installation; for copies under this project's artifacts directory, run xcrun swift scripts/app-lifecycle.swift --quit-project-copies.\n", stderr)
    exit(2)
}
