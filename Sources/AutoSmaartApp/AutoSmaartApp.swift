import SwiftUI
import AutoSmaartUI

@main
struct AutoSmaartApp: App {
    var body: some Scene {
        WindowGroup {
            ShellView(controller: AppRuntime.controller)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
    }
}
