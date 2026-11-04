import SwiftUI
import AppKit
import AutoSmaartUI

@main
struct AutoSmaartApp: App {
    init() {
        // SPM executables default to BackgroundOnly and do not take mouse clicks.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ShellView(controller: AppRuntime.controller)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
    }
}
