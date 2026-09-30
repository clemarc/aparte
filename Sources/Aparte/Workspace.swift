import AppKit
import SwiftUI
import ServiceManagement
import AparteCore

// Navigation belongs to the retained workspace, independent of the dictation transaction.
enum WorkspaceSection: String, CaseIterable, Identifiable {
    case tryIt = "Try it", processing = "Processing", shortcuts = "Shortcuts", settings = "Settings"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .tryIt: return "mic"; case .processing: return "slider.horizontal.3"; case .shortcuts: return "keyboard"; case .settings: return "gearshape" }
    }
    var subtitle: String {
        switch self {
        case .tryIt: return "Speak and see your words."
        case .processing: return "Choose how your voice becomes text."
        case .shortcuts: return "Choose how dictation starts and stops."
        case .settings: return "Access, startup and privacy."
        }
    }
}
@MainActor final class WorkspaceNavigation: ObservableObject {
    @Published var section: WorkspaceSection = .tryIt
    @Published var showsSetup = !UserDefaults.standard.bool(forKey: "workspace.setupCompleted.v1")
    @Published var setupStep = 0
    init() { if showsSetup { section = .settings } }
    func goToSetup(_ step: Int) {
        setupStep = step; section = [.settings, .processing, .tryIt][step]; showsSetup = true
    }
    func finishSetup() {
        UserDefaults.standard.set(true, forKey: "workspace.setupCompleted.v1"); showsSetup = false; section = .tryIt
    }
}

struct WorkspaceView: View {
    @ObservedObject var model: Coordinator
    @ObservedObject var navigation: WorkspaceNavigation
    var showRecovery: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    AparteLogo().foregroundStyle(.tint).frame(width: 38, height: 30)
                    Text(AppVersion.displayName).font(.title2.weight(.semibold))
                }.padding(.top, 10)
                VStack(spacing: 5) {
                    ForEach(WorkspaceSection.allCases) { section in
                        Button { navigation.section = section } label: {
                            Label(section.rawValue, systemImage: section.symbol)
                                .font(.system(size: 14, weight: navigation.section == section ? .semibold : .regular))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 11)
                                .background(navigation.section == section ? Color.accentColor.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).accessibilityAddTraits(navigation.section == section ? .isSelected : [])
                    }
                }
                Spacer()
                Button { navigation.goToSetup(0) } label: { Label("Setup guide", systemImage: "checklist") }.buttonStyle(.plain)
                Divider()
                Label("On-device transcription", systemImage: "lock.shield").font(.caption)
                Text(AppVersion.detailed).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }.padding(20).frame(width: 220).frame(maxHeight: .infinity).background(.regularMaterial)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(navigation.section.rawValue).font(.system(size: 28, weight: .bold))
                            Text(navigation.section.subtitle).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(model: model)
                    }
                    if navigation.showsSetup { setupGuide }
                    switch navigation.section {
                    case .tryIt: TryItView(model: model, navigation: navigation, showRecovery: showRecovery)
                    case .processing: ProcessingView(model: model, navigation: navigation)
                    case .shortcuts: ShortcutsView(model: model, navigation: navigation)
                    case .settings: PreferencesView(model: model)
                    }
                }.padding(28).frame(maxWidth: 860, alignment: .leading).frame(maxWidth: .infinity)
            }.background(Color(nsColor: .windowBackgroundColor))
        }.frame(minWidth: 860, minHeight: 600)
        .onAppear { model.recheck() }
        .onChange(of: navigation.section) { _, _ in model.closeSetupTests() }
        .onDisappear { model.closeSetupTests() }
    }
    private var setupGuide: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Set up \(AppVersion.displayName)").font(.headline)
                Spacer()
                Button("Hide guide") { navigation.showsSetup = false }.buttonStyle(.link)
            }
            HStack(spacing: 16) {
                ForEach(0..<3) { step in
                    Button { navigation.goToSetup(step) } label: {
                        Label(["1 · Access", "2 · Processing", "3 · Try it"][step], systemImage: stepComplete(step) ? "checkmark.circle.fill" : "circle")
                            .font(.callout.weight(navigation.setupStep == step ? .semibold : .regular))
                    }.buttonStyle(.plain).foregroundStyle(navigation.setupStep == step ? Color.accentColor : Color.secondary)
                    if step < 2 { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
                }
            }
            Text(model.readinessSummary).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                if navigation.setupStep < 2 {
                    Button(navigation.setupStep == 0 ? "Choose processing →" : "Try dictation →") { navigation.goToSetup(navigation.setupStep + 1) }
                } else {
                    Button("Finish setup") { navigation.finishSetup() }.disabled(!model.setupReadiness.canDictate || model.sessionBusy)
                    Text("Finish when system-wide dictation is ready. Tests are optional.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
    private func stepComplete(_ step: Int) -> Bool {
        if step == 0 { return model.setupReadiness.microphone && model.setupReadiness.accessibility && model.setupReadiness.shortcut }
        if step == 1 { return model.setupReadiness.model }
        return false // Visiting a test is not evidence that capture or external insertion passed.
    }
}

struct StatusBadge: View {
    @ObservedObject var model: Coordinator
    var body: some View {
        Label(model.state.rawValue, systemImage: model.setupReadiness.canDictate && !model.sessionBusy ? "checkmark.circle.fill" : "circle.fill")
            .font(.caption.weight(.semibold)).foregroundStyle(model.state == .recording ? Color.red : (model.setupReadiness.canDictate ? Color.green : Color.secondary))
            .padding(.horizontal, 12).padding(.vertical, 7).background(.quaternary, in: Capsule())
            .accessibilityLabel("Dictation status: \(model.state.rawValue)")
    }
}

struct WorkspaceCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content
    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) { self.title = title; self.subtitle = subtitle; self.content = content }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            content()
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.07)))
    }
}

struct TryItView: View {
    @ObservedObject var model: Coordinator
    @ObservedObject var navigation: WorkspaceNavigation
    var showRecovery: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !model.setupReadiness.canDictate {
                HStack(alignment: .top) {
                    Image(systemName: "info.circle").foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.readinessSummary).font(.callout)
                        HStack {
                            Button("Review access") { navigation.section = .settings }
                            Button("Choose a model") { navigation.section = .processing }
                        }.buttonStyle(.link)
                    }
                }
            }
            HStack {
                Label(model.preferences.model.capitalized, systemImage: "cpu")
                Text("· \(languageLabel(model.preferences.language)) · Original text").foregroundStyle(.secondary)
                Spacer()
                Button("Change") { navigation.section = .processing }.buttonStyle(.link)
            }.font(.callout)
            WorkspaceCard("Microphone check", subtitle: "Start, wait for Recording, speak, then stop to transcribe. No text is sent to another app.") {
                HStack {
                    Button { model.startMicrophoneTest() } label: { Label("Start recording", systemImage: "mic.fill") }
                        .buttonStyle(.borderedProminent).disabled(!model.canStartMicrophoneTest || model.recordingBinding)
                    Button("Stop & transcribe") { model.stopMicrophoneTest() }.disabled(!model.microphoneTestActive)
                    if model.sessionBusy { Button("Cancel") { model.cancel("Test cancelled.") } }
                }
                ProgressView(value: model.inputLevel).tint(model.microphoneTestActive ? .accentColor : .secondary).accessibilityLabel("Microphone input level")
                Text(model.inputStatus).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Button("Sound Input Settings") { openSoundInput() }.buttonStyle(.link)
                if !model.setupReadiness.canTestMicrophone { Text("Needs Microphone access and a prepared model. Accessibility is not required for this check.").font(.caption).foregroundStyle(.secondary) }
                if model.lastResultWasTest, let text = model.recoveryText {
                    Divider()
                    Text("Transcript").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            WorkspaceCard("Try your shortcut", subtitle: "Click in the box. Hold \(model.preferences.shortcut.displayLabel) to talk and release to finish, or double-tap to start and tap once to stop.") {
                SetupEditor(model: model).frame(height: 130)
                Text(model.testStatus).font(.callout).accessibilityLabel("Test status: \(model.testStatus)")
                HStack {
                    Button("Change shortcut") { navigation.section = .shortcuts }.buttonStyle(.link)
                    Spacer()
                    Button("Clear test results") { model.closeSetupTests() }
                }
                Text("In-app delivery is reported separately from the global listener. This box does not validate insertion into another app.").font(.caption).foregroundStyle(.secondary)
            }
            Text(model.notice).font(.callout).textSelection(.enabled)
            if model.recoveryText != nil && !model.lastResultWasTest {
                WorkspaceCard(model.recoveryUncertain ? "Insertion unconfirmed" : "A dictation is in Recovery") {
                    Text(model.recoveryUncertain ? "Check the target before pasting again; text may already have been inserted." : model.recoveryReason).font(.callout)
                    Button("Open Recovery") { showRecovery() }
                }
            }
            Text("Tests stay in memory and clear after five minutes, when you leave Try it or close the workspace, on lock or quit. No recordings or transcripts are saved. Escape cancels; no Return is sent.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SpeechLanguagePicker: View {
    @ObservedObject var model: Coordinator
    @State private var showing = false
    @State private var query = ""
    private var available: [String] {
        SpeechLanguages.codes.filter { SpeechLanguages.supports($0, model: model.preferences.model) }
            .sorted { languageLabel($0).localizedStandardCompare(languageLabel($1)) == .orderedAscending }
    }
    private var filtered: [String] {
        query.isEmpty ? available : available.filter { languageLabel($0).localizedStandardContains(query) || $0.localizedStandardContains(query) }
    }
    var body: some View {
        HStack {
            Text("Spoken language")
            Spacer()
            Button(model.preferences.language == "auto" && model.preferences.model.hasSuffix(".en") ? "Auto · English only" : languageLabel(model.preferences.language)) { query = ""; showing = true }
                .disabled(model.sessionBusy)
                .popover(isPresented: $showing) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Search languages", text: $query).textFieldStyle(.roundedBorder)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                choice("auto")
                                ForEach(filtered, id: \.self) { choice($0) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(height: 260)
                    }.frame(width: 270).padding()
                }
        }
        Text("Auto detects the language with a multilingual model. Choosing a language gives recognition a fixed prompt; it does not translate or select an accent.").font(.caption).foregroundStyle(.secondary)
    }
    private func choice(_ code: String) -> some View {
        Button { model.preferences.language = code; model.persist(); showing = false } label: {
            HStack { Text(languageLabel(code)); Spacer(); if code == model.preferences.language { Image(systemName: "checkmark") } }
                .contentShape(Rectangle())
        }.buttonStyle(.plain).padding(.vertical, 5).padding(.horizontal, 7)
    }
}

struct ProcessingView: View {
    @ObservedObject var model: Coordinator
    @ObservedObject var navigation: WorkspaceNavigation
    @State private var selectedModelID = "small"
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                pipelineStage("1", "Recognition", "On this Mac")
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                pipelineStage("2", "Text handling", "Off · original text")
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                pipelineStage("3", "Insertion", "Original text field")
            }
            WorkspaceCard("Speech recognition", subtitle: "Active: \(model.preferences.model.capitalized) · \(model.modelStatus)") {
                SpeechLanguagePicker(model: model)
                if let catalog = model.catalog {
                    Picker("Model to compare", selection: $selectedModelID) {
                        ForEach(catalog.models) { entry in Text(entry.displayName + (entry.id == model.preferences.model ? " · Active" : "")).tag(entry.id) }
                    }
                    if let entry = catalog.models.first(where: { $0.id == selectedModelID }) {
                        let comparison = ModelComparison.forModel(entry.id)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.displayName).font(.title3.weight(.semibold))
                                Text("\(model.installed(entry.id) ? "Installed" : "Not installed") · \(bytes(entry.installedBytes)) on disk").foregroundStyle(.secondary)
                            }
                            Spacer()
                            if entry.id == "small" { Text("Recommended").font(.caption.weight(.semibold)).foregroundStyle(.tint) }
                        }
                        Text(comparison.quality).font(.callout).foregroundStyle(.secondary)
                        HStack(spacing: 26) {
                            metric("Prepare", comparison.prepare)
                            metric("8 s decode p95", comparison.warmP95)
                            metric("Peak process RAM", comparison.peakMemory)
                        }
                        HStack {
                            if model.installed(entry.id) {
                                Button(!SpeechLanguages.supports(model.preferences.language, model: entry.id) ? "Use with Auto language" : (entry.id == model.preferences.model && model.modelLoaded ? "Prepare again" : "Prepare / Use")) { model.prepare(entry.id) }.buttonStyle(.borderedProminent)
                            } else {
                                Button("Download \(bytes(entry.installedBytes))") { model.installModel(entry.id) }.buttonStyle(.borderedProminent)
                            }
                            Button("Import…") { model.importModel(entry.id) }
                            Button("Delete", role: .destructive) { model.deleteModel(entry.id) }.disabled(!model.installed(entry.id))
                        }.disabled(model.sessionBusy || model.installing)
                        Text("\(bytes(entry.temporaryBytes)) free space needed to install. Selecting a model here previews it; the active model changes only after successful preparation.").font(.caption).foregroundStyle(.secondary)
                    }
                } else { Text("The bundled model catalog is unavailable. Reopen the installed app and check its version.").foregroundStyle(.red) }
                if model.installing {
                    ProgressView(value: model.installProgress)
                    Button("Cancel installation") { model.cancelInstall() }
                }
                Text(model.notice).font(.callout).textSelection(.enabled)
                Text("Downloads start only when you click. Installed models work offline; nothing downloads during dictation.").font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("Compare all models") {
                VStack(alignment: .leading, spacing: 12) {
                    Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 10) {
                        GridRow { Text("Model"); Text("Disk"); Text("Prepare"); Text("8 s p95"); Text("Peak RAM") }.fontWeight(.semibold)
                        ForEach(model.catalog?.models ?? []) { entry in
                            let c = ModelComparison.forModel(entry.id)
                            GridRow { Text(entry.id.capitalized); Text(bytes(entry.installedBytes)); Text(c.prepare); Text(c.warmP95); Text(c.peakMemory) }
                        }
                    }.font(.caption)
                        Text("Figures were measured on M5 Pro / 48 GB with synthetic audio. English-only Base was evaluated on English clips; it cannot recognize French. File decoding is not microphone-to-insertion latency; these figures do not predict your accent.").font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 12)
            }
            WorkspaceCard("Text handling", subtitle: "Off · keep the original transcript") {
                Text("Aparté inserts the recognized words with ordinary punctuation and safe single-line formatting. It does not rewrite or translate your speech.").font(.callout)
                Text("Optional text handling is planned for a later version. This version uses your original transcript.").font(.caption).foregroundStyle(.secondary)
            }
            Button("Compare with your voice →") { navigation.section = .tryIt }.buttonStyle(.link)
        }.onAppear { selectedModelID = model.preferences.model }
            .onChange(of: model.preferences.model) { selectedModelID = model.preferences.model }
    }
    private func pipelineStage(_ number: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(number) · \(title)").font(.callout.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(value).font(.title3.weight(.semibold)); Text(title).font(.caption).foregroundStyle(.secondary) }
    }
}

struct ShortcutsView: View {
    @ObservedObject var model: Coordinator
    @ObservedObject var navigation: WorkspaceNavigation
    @State private var listening = false
    @State private var candidate: Shortcut?
    @State private var preview = "Press modifiers, then a key."
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WorkspaceCard("Recording shortcut", subtitle: "Both gestures work with the same shortcut. Escape cancels a recording.") {
                Text("Hold to talk · release to finish").font(.callout)
                Text("Double-tap to start · tap once to stop").font(.callout)
                Text(model.preferences.shortcut.displayLabel).font(.system(size: 32, weight: .medium, design: .rounded)).padding(.vertical, 6)
                if !model.recordingBinding {
                    HStack {
                        Button("Record a shortcut") { beginRecording() }.buttonStyle(.borderedProminent)
                        Button("Use default") { candidate = .standard; model.recordingBinding = true; model.bindingTest = false }.disabled(model.preferences.shortcut == .standard)
                    }.disabled(model.sessionBusy)
                } else {
                    if listening {
                        ShortcutRecorder(preview: { preview = $0 }, accept: { chord in
                            listening = false
                            if let chord { candidate = chord } else { cancelChange() }
                        }).frame(height: 44)
                        Text(preview).font(.callout).accessibilityLabel("Shortcut entered: \(preview)")
                    } else if let candidate {
                        Label("New shortcut: \(candidate.displayLabel)", systemImage: "keyboard").font(.title3)
                        Text("Your saved shortcut is still \(model.preferences.shortcut.displayLabel). Save to apply this change.").font(.callout).foregroundStyle(.secondary)
                        HStack {
                            Button("Save shortcut") { save(candidate) }.buttonStyle(.borderedProminent)
                            Button("Record another") { beginRecording() }
                        }.disabled(model.sessionBusy)
                    }
                    Button("Cancel change") { cancelChange() }
                }
                Text("Letters, numbers, punctuation, Space, one modifier alone, or Fn / Globe with a key can be saved. Bare keys take over normal typing while Aparté is ready. Modifier-only keys can conflict with other shortcuts. macOS may handle Globe before Aparté sees it. Test on your keyboard; key labels use US physical positions.").font(.caption).foregroundStyle(.secondary)
            }
            WorkspaceCard("Check detection", subtitle: "Tests the saved shortcut without opening the microphone.") {
                Toggle("Check shortcut detection", isOn: $model.bindingTest).disabled(model.sessionBusy || model.recordingBinding)
                Text(model.bindingTest ? "Hold \(model.preferences.shortcut.displayLabel) and release, or double-tap it and tap once to stop." : model.shortcutStatus).font(.callout)
                Text(model.testStatus).font(.caption).foregroundStyle(.secondary)
                Text("The result distinguishes the global listener from in-app delivery. In-app delivery alone does not establish system-wide access or conflict freedom.").font(.caption).foregroundStyle(.secondary)
            }
            Text("Aparté does not change macOS keyboard settings. Fn / Globe is available only when macOS delivers its modifier event to Aparté; Check detection confirms your saved key on this Mac.").font(.caption).foregroundStyle(.secondary)
            Button("Try dictation with this shortcut →") { navigation.section = .tryIt }.buttonStyle(.link)
        }.onDisappear { cancelChange(); model.bindingTest = false }
    }
    private func beginRecording() { model.bindingTest = false; candidate = nil; preview = "Press a key or modifier."; model.recordingBinding = true; listening = true }
    private func cancelChange() { listening = false; candidate = nil; model.recordingBinding = false }
    private func save(_ shortcut: Shortcut) {
        guard shortcut.isValid, !model.sessionBusy else { return }
        model.preferences.shortcut = shortcut; model.persist(); model.notice = "Shortcut saved: \(shortcut.displayLabel)."; cancelChange()
    }
}

struct PreferencesView: View {
    @ObservedObject var model: Coordinator
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WorkspaceCard("Access", subtitle: "Microphone for recording. Accessibility for the global shortcut and interaction with the original text field.") {
                accessRow("Microphone", microphoneDescription, granted: model.setupReadiness.microphone)
                HStack {
                    if model.microphonePermission == .notDetermined {
                        Button("Enable Microphone") { Task { _ = await PermissionStatus.requestMicrophone(); model.recheck() } }
                    }
                    Button("Microphone Settings") { PermissionStatus.open("Microphone") }
                }
                if model.microphonePermission == .denied { Text("Access was denied. Enable this copy in macOS Microphone Settings, then reopen Aparté and recheck.").font(.caption).foregroundStyle(.secondary) }
                if model.microphonePermission == .restricted { Text("Microphone access is restricted by macOS policy. Recording is unavailable until the restriction is removed.").font(.caption).foregroundStyle(.secondary) }
                Divider()
                accessRow("Accessibility", model.setupReadiness.accessibility ? "Granted" : "Required for system-wide dictation", granted: model.setupReadiness.accessibility)
                HStack {
                    Button("Accessibility Settings") { PermissionStatus.open("Accessibility") }
                    Button("Recheck access") { model.recheck() }
                }
                Text(model.shortcutStatus).font(.callout).foregroundStyle(.secondary)
                if model.tapFailed {
                    Text("The global listener could not start. Review Input Monitoring if macOS requires it, then quit/reopen Aparté and recheck.").font(.callout)
                    Button("Input Monitoring Settings") { PermissionStatus.open("ListenEvent") }
                }
                Text("If access already appears granted in macOS, quit and reopen this installed copy. A restart can be needed after changing grants or app identity.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Capability details") { Text(model.permissionSummary).font(.caption).textSelection(.enabled).padding(.top, 8) }
            }
            WorkspaceCard("Startup") {
                Toggle("Launch at login", isOn: Binding(get: { loginStatus == .enabled }, set: { enabled in
                    do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginError = "" }
                    catch { loginError = "Registration failed; install at ~/Applications/Aparte Dew.app and retry." }
                    loginStatus = SMAppService.mainApp.status
                }))
                Text("Login registration: \(loginDescription)").font(.callout).foregroundStyle(.secondary)
                if !loginError.isEmpty { Text(loginError).font(.caption).foregroundStyle(.red) }
                if loginStatus == .requiresApproval { Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() } }
            }
            WorkspaceCard("Privacy & insertion") {
                Label("Transcription happens on this Mac", systemImage: "lock.shield").font(.callout.weight(.medium))
                Text("No audio or transcript history is saved. Destination apps may process or sync inserted text. After failed insertion, Recovery places text on the system clipboard for manual paste; the clipboard may retain or sync it beyond Aparté’s five-minute expiry.").font(.callout).foregroundStyle(.secondary)
                DisclosureGroup("Insertion & Recovery limits") {
                    Text("Accessible editable fields across apps can receive guarded insertion. Secure, read-only and inaccessible controls use Recovery. An unconfirmed paste may already have inserted text: check the target before pasting again. Clipboard preservation may request data from its owning app. No Return is sent.").font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }
            }
            DisclosureGroup("Diagnostics") {
                Text("Aparté \(AppVersion.detailed) · WhisperKit 1.1.0 · macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · model \(model.preferences.model). Diagnostics contain no transcript or audio.").font(.caption).textSelection(.enabled).padding(.top, 8)
            }
        }.onAppear { loginStatus = SMAppService.mainApp.status; model.recheck() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in loginStatus = SMAppService.mainApp.status }
    }
    private func accessRow(_ name: String, _ state: String, granted: Bool) -> some View {
        HStack { Text(name).fontWeight(.medium); Spacer(); Label(state, systemImage: granted ? "checkmark.circle.fill" : "circle").foregroundStyle(granted ? Color.green : Color.secondary) }
    }
    private var loginDescription: String {
        switch loginStatus {
        case .notRegistered: return "Off"
        case .enabled: return "On"
        case .requiresApproval: return "Awaiting approval in Login Items"
        case .notFound: return "App not found; install at the stable path"
        @unknown default: return "Unknown; recheck Login Items"
        }
    }
    private var microphoneDescription: String {
        switch model.microphonePermission {
        case .authorized: return "Granted"
        case .denied: return "Denied in macOS"
        case .restricted: return "Restricted by macOS"
        default: return "Not requested"
        }
    }
}

struct MenuCompanionView: View {
    @ObservedObject var model: Coordinator
    var open: (WorkspaceSection?) -> Void
    var recovery: () -> Void
    var quit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { AparteLogo().foregroundStyle(.tint).frame(width: 30, height: 24); Text(AppVersion.displayName).font(.headline); Spacer(); StatusBadge(model: model) }
            Text(model.notice).font(.callout).fixedSize(horizontal: false, vertical: true).lineLimit(4)
            HStack { Text(model.preferences.shortcut.displayLabel).font(.title3.weight(.semibold)); Spacer(); Text("Hold or double-tap").font(.caption).foregroundStyle(.secondary) }
            Text("\(model.preferences.model.capitalized) · \(model.preferences.model.hasSuffix(".en") ? "English only" : languageLabel(model.preferences.language)) · On-device").font(.caption).foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                action("Try dictation…", icon: "mic") { open(.tryIt) }
                action("Open workspace…", icon: "slider.horizontal.3") { open(nil) }
                if !model.setupReadiness.canDictate { action("Review access…", icon: "lock.shield") { open(.settings) } }
                if model.recoveryText != nil {
                    action(model.recoveryUncertain ? "Recovery — check target first…" : "Open Recovery…", icon: "doc.text") { recovery() }
                }
                if model.sessionBusy { action("Cancel current dictation", icon: "xmark.circle") { model.cancel() } }
            }
            Divider()
            HStack { Text(AppVersion.detailed).font(.caption).foregroundStyle(.secondary); Spacer(); Button("Quit") { quit() }.buttonStyle(.link) }
        }.padding(20).frame(width: 320)
    }
    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 18)
                Text(title).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.bordered).controlSize(.large)
    }
}

func languageLabel(_ language: String) -> String {
    if language == "auto" { return "Auto" }
    return Locale.current.localizedString(forLanguageCode: language)?.capitalized ?? language.uppercased()
}
private func bytes(_ size: Int64) -> String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
private func openSoundInput() { if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension?input") { NSWorkspace.shared.open(url) } }
private struct ModelComparison {
    let prepare, warmP95, peakMemory, quality: String
    static func forModel(_ id: String) -> Self {
        switch id {
        case "base": return Self(prepare: "6.2 s", warmP95: "0.218 s", peakMemory: "318 MB", quality: "Fastest, but failed the fixed technical-term gate (50%; gate: 80%).")
        case "base.en": return Self(prepare: "5.9 s", warmP95: "0.356 s", peakMemory: "313 MB", quality: "English only. Synthetic English WER 2.13%, English technical terms 5/6; French recognition is unsupported. Compare your accent with Small before choosing.")
        case "small": return Self(prepare: "18.3 s", warmP95: "0.533 s", peakMemory: "842 MB", quality: "Recommended default. Passed every fixed synthetic quality gate.")
        case "medium": return Self(prepare: "10.3 s", warmP95: "1.137 s", peakMemory: "2.51 GB", quality: "Passed every fixed synthetic quality gate. English/French WER: 0.43% / 0.85%; technical terms: 91.7%.")
        case "turbo": return Self(prepare: "94 s", warmP95: "0.625 s", peakMemory: "3.24 GB", quality: "Passed every fixed synthetic quality gate. English/French WER: 0.43% / 1.91%.")
        default: return Self(prepare: "Unknown", warmP95: "Unknown", peakMemory: "Unknown", quality: "No measurements available.")
        }
    }
}
