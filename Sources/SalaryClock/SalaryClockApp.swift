import SwiftUI
import AppKit
import UserNotifications

@main
struct SalaryClockApp: App {
    @NSApplicationDelegateAdaptor(SalaryClockAppDelegate.self) private var appDelegate

    var body: some Scene {
        // The floating widget is managed as a dedicated AppKit window by the
        // application delegate. A Settings scene keeps the app lifecycle native
        // without SwiftUI WindowGroup restoring duplicate/hidden widget windows.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button(LocalizedStringKey("设置…")) {
                        SettingsWindowController.shared.toggle(model: SalaryClockModel.shared)
                    }
                    .keyboardShortcut(",", modifiers: [.command])
                }
                CommandMenu(LocalizedStringKey("薪资时钟")) {
                    Button(LocalizedStringKey("隐藏 / 显示悬浮挂件")) {
                        WidgetWindowActions.toggle()
                    }
                    .keyboardShortcut("h", modifiers: [.command, .option])
                }
            }
    }
}

@MainActor
enum WidgetWindowActions {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("salary-clock.floating-widget")
    private static let positionKey = "salary-clock.floating-widget.position"
    private static let appGroupID = "WXFKXAFBJ8.salaryclock"
    private static let legacyBundleID = "com.jyd.salaryclock"
    private static var positionObserver: NSObjectProtocol?

    static var widgetWindow: NSWindow? {
        NSApp.windows.first { $0.identifier == windowIdentifier }
    }

    static func applyWindowLevel(to window: NSWindow) {
        let shouldFloat = SalaryClockModel.shared.settings.alwaysOnTop
        // Desktop level keeps the widget on the desktop layer, behind normal
        // application windows. Floating is an explicit opt-in overlay.
        // NSPanel.isFloatingPanel can implicitly rewrite the window level.
        // Use the explicit level as the single source of truth instead.
        window.level = shouldFloat ? .floating : .normal
        if window.isVisible { window.orderFront(nil) }
    }

    static func toggle() {
        guard let window = widgetWindow ?? NSApp.windows.first(where: { !($0 is NSPanel) }) ?? NSApp.windows.first else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
        }
    }

    static func restorePosition(for window: NSWindow) {
        let stored = UserDefaults(suiteName: appGroupID)?.array(forKey: positionKey) as? [Double]
            ?? UserDefaults(suiteName: legacyBundleID)?.array(forKey: positionKey) as? [Double]
            ?? UserDefaults.standard.array(forKey: positionKey) as? [Double]
        guard let stored, stored.count == 2 else { return }
        applyPosition(x: stored[0], y: stored[1], to: window)
    }

    static func observePosition(of window: NSWindow) {
        guard positionObserver == nil else { return }
        positionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { notification in
            guard let movedWindow = notification.object as? NSWindow else { return }
            Task { @MainActor in savePosition(of: movedWindow) }
        }
    }

    static func savePosition(of window: NSWindow) {
        let origin = window.frame.origin
        let position = [Double(origin.x), Double(origin.y)]
        UserDefaults(suiteName: appGroupID)?.set(position, forKey: positionKey)
        UserDefaults.standard.set(position, forKey: positionKey)
    }

    private static func applyPosition(x: Double, y: Double, to window: NSWindow) {
        let frame = window.frame
        let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        guard visibleFrame != .zero else {
            window.setFrameOrigin(NSPoint(x: x, y: y))
            return
        }
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - frame.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - frame.height)
        let safeX = min(max(CGFloat(x), visibleFrame.minX), maxX)
        let safeY = min(max(CGFloat(y), visibleFrame.minY), maxY)
        window.setFrameOrigin(NSPoint(x: safeX, y: safeY))
    }
}

extension Notification.Name {
    static let salaryClockWindowLockChanged = Notification.Name("salary-clock.window-lock-changed")
    static let salaryClockWindowLevelChanged = Notification.Name("salary-clock.window-level-changed")
    static let salaryClockPointerAfterDrag = Notification.Name("salary-clock.pointer-after-drag")
}

/// NSHostingView normally consumes mouse-down events for SwiftUI hit testing.
/// Explicitly advertise the hosting surface as a movable window background;
/// SwiftUI controls still receive events in their own hit-tested regions.
@MainActor
final class MovableWidgetHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool {
        !SalaryClockModel.shared.settings.windowLocked
    }
}

@MainActor
final class SalaryClockPanel: NSPanel {
    private(set) var isPointerInteractionActive = false

    convenience init(contentViewController: NSViewController) {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 310),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.contentViewController = contentViewController
        NotificationCenter.default.addObserver(self, selector: #selector(syncDragLock), name: .salaryClockWindowLockChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(syncWindowLevel), name: .salaryClockWindowLevelChanged, object: nil)
    }

    @objc private func syncDragLock() {
        isMovableByWindowBackground = !SalaryClockModel.shared.settings.windowLocked
    }

    @objc private func syncWindowLevel() {
        WidgetWindowActions.applyWindowLevel(to: self)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            isPointerInteractionActive = true
        }
        super.sendEvent(event)
        if event.type == .leftMouseUp {
            isPointerInteractionActive = false
            // Native window dragging can temporarily move the pointer outside
            // the original tracking area. Re-evaluate hover only after AppKit
            // has completed the drag, otherwise compact mode collapses mid-drag.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let screenPoint = NSEvent.mouseLocation
                let windowPoint = self.convertPoint(fromScreen: screenPoint)
                let inside = self.contentView?.bounds.contains(
                    self.contentView?.convert(windowPoint, from: nil) ?? .zero
                ) ?? false
                NotificationCenter.default.post(
                    name: .salaryClockPointerAfterDrag,
                    object: self,
                    userInfo: ["inside": inside]
                )
            }
        }
    }
}

/// A small menu-bar control keeps the borderless widget reachable after it is hidden.
final class SalaryClockAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var retainedWidgetWindow: NSPanel?
    private var hasCreatedInitialWidget = false

    func applicationWillTerminate(_ notification: Notification) {
        if let window = WidgetWindowActions.widgetWindow {
            WidgetWindowActions.savePosition(of: window)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // macOS 默认不会在应用处于前台时展示通知；显式声明前台展示方式。
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = appIcon
        }

        // Remove already-delivered tiles once after the icon artwork changes;
        // old notification tiles can retain a cached snapshot of the previous app icon.
        let iconRevision = "salary-clock-svg-icon-v1"
        if UserDefaults.standard.string(forKey: "salary-clock.notification-icon-revision") != iconRevision {
            notificationCenter.removeAllDeliveredNotifications()
            UserDefaults.standard.set(iconRevision, forKey: "salary-clock.notification-icon-revision")
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "¥"
        item.button?.toolTip = AppLocalization.string("薪资时钟", language: Self.savedLanguage())

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        rebuildMenu(menu)

        // Keep a regular app activation policy so macOS reliably presents the
        // floating panel on launch; the panel itself remains non-activating.
        NSApp.setActivationPolicy(.regular)
        // SwiftUI may restore its empty Settings scene from the previous run.
        // Close that placeholder before presenting the real floating widget so
        // users never see a transient blank preferences window on launch.
        DispatchQueue.main.async {
            Self.closeRestoredPlaceholderWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            Self.closeRestoredPlaceholderWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.showWidgetOnLaunch()
        }
    }

    @MainActor
    private static func closeRestoredPlaceholderWindows() {
        for restored in NSApp.windows where restored.title.contains("设置") && restored.identifier != WidgetWindowActions.windowIdentifier {
            restored.orderOut(nil)
            restored.close()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWidgetOnLaunch()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Reconcile the daily notification after sleep/wake or returning from
        // Notification settings; the system keeps pending calendar triggers
        // while the app is suspended, and this verifies the configured request.
        SalaryClockModel.shared.configureAfterWorkReminder()
        guard !hasCreatedInitialWidget else { return }
        DispatchQueue.main.async { [weak self] in self?.showWidgetOnLaunch() }
    }

    @MainActor
    private func showWidgetOnLaunch() {
        hasCreatedInitialWidget = true
        let window: NSWindow
        if let existing = WidgetWindowActions.widgetWindow {
            window = existing
        } else {
            let model = SalaryClockModel.shared
            let root = FloatingWidgetView()
                .environmentObject(model)
                .environment(\.locale, model.settings.language.locale)
            let hosting = NSHostingController(rootView: root)
            hosting.view = MovableWidgetHostingView(rootView: root)
            // A floating widget is an NSPanel, not a document NSWindow.
            // Borderless NSWindows cannot become key windows; trying to activate
            // them caused AppKit to reject presentation on some macOS versions.
            let created = SalaryClockPanel(contentViewController: hosting)
            created.identifier = WidgetWindowActions.windowIdentifier
            created.title = "Salary Clock"
            created.styleMask = [.borderless, .nonactivatingPanel]
            created.level = model.settings.alwaysOnTop ? .floating : .normal
            created.becomesKeyOnlyIfNeeded = true
            created.isOpaque = false
            created.backgroundColor = .clear
            created.hasShadow = true
            created.hidesOnDeactivate = false
            // Use AppKit's native background drag. No per-event frame updates:
            // native window dragging is smoother and keeps mouse/window coordinates in sync.
            created.isMovable = true
            created.isMovableByWindowBackground = !model.settings.windowLocked
            // Stay on the current desktop only. Do not appear in every Space or
            // over full-screen applications unless the user explicitly changes
            // the window's placement in a future setting.
            created.collectionBehavior = [.ignoresCycle]
            created.isRestorable = false
            let initialSize = model.settings.compactMode
                ? NSSize(width: 210, height: 58)
                : NSSize(width: 340, height: 310)
            created.setContentSize(initialSize)
            created.minSize = NSSize(width: 190, height: 48)
            created.contentMinSize = NSSize(width: 190, height: 48)
            WidgetWindowActions.restorePosition(for: created)
            retainedWidgetWindow = created
            window = created
        }
        WidgetWindowActions.observePosition(of: window)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        WidgetWindowActions.applyWindowLevel(to: window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            WidgetWindowActions.applyWindowLevel(to: window)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
        statusItem?.button?.toolTip = AppLocalization.string("薪资时钟", language: Self.savedLanguage())
    }

    private func rebuildMenu(_ menu: NSMenu) {
        let language = Self.savedLanguage()
        menu.removeAllItems()
        let toggle = NSMenuItem(title: AppLocalization.string("隐藏 / 显示薪资时钟", language: language), action: #selector(toggleWidget), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let settings = NSMenuItem(title: AppLocalization.string("设置…", language: language), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        settings.keyEquivalentModifierMask = [.command]
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: AppLocalization.string("退出薪资时钟", language: language), action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private static func savedLanguage() -> AppLanguage {
        let key = "salary-clock.settings.v1"
        let data = UserDefaults(suiteName: "WXFKXAFBJ8.salaryclock")?.data(forKey: key)
            ?? UserDefaults.standard.data(forKey: key)
        return data.flatMap { try? JSONDecoder().decode(SalarySettings.self, from: $0).language } ?? .simplifiedChinese
    }

    @MainActor @objc private func toggleWidget() {
        WidgetWindowActions.toggle()
    }

    @MainActor @objc private func openSettings() {
        SettingsWindowController.shared.toggle(model: SalaryClockModel.shared)
    }

    @MainActor @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(model: SalaryClockModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let content = SettingsView().environmentObject(model)
        let hosting = NSHostingController(rootView: content)
        let panel = NSWindow(contentViewController: hosting)
        panel.title = AppLocalization.string("设置", language: model.settings.language)
        panel.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        panel.setContentSize(NSSize(width: 790, height: 720))
        panel.minSize = NSSize(width: 720, height: 620)
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.isMovableByWindowBackground = true
        panel.center()
        panel.level = .floating
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel
    }

    func toggle(model: SalaryClockModel) {
        if let window, window.isVisible {
            window.orderOut(nil)
        } else {
            show(model: model)
        }
    }

    func close() {
        window?.close()
        window = nil
    }
}
