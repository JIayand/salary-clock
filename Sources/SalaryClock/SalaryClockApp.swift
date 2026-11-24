import SwiftUI
import AppKit
import UserNotifications

@main
struct SalaryClockApp: App {
    @NSApplicationDelegateAdaptor(SalaryClockAppDelegate.self) private var appDelegate
    @StateObject private var model = SalaryClockModel()

    var body: some Scene {
        WindowGroup {
            FloatingWidgetView()
                .environmentObject(model)
                .background(WindowConfigurator(isLocked: model.settings.windowLocked))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 340, height: 310)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("薪资时钟") {
                Button("隐藏 / 显示悬浮挂件") {
                    WidgetWindowActions.toggle()
                }
                .keyboardShortcut("h", modifiers: [.command, .option])
            }
        }
    }
}

@MainActor
enum WidgetWindowActions {
    static func toggle() {
        guard let window = NSApp.windows.first(where: { !($0 is NSPanel) }) ?? NSApp.windows.first else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
        }
    }
}

/// A small menu-bar control keeps the borderless widget reachable after it is hidden.
final class SalaryClockAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // macOS 默认不会在应用处于前台时展示通知；显式声明前台展示方式。
        UNUserNotificationCenter.current().delegate = self

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "¥"
        item.button?.toolTip = "薪资时钟"

        let menu = NSMenu()
        let toggle = NSMenuItem(title: "隐藏 / 显示薪资时钟", action: #selector(toggleWidget), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出薪资时钟", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    @MainActor @objc private func toggleWidget() {
        WidgetWindowActions.toggle()
    }

    @MainActor @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

struct WindowConfigurator: NSViewRepresentable {
    var isLocked: Bool

    func makeNSView(context: Context) -> NSView {
        let view = WindowConfigView()
        view.isLocked = isLocked
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowConfigView)?.isLocked = isLocked
    }
}

private final class WindowConfigView: NSView {
    var isLocked = false {
        didSet { if let window { window.isMovableByWindowBackground = !isLocked } }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        configure(window)
    }

    private func configure(_ window: NSWindow) {
        // Use a borderless floating surface rather than a conventional macOS document window.
        // This removes the traffic-light controls (especially the visible close button) entirely.
        if window.styleMask.contains(.titled) || window.styleMask.contains(.closable) {
            window.styleMask = [.borderless]
        }
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = !isLocked
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.animationBehavior = .utilityWindow
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.minSize = NSSize(width: 310, height: 180)
        window.contentMinSize = NSSize(width: 310, height: 180)
        window.setContentSize(NSSize(width: 340, height: 310))
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
        panel.title = "薪资时钟设置"
        panel.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        panel.setContentSize(NSSize(width: 470, height: 680))
        panel.minSize = NSSize(width: 470, height: 560)
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.center()
        panel.level = .floating
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel
    }

    func close() {
        window?.close()
        window = nil
    }
}
