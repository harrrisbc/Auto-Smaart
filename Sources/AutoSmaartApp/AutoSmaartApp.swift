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
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.isReleasedWhenClosed = false
                window.collectionBehavior.insert(.moveToActiveSpace)
                window.center()
                window.makeKeyAndOrderFront(nil)
            }
        }
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
    @State private var mode: AppMode = .calibration

    init() {
        signal(SIGHUP, SIG_IGN)
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("Auto-Smaart", id: "main") {
            ShellView(
                mode: $mode,
                calibration: AppRuntime.controller,
                ringOut: AppRuntime.ringOut
            )
            .onAppear {
                AppRuntime.controller.refreshSessionFlag()
                AppRuntime.ringOut.updateHost(AppRuntime.box.host)
                AppRuntime.ringOut.updatePort(AppRuntime.box.port)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
        .defaultPosition(.center)
    }
}
