import SwiftUI
import AppKit

@main
struct SalaryClockApp: App {
    @StateObject private var model = SalaryClockModel()

    var body: some Scene {
        WindowGroup {
            FloatingWidgetView()
                .environmentObject(model)
                .background(WindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 340, height: 310)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowConfigView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowConfigView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        configure(window)
    }

    private func configure(_ window: NSWindow) {
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.minSize = NSSize(width: 310, height: 180)
        window.contentMinSize = NSSize(width: 310, height: 180)
        window.setContentSize(NSSize(width: 340, height: 310))
    }
}
