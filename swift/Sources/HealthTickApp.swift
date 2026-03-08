import SwiftUI

@main
struct HealthTickApp: App {
    @StateObject private var state = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(state)
        } label: {
            Image(systemName: phaseSystemImage)
        }
        .menuBarExtraStyle(.window)

        Window("设置", id: "settings") {
            SettingsView()
                .environmentObject(state)
        }
        .defaultSize(width: 400, height: 320)

        Window("帮助", id: "help") {
            HelpView()
        }
        .defaultSize(width: 600, height: 650)

        Window("成就", id: "stats") {
            StatsWindowView()
                .environmentObject(state)
        }
        .defaultSize(width: 780, height: 620)
    }

    private var phaseSystemImage: String {
        switch state.phase {
        case .working: return "figure.walk"
        case .alerting, .breaking: return "cup.and.saucer.fill"
        case .waiting: return "hand.raised.fill"
        case .paused: return "pause.circle"
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var observer: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app icon from bundle resources
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns", subdirectory: "Resources"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        // Check for updates silently on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UpdateChecker.shared.check(silent: true)
        }

        // Monitor window close to hide Dock icon when no windows are open
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let hasVisibleWindow = NSApp.windows.contains { w in
                    w.isVisible && !(w is NSPanel) && !w.title.isEmpty
                        && w.styleMask.contains(.titled)
                }
                if !hasVisibleWindow {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
