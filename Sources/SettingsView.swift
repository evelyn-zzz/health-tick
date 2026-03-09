import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label(L.tabGeneral, systemImage: "slider.horizontal.3") }
            ReminderTab()
                .tabItem { Label(L.tabReminders, systemImage: "text.bubble") }
            AboutTab()
                .tabItem { Label(L.tabAbout, systemImage: "info.circle") }
        }
        .frame(width: 440, height: 520)
    }
}

// MARK: - General

struct GeneralTab: View {
    @EnvironmentObject var state: AppState
    @State private var resetSettingsStep = 0
    @State private var resetSettingsDone = false
    @State private var resetDataStep = 0
    @State private var resetDataDone = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Timer sliders
                VStack(spacing: 16) {
                    sliderRow(icon: "deskclock.fill", label: L.workDuration, value: Binding(
                        get: { Double(state.config.workMinutes) },
                        set: { state.config.workMinutes = Int($0) }
                    ), range: 1...120, unit: L.unitMinutes, color: .green)

                    sliderRow(icon: "cup.and.saucer.fill", label: L.breakDuration, value: Binding(
                        get: { Double(state.config.breakMinutes) },
                        set: { state.config.breakMinutes = Int($0) }
                    ), range: 1...15, unit: L.unitMinutes, color: .orange)

                    sliderRow(icon: "target", label: L.dailyGoal, value: Binding(
                        get: { Double(state.config.dailyGoal) },
                        set: { state.config.dailyGoal = Int($0) }
                    ), range: 1...20, unit: L.unitTimes, color: .blue)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                // Break position + toggles
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.inset.filled")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(L.breakWindow)
                            .font(.callout)
                        Spacer()
                        Picker("", selection: $state.config.breakPosition) {
                            ForEach(BreakPosition.allCases, id: \.self) { pos in
                                Text(pos.label).tag(pos)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)

                    Divider().padding(.leading, 44)

                    toggleRow(icon: "hand.raised.fill", label: L.breakConfirm, isOn: $state.config.breakConfirm)
                    Divider().padding(.leading, 44)
                    toggleRow(icon: "speaker.wave.2.fill", label: L.reminderSound, isOn: $state.config.soundEnabled)
                    Divider().padding(.leading, 44)
                    toggleRow(icon: "ear.fill", label: L.activityDetectSound, isOn: $state.config.breakDetectSound)
                }
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                // Language + Launch at login
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(L.language)
                            .font(.callout)
                        Spacer()
                        Picker("", selection: $state.config.language) {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)

                    Divider().padding(.leading, 44)

                    HStack(spacing: 10) {
                        Image(systemName: "power")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(L.launchAtLogin)
                            .font(.callout)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { SMAppService.mainApp.status == .enabled },
                            set: { enable in
                                try? enable ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                // Reset section
                HStack(spacing: 20) {
                    Spacer()
                    resetButton(
                        step: $resetSettingsStep,
                        done: $resetSettingsDone,
                        label: L.resetSettings,
                        warning: L.resetSettingsWarning,
                        confirmLabel: L.resetSettingsConfirm,
                        doneLabel: L.settingsReset
                    ) {
                        state.resetToDefaults()
                    }

                    resetButton(
                        step: $resetDataStep,
                        done: $resetDataDone,
                        label: L.resetAllData,
                        warning: L.resetDataWarning,
                        confirmLabel: L.confirmDelete,
                        doneLabel: L.dataCleared
                    ) {
                        Database.shared.resetAllData()
                        state.refreshStats()
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .alert(L.durationChanged, isPresented: $state.showRestartPrompt) {
            Button(L.restartTimer) { state.restartCurrentPhase() }
            Button(L.laterAction, role: .cancel) {}
        } message: {
            Text(L.durationChangedMsg)
        }
    }

    @ViewBuilder
    private func resetButton(step: Binding<Int>, done: Binding<Bool>, label: String, warning: String, confirmLabel: String, doneLabel: String, action: @escaping () -> Void) -> some View {
        if done.wrappedValue {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(doneLabel)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .transition(.opacity)
        } else if step.wrappedValue == 0 {
            Button {
                withAnimation { step.wrappedValue = 1 }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption2)
                    Text(label)
                        .font(.caption)
                }
                .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.borderless)
            .handCursor()
        } else if step.wrappedValue == 1 {
            VStack(spacing: 6) {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button(L.cancel) {
                        withAnimation { step.wrappedValue = 0 }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)

                    Button(confirmLabel) {
                        withAnimation { step.wrappedValue = 2 }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
            .transition(.opacity)
        } else if step.wrappedValue == 2 {
            VStack(spacing: 6) {
                Text(L.finalConfirm)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                HStack(spacing: 12) {
                    Button(L.thinkAgain) {
                        withAnimation { step.wrappedValue = 0 }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)

                    Button(L.deleteForever) {
                        action()
                        withAnimation {
                            step.wrappedValue = 0
                            done.wrappedValue = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { done.wrappedValue = false }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
            .transition(.opacity)
        }
    }

    private func sliderRow(icon: String, label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon).font(.callout).foregroundStyle(color).frame(width: 20)
                Text(label).font(.callout)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .font(.callout.monospacedDigit().bold())
                    .foregroundStyle(color)
                    .frame(width: 70, alignment: .trailing)
            }
            Slider(value: value, in: range, step: 1).tint(color)
        }
    }

    private func toggleRow(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.callout)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

// MARK: - Reminders

struct ReminderTab: View {
    @EnvironmentObject var state: AppState
    @State private var newReminder = ""
    @State private var editingIndex: Int? = nil
    @State private var editingText = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L.reminderHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(state.config.reminders.enumerated()), id: \.offset) { i, reminder in
                    if i > 0 { Divider().padding(.leading, 14) }
                    HStack(spacing: 10) {
                        Circle()
                            .fill(.green.opacity(0.7))
                            .frame(width: 6, height: 6)

                        if editingIndex == i {
                            TextField("", text: $editingText)
                                .textFieldStyle(.plain)
                                .font(.callout)
                                .onSubmit { saveEdit(at: i) }
                                .onExitCommand { editingIndex = nil }
                        } else {
                            Text(reminder)
                                .font(.callout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingIndex = i
                                    editingText = reminder
                                }
                                .handCursor()
                        }

                        Spacer()
                        if state.config.reminders.count > 1 {
                            Button {
                                if editingIndex == i { editingIndex = nil }
                                _ = state.config.reminders.remove(at: i)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 18, height: 18)
                                    .background(.quaternary, in: Circle())
                            }
                            .buttonStyle(.borderless)
                            .handCursor()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField(L.addReminderPlaceholder, text: $newReminder)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit { addReminder() }

                if !newReminder.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        addReminder()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.borderless)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

            Spacer()
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.15), value: newReminder)
    }

    private func addReminder() {
        let text = newReminder.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        withAnimation { state.config.reminders.append(text) }
        newReminder = ""
    }

    private func saveEdit(at index: Int) {
        let text = editingText.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty && index < state.config.reminders.count {
            state.config.reminders[index] = text
        }
        editingIndex = nil
    }
}

// MARK: - About

struct AboutTab: View {
    @EnvironmentObject var state: AppState
    @StateObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text("HealthTick")
                .font(.title2.bold())

            Text(L.appSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("v\(appVersion)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())

            Text(L.appSlogan)
                .font(.callout)
                .foregroundStyle(.tertiary)

            Button {
                updater.check(silent: false)
            } label: {
                HStack(spacing: 6) {
                    if updater.isChecking {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(updater.isChecking ? L.checking : L.checkUpdate)
                }
            }
            .controlSize(.regular)
            .disabled(updater.isChecking)
            .handCursor()

            if let err = updater.checkError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                Button {
                    if let url = URL(string: "https://github.com/lifedever/health-tick-release#-赞助支持") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text(L.sponsorSupport)
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .handCursor()

                Text("·")
                    .font(.callout)
                    .foregroundStyle(.quaternary)

                Button {
                    if let url = URL(string: "https://github.com/lifedever/health-tick-release") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text(L.githubPage)
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .handCursor()
            }

            Spacer()

            HStack(spacing: 4) {
                Text("Made with")
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red.opacity(0.5))
                Text("for your health")
            }
            .font(.caption2)
            .foregroundStyle(.quaternary)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hand Cursor

extension View {
    func handCursor() -> some View {
        self.onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
