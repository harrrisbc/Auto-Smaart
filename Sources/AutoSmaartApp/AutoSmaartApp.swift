import SwiftUI
import AppKit
import AutoSmaartUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SPM executables default to accessory/background and drop mouse clicks.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        return true
    }
}

@main
struct AutoSmaartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ShellView(controller: AppRuntime.controller)
                .onAppear {
                    AppRuntime.controller.refreshSessionFlag()
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
    }
}
