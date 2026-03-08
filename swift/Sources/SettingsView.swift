import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("通用", systemImage: "slider.horizontal.3") }
            ReminderTab()
                .tabItem { Label("提醒", systemImage: "text.bubble") }
            AboutTab()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 440, height: 480)
    }
}

// MARK: - 通用

struct GeneralTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            // Timer sliders
            VStack(spacing: 16) {
                sliderRow(icon: "deskclock.fill", label: "工作时长", value: Binding(
                    get: { Double(state.config.workMinutes) },
                    set: { state.config.workMinutes = Int($0) }
                ), range: 1...120, unit: "分钟", color: .green)

                sliderRow(icon: "cup.and.saucer.fill", label: "休息时长", value: Binding(
                    get: { Double(state.config.breakMinutes) },
                    set: { state.config.breakMinutes = Int($0) }
                ), range: 1...15, unit: "分钟", color: .orange)

                sliderRow(icon: "target", label: "每日目标", value: Binding(
                    get: { Double(state.config.dailyGoal) },
                    set: { state.config.dailyGoal = Int($0) }
                ), range: 1...20, unit: "次", color: .blue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

            // Break position + sound toggles
            VStack(spacing: 0) {
                // Break position
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.inset.filled")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("休息窗口")
                        .font(.callout)
                    Spacer()
                    Picker("", selection: $state.config.breakPosition) {
                        ForEach(BreakPosition.allCases, id: \.self) { pos in
                            Text(pos.label).tag(pos)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

                Divider().padding(.leading, 44)

                toggleRow(icon: "hand.raised.fill", label: "休息前确认", isOn: $state.config.breakConfirm)
                Divider().padding(.leading, 44)
                toggleRow(icon: "speaker.wave.2.fill", label: "提醒声音", isOn: $state.config.soundEnabled)
                Divider().padding(.leading, 44)
                toggleRow(icon: "ear.fill", label: "操作检测提示音", isOn: $state.config.breakDetectSound)
            }
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

            // Launch at login
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "power")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("开机自启动")
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

            Spacer()
        }
        .padding(20)
        .alert("时长已变更", isPresented: $state.showRestartPrompt) {
            Button("重新计时") { state.restartCurrentPhase() }
            Button("稍后再说", role: .cancel) {}
        } message: {
            Text("工作或休息时长已修改，是否按新设置重新开始计时？")
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
                    .frame(width: 60, alignment: .trailing)
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

// MARK: - 提醒内容

struct ReminderTab: View {
    @EnvironmentObject var state: AppState
    @State private var newReminder = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("休息时随机展示一条提醒")
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
                        Text(reminder)
                            .font(.callout)
                        Spacer()
                        if state.config.reminders.count > 1 {
                            Button {
                                _ = state.config.reminders.remove(at: i)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 18, height: 18)
                                    .background(.quaternary, in: Circle())
                            }
                            .buttonStyle(.borderless)
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
                TextField("添加新的提醒内容...", text: $newReminder)
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
}

// MARK: - 关于

struct AboutTab: View {
    @EnvironmentObject var state: AppState
    @StateObject private var updater = UpdateChecker.shared
    @State private var resetStep = 0 // 0=idle, 1=first confirm, 2=second confirm
    @State private var resetDone = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text("HealthTick")
                .font(.title2.bold())

            Text("健康打卡")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("v\(appVersion)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())

            Text("久坐提醒 · 强制休息 · 习惯养成")
                .font(.callout)
                .foregroundStyle(.tertiary)

            // Update check
            Button {
                updater.check(silent: false)
            } label: {
                HStack(spacing: 6) {
                    if updater.isChecking {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(updater.isChecking ? "检查中..." : "检查更新")
                }
            }
            .controlSize(.regular)
            .disabled(updater.isChecking)

            if let err = updater.checkError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                if let url = URL(string: "https://github.com/lifedever/health-tick-release#-赞助支持") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("赞助支持")
                }
            }
            .buttonStyle(.borderless)

            Spacer()

            // Danger zone
            VStack(spacing: 8) {
                if resetDone {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("数据已清除")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity)
                } else if resetStep == 0 {
                    Button {
                        withAnimation { resetStep = 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption2)
                            Text("重置所有打卡数据")
                                .font(.caption)
                        }
                        .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.borderless)
                } else if resetStep == 1 {
                    VStack(spacing: 6) {
                        Text("此操作将删除所有打卡记录，不可恢复！")
                            .font(.caption)
                            .foregroundStyle(.red)
                        HStack(spacing: 12) {
                            Button("取消") {
                                withAnimation { resetStep = 0 }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)

                            Button("确认删除") {
                                withAnimation { resetStep = 2 }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                        }
                    }
                    .transition(.opacity)
                } else if resetStep == 2 {
                    VStack(spacing: 6) {
                        Text("最后确认：真的要清除全部数据吗？")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                        HStack(spacing: 12) {
                            Button("我再想想") {
                                withAnimation { resetStep = 0 }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)

                            Button("彻底删除") {
                                Database.shared.resetAllData()
                                state.refreshStats()
                                withAnimation {
                                    resetStep = 0
                                    resetDone = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { resetDone = false }
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
            .animation(.easeInOut(duration: 0.2), value: resetStep)
            .animation(.easeInOut(duration: 0.2), value: resetDone)
            .padding(.bottom, 4)

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
