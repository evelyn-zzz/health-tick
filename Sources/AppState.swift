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

enum AppAppearance: String, CaseIterable, Equatable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var label: String {
        switch self {
        case .system: return L.appearanceSystem
        case .light: return L.appearanceLight
        case .dark: return L.appearanceDark
        }
    }
}

struct QuietHourPeriod: Codable, Equatable {
    var start: String  // "HH:mm"
    var end: String    // "HH:mm"

    func isActive(at date: Date) -> Bool {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let now = h * 60 + m

        let startParts = start.split(separator: ":").compactMap { Int($0) }
        let endParts = end.split(separator: ":").compactMap { Int($0) }
        guard startParts.count == 2, endParts.count == 2 else { return false }

        let s = startParts[0] * 60 + startParts[1]
        let e = endParts[0] * 60 + endParts[1]

        if s <= e {
            return now >= s && now < e
        } else {
            // Crosses midnight
            return now >= s || now < e
        }
    }
}

struct BreakActivity {
    let icon: String
    let textZh: String
    let textEn: String

    var text: String { L.isZhAccess ? textZh : textEn }
}

let breakActivities: [BreakActivity] = [
    BreakActivity(icon: "figure.walk", textZh: "起来走走，活动一下身体", textEn: "Take a walk and stretch your body"),
    BreakActivity(icon: "eye", textZh: "远眺窗外，放松眼睛", textEn: "Look out the window, relax your eyes"),
    BreakActivity(icon: "drop.fill", textZh: "喝杯水，补充水分", textEn: "Drink some water, stay hydrated"),
    BreakActivity(icon: "figure.flexibility", textZh: "做几个简单的拉伸动作", textEn: "Do some simple stretches"),
    BreakActivity(icon: "wind", textZh: "深呼吸，放松身心", textEn: "Take deep breaths, relax your mind"),
    BreakActivity(icon: "hand.raised.fingers.spread", textZh: "活动手腕，预防鼠标手", textEn: "Flex your wrists to prevent strain"),
    BreakActivity(icon: "moon.fill", textZh: "闭眼休息，让大脑放松", textEn: "Close your eyes and rest your mind"),
    BreakActivity(icon: "arrow.up.and.down", textZh: "伸展脊柱，改善坐姿", textEn: "Stretch your spine, improve posture"),
]

struct AppConfig: Equatable {
    var workMinutes: Int = 60
    var breakMinutes: Int = 2
    var dailyGoal: Int = 8
    var reminders: [String] = [L.defaultReminder1, L.defaultReminder2]
    var soundEnabled: Bool = true
    var breakDetectSound: Bool = false
    var breakPosition: BreakPosition = .menuWindow
    var breakConfirm: Bool = true
    var alertSound: String = "Glass"
    var breakDetectSoundName: String = "Tink"
    var language: AppLanguage = .system
    var appearance: AppAppearance = .system
    var quietHours: [QuietHourPeriod] = []
    var workDays: Set<Int> = [2, 3, 4, 5, 6]  // Calendar weekday: 2=Mon...6=Fri
}

struct Badge {
    let days: Int
    let icon: String
    let isTotal: Bool

    init(days: Int, icon: String, isTotal: Bool = false) {
        self.days = days
        self.icon = icon
        self.isTotal = isTotal
    }

    var name: String { isTotal ? L.totalBadgeName(days) : L.badgeName(days) }
    var desc: String { isTotal ? L.totalBadgeDesc(days) : L.badgeDesc(days) }
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

let allTotalBadges: [Badge] = [
    Badge(days: 50, icon: "🔢", isTotal: true),
    Badge(days: 100, icon: "💯", isTotal: true),
    Badge(days: 200, icon: "🎯", isTotal: true),
    Badge(days: 500, icon: "🚀", isTotal: true),
    Badge(days: 1000, icon: "🌟", isTotal: true),
    Badge(days: 2000, icon: "🔥", isTotal: true),
    Badge(days: 5000, icon: "🏅", isTotal: true),
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
    @Published var totalCount: Int = 0
    @Published var isInQuietHours: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var currentBreakActivity: BreakActivity?

    private var currentSessionId: Int64?
    private var breakStartDate: Date?
    private var targetTime: Date = Date()
    private var pausedRemaining: Int = 0
    private var pausedPhase: AppPhase?
    private var timer: Timer?
    private var alertRepeatTimer: Timer?
    private var quietCheckTimer: Timer?
    private var autoQuietPaused: Bool = false
    private let db = Database.shared
    var overlayManager = BreakOverlayManager()

    private var configWatcher: AnyCancellable?
    private var lastSavedConfig: AppConfig?

    var earnedTotalBadges: [Badge] {
        allTotalBadges.filter { totalCount >= $0.days }
    }

    var nextTotalBadge: Badge? {
        allTotalBadges.first(where: { totalCount < $0.days })
    }

    init() {
        config = db.loadConfig()
        L.lang = config.language
        Self.applyAppearance(config.appearance)
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

        startQuietCheckTimer()

        // Delay so onChange in HealthTickApp can catch the transition
        if !db.isOnboardingCompleted() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showOnboarding = true
            }
        }

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
        currentSessionId = db.startSession(workMinutes: config.workMinutes, breakMinutes: config.breakMinutes, dailyGoal: config.dailyGoal)
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
        playSound()

        if config.breakConfirm {
            phase = .alerting
            remainingSeconds = 0
            alertRepeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in self?.playSound() }
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
        breakStartDate = Date()
        currentBreakActivity = breakActivities.randomElement()
        let secs = config.breakMinutes * 60
        remainingSeconds = secs

        if let sid = currentSessionId {
            db.endWork(sessionId: sid)
            db.startSessionBreak(sessionId: sid)
        }

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

        let actualSeconds: Int?
        if let start = breakStartDate {
            actualSeconds = Int(Date().timeIntervalSince(start))
        } else {
            actualSeconds = nil
        }
        if let sid = currentSessionId {
            db.endSessionBreak(sessionId: sid, actualSeconds: actualSeconds, skipped: false)
        }

        db.addRecord()
        refreshStats()
    }

    func confirmReturn() {
        startWork()
    }

    // MARK: - Pause / Reset

    func togglePause() {
        if phase == .paused, let prev = pausedPhase {
            // Don't allow manual resume during quiet hours
            if isInQuietHours { return }
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
        autoQuietPaused = false
        isInQuietHours = false
        startWork()
        checkQuietHours()
    }

    // MARK: - Stats

    func refreshStats() {
        todayDone = db.todayCount()
        currentStreak = db.streakDays(goal: config.dailyGoal)
        maxStreak = db.maxStreakDays(goal: config.dailyGoal)
        weekData = db.recent7DaysCounts()
        totalCount = db.totalCount()
    }

    @Published var showRestartPrompt = false
    var suppressNextRestartPrompt = false

    private func autoSave(_ newConfig: AppConfig) {
        guard let old = lastSavedConfig, newConfig != old else { return }
        db.saveConfig(newConfig)
        refreshStats()
        lastSavedConfig = newConfig

        if newConfig.language != old.language {
            L.lang = newConfig.language
        }
        if newConfig.appearance != old.appearance {
            Self.applyAppearance(newConfig.appearance)
        }

        if suppressNextRestartPrompt {
            suppressNextRestartPrompt = false
        } else if (newConfig.workMinutes != old.workMinutes && (phase == .working || phase == .paused)) ||
           (newConfig.breakMinutes != old.breakMinutes && phase == .breaking) {
            showRestartPrompt = true
        }

        if newConfig.quietHours != old.quietHours || newConfig.workDays != old.workDays {
            checkQuietHours()
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

    func playSound(_ name: String? = nil) {
        guard config.soundEnabled else { return }
        NSSound(named: name ?? config.alertSound)?.play()
    }

    func playBreakDetectSound() {
        guard config.breakDetectSound else { return }
        NSSound(named: config.breakDetectSoundName)?.play()
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

        let actualSeconds: Int?
        if let start = breakStartDate {
            actualSeconds = Int(Date().timeIntervalSince(start))
        } else {
            actualSeconds = nil
        }
        if let sid = currentSessionId {
            db.endSessionBreak(sessionId: sid, actualSeconds: actualSeconds, skipped: true)
        }

        startWork()
    }

    // MARK: - Quiet Hours

    private func startQuietCheckTimer() {
        quietCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.checkQuietHours() }
        }
        checkQuietHours()
    }

    private func checkQuietHours() {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let isWorkDay = config.workDays.contains(weekday)
        let inQuietPeriod = config.quietHours.contains { $0.isActive(at: now) }
        let shouldPause = !isWorkDay || inQuietPeriod

        if shouldPause && !isInQuietHours {
            isInQuietHours = true
            if phase == .breaking { forceEndBreak() }
            if phase == .working { togglePause(); autoQuietPaused = true }
        } else if !shouldPause && isInQuietHours {
            isInQuietHours = false
            if phase == .paused && autoQuietPaused { togglePause(); autoQuietPaused = false }
        }
    }

    static func applyAppearance(_ appearance: AppAppearance) {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
