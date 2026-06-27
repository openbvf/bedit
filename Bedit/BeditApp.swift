import SwiftUI
import BvfAppKitDecrypt

@main
struct BeditApp: App {
    @State private var tabSelection = TabSelection()
    @State private var env = BvfAppKitEnvironment(
        app: "Bedit",
        container: "iCloud.io.bvf.shared",
        appGroupIdentifier: "group.io.bvf.shared"
    )
    @AppStorage("bedit.textSize") private var textSize: Double = 14

    init() {
        DisableCoreDumps.apply()
    }

    var body: some Scene {
        Window("Bedit", id: "main") {
            AppRootView {
                MainView()
                    .environment(tabSelection)
                    .bvfAppKitEnvironment(env)
                    .task {
                        await env.initialize()
                        StagingManager.recoverOrphanedFiles(to: env.cloudManager.appFolderURL)
                    }
            }
        }
        .commands {
            CommandMenu("Tabs") {
                Button("First Tab") { tabSelection.selected = 0 }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Second Tab") { tabSelection.selected = 1 }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Third Tab") { tabSelection.selected = 2 }
                    .keyboardShortcut("3", modifiers: .command)
            }
            CommandMenu("View") {
                Button("Make Text Bigger") { textSize = min(textSize + 2, 28) }
                    .keyboardShortcut("=", modifiers: .command)
                    .disabled(textSize >= 28)
                Button("Make Text Smaller") { textSize = max(textSize - 2, 10) }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(textSize <= 10)
            }
        }

        Settings {
            PreferencesView(appName: "Bedit", appGroupIdentifier: "group.io.bvf.shared") {
                BeditSettingsSection()
            }
            .bvfAppKitEnvironment(env)
        }
    }
}
