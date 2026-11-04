import SwiftUI
import AppKit
import Darwin
import AutoSmaartUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Agent / terminal launches send SIGHUP when the launcher shell exits.
        signal(SIGHUP, SIG_IGN)
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("Auto-Smaart window")
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if !flag {
            NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        }
        return true
    }
}

@main
struct AutoSmaartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        signal(SIGHUP, SIG_IGN)
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        // Single Window avoids WindowGroup spawning extra off-screen scenes that then vanish.
        Window("Auto-Smaart", id: "main") {
            ShellView(controller: AppRuntime.controller)
                .onAppear {
                    AppRuntime.controller.refreshSessionFlag()
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
        .defaultPosition(.center)
    }
}
