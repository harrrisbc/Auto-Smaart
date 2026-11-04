import SwiftUI
import AppKit
import AutoSmaartUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SPM executables default to accessory/background and drop mouse clicks.
        NSApp.setActivationPolicy(.regular)
        // Without a bundle, AppKit may idle-exit or quit when a WindowGroup hiccups.
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("Auto-Smaart window")
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Landing must stay up; do not quit if the first WindowGroup presentation races.
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if !flag {
            // Ask SwiftUI/AppKit to show a window again if the user closed it.
            NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        }
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
                    // Activate only — ordering front during WindowGroup presentation caused
                    // "Window move completed without beginning" and a silent quit.
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
    }
}
