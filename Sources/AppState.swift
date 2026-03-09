import Foundation
import Combine
import AppKit

enum BreakPosition: String, CaseIterable, Equatable {
    case topRight = "top_right"
    case topLeft = "top_left"
    case center = "center"
    case fullscreen = "fullscreen"
    case menuWindow = "menu_window"

    var label: String {
        switch self {
        case .topRight: return L.posTopRight
        case .topLeft: return L.posTopLeft
        case .center: return L.posCenter
        case .fullscreen: return L.posFullscreen
        case .menuWindow: return L.posMenuWindow
        }
    }
}

struct AppConfig: Equatable {
    var workMinutes: Int = 60
    var breakMinutes: Int = 2
    var dailyGoal: Int = 8
    var reminders: [String] = [L.defaultReminder1, L.defaultReminder2]
    var soundEnabled: Bool = true
    var breakDetectSound: Bool = false
    var breakPosition: BreakPosition = .menuWindow
    var breakConfirm: Bool = true
    var language: AppLanguage = .system
}

struct Badge {
    let days: Int
    let icon: String

    var name: String { L.badgeName(days) }
    var desc: String { L.badgeDesc(days) }
}

let allBadges: [Badge] = [
    Badge(days: 3, icon: "👣"),
    Badge(days: 7, icon: "🌱"),
    Badge(days: 14, icon: "🌿"),
    Badge(days: 21, icon: "🌳"),
    Badge(days: 30, icon: "🛡️"),
    Badge(days: 50, icon: "⭐"),
    Badge(days: 60, icon: "💪"),
    Badge(days: 90, icon: "👑"),
    Badge(days: 100, icon: "🏆"),
    Badge(days: 180, icon: "💎"),
    Badge(days: 365, icon: "🐉"),
]

enum AppPhase: String {
    case working
    case alerting
    case breaking
    case waiting
    case paused
}

@MainActor
final class AppState: ObservableObject {
    @Published var config: AppConfig
    @Published var phase: AppPhase = .working
    @Published var remainingSeconds: Int = 0
    @Published var todayDone: Int = 0
    @Published var currentStreak: Int = 0
    @Published var maxStreak: Int = 0
    @Published var breakWarning: String = ""
    @Published var breakSkipCount: Int = 0
    let breakSkipNeeded = 3
    @Published var weekData: [(String, Int)] = []

    private var targetTime: Date = Date()
    private var pausedRemaining: Int = 0
    private var pausedPhase: AppPhase?
    private var timer: Timer?
    private var alertRepeatTimer: Timer?
    private let db = Database.shared
    var overlayManager = BreakOverlayManager()

    private var configWatcher: AnyCancellable?
    private var lastSavedConfig: AppConfig?

    init() {
        config = db.loadConfig()
        L.lang = config.language
        lastSavedConfig = config
        overlayManager.appState = self
        overlayManager.onForceEnd = { [weak self] in
            self?.forceEndBreak()
        }
        overlayManager.onBreakDone = { [weak self] in
            self?.onBreakDone()
        }
        startWork()
        refreshStats()

        // Auto-save when config changes
        configWatcher = $config
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newConfig in
                self?.autoSave(newConfig)
            }
    }

    // MARK: - Timer

    func startWork() {
        phase = .working
        targetTime = Date().addingTimeInterval(Double(config.workMinutes * 60))
        remainingSeconds = config.workMinutes * 60
        startTicking()
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard phase == .working || phase == .breaking else { return }
        // Menu window break: overlay manages countdown with idle detection
        if phase == .breaking && config.breakPosition == .menuWindow { return }
        let newVal = max(0, Int(targetTime.timeIntervalSinceNow))
        if newVal != remainingSeconds {
            remainingSeconds = newVal
        }
        if remainingSeconds <= 0 {
            if phase == .working { onWorkDone() }
            else if phase == .breaking { onBreakDone() }
        }
    }

    // MARK: - Work Done -> Alert

    private func onWorkDone() {
        let reminder = config.reminders.randomElement() ?? L.defaultBreakReminder
        playSound("Glass")

        if config.breakConfirm {
            phase = .alerting
            remainingSeconds = 0
            alertRepeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in self?.playSound("Ping") }
            }
            showBreakAlert(reminder)
        } else {
            startBreak()
        }
    }

    private func showBreakAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L.healthCheckIn
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.alertConfirmBreak)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.setActivationPolicy(.accessory)
        alertRepeatTimer?.invalidate()
        alertRepeatTimer = nil
        startBreak()
    }

    // MARK: - Break

    private func startBreak() {
        phase = .breaking
        breakWarning = ""
        breakSkipCount = 0
        let secs = config.breakMinutes * 60
        remainingSeconds = secs

        if config.breakPosition == .menuWindow {
            // Menu window mode: overlay manages idle-aware countdown
            overlayManager.showMenuWindow(seconds: secs)
        } else {
            targetTime = Date().addingTimeInterval(Double(secs))
            overlayManager.show(seconds: secs)
            startTicking()
        }
    }

    private func onBreakDone() {
        phase = .waiting
        remainingSeconds = 0
        breakWarning = ""
        overlayManager.hide()

        db.addRecord()
        refreshStats()

        showReturnDialog()
    }

    private func showReturnDialog() {
        let alert = NSAlert()
        alert.messageText = L.healthCheckIn
        alert.informativeText = L.breakOverReturnPrompt
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.alertImBack)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.setActivationPolicy(.accessory)
        startWork()
    }

    // MARK: - Pause / Reset

    func togglePause() {
        if phase == .paused, let prev = pausedPhase {
            phase = prev
            pausedPhase = nil
            targetTime = Date().addingTimeInterval(Double(pausedRemaining))
            remainingSeconds = pausedRemaining
            startTicking()
        } else if phase == .working || phase == .breaking {
            pausedRemaining = remainingSeconds
            pausedPhase = phase
            phase = .paused
            timer?.invalidate()
        }
    }

    func reset() {
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        overlayManager.hide()
        pausedPhase = nil
        startWork()
    }

    // MARK: - Stats

    func refreshStats() {
        todayDone = db.todayCount()
        currentStreak = db.streakDays(goal: config.dailyGoal)
        maxStreak = db.maxStreakDays(goal: config.dailyGoal)
        weekData = db.recent7DaysCounts()
    }

    @Published var showRestartPrompt = false

    private func autoSave(_ newConfig: AppConfig) {
        guard let old = lastSavedConfig, newConfig != old else { return }
        db.saveConfig(newConfig)
        refreshStats()
        lastSavedConfig = newConfig

        // Update global language
        if newConfig.language != old.language {
            L.lang = newConfig.language
        }

        if (newConfig.workMinutes != old.workMinutes && (phase == .working || phase == .paused)) ||
           (newConfig.breakMinutes != old.breakMinutes && phase == .breaking) {
            showRestartPrompt = true
        }
    }

    func resetToDefaults() {
        db.resetConfig()
        config = db.loadConfig()
        lastSavedConfig = config
        L.lang = config.language
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        overlayManager.hide()
        pausedPhase = nil
        startWork()
        refreshStats()
    }

    func restartCurrentPhase() {
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        overlayManager.hide()
        pausedPhase = nil
        startWork()
    }

    // MARK: - Helpers

    var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var phaseIcon: String {
        switch phase {
        case .working: return "🟢"
        case .alerting, .breaking: return "🟡"
        case .waiting: return "🔴"
        case .paused: return "⏸"
        }
    }

    var phaseLabel: String {
        switch phase {
        case .working: return L.phaseWorking
        case .alerting: return L.phaseAlerting
        case .breaking: return L.phaseBreaking
        case .waiting: return L.phaseWaiting
        case .paused: return L.phasePaused
        }
    }

    var goalProgress: Double {
        Double(min(todayDone, config.dailyGoal)) / Double(config.dailyGoal)
    }

    var encourageText: String {
        let gap = db.daysSinceLastGoal(goal: config.dailyGoal)
        if gap == 0 { return L.encourageGoalMet }
        if gap == -1 { return L.encourageNoRecord }
        if gap == 1 { return L.encourageYesterday }
        if gap <= 3 { return L.encourageGapShort(gap) }
        return L.encourageGapLong(gap)
    }

    var earnedBadge: Badge? {
        allBadges.last(where: { maxStreak >= $0.days })
    }

    var nextBadge: Badge? {
        allBadges.first(where: { maxStreak < $0.days })
    }

    func playSound(_ name: String) {
        guard config.soundEnabled else { return }
        NSSound(named: name)?.play()
    }

    func playBreakDetectSound() {
        guard config.breakDetectSound else { return }
        NSSound(named: "Tink")?.play()
    }

    func skipBreakClicked() {
        breakSkipCount += 1
        if breakSkipCount >= breakSkipNeeded {
            forceEndBreak()
        }
    }

    func forceEndBreak() {
        guard phase == .breaking else { return }
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        alertRepeatTimer = nil
        breakWarning = ""
        overlayManager.hide()
        startWork()
    }
}
