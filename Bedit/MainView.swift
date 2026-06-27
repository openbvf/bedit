import SwiftUI
import BvfAppKitDecrypt

struct MainView: View {
    @Environment(TabSelection.self) var tabSelection
    @Environment(FileAccessManager.self) var fileAccessManager
    @Environment(AppSettings.self) var appSettings
    @State private var showOnboarding = false
    @AppStorage("bedit.textSize") private var textSize: Double = 14

    var body: some View {
        @Bindable var tabSelection = tabSelection
        TabView(selection: $tabSelection.selected) {
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "pencil")
                }.tag(0)

            if fileAccessManager.isStandardMode {
                BrowseView()
                    .tabItem {
                        Label("Browse", systemImage: "house.fill")
                    }.tag(1)
            }
        }
        .tabCyclingShortcuts(
            selection: $tabSelection.selected,
            count: fileAccessManager.isStandardMode ? 2 : 1
        )
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { textSize = max(textSize - 2, 10) } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .disabled(textSize <= 10)
                .help("Make text smaller")

                Button { textSize = min(textSize + 2, 28) } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .disabled(textSize >= 28)
                .help("Make text bigger")
            }
        }
        .task {
            if !fileAccessManager.isConfigured && !appSettings.hasSkippedOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(appName: "Bedit", appGroupIdentifier: "group.io.bvf.shared")
        }
    }
}
