import SwiftUI
import BvfAppKit

@main
struct BeditJournalApp: App {
    @State private var cloudManager = iCloudManager("Bedit", container: "iCloud.io.bvf.shared")

    var body: some Scene {
        WindowGroup {
            JournalWriterView()
                .environment(cloudManager)
                .task {
                    // Handles iOS timing issues where container may not be ready immediately
                    await cloudManager.initialize()
                    StagingManager.recoverOrphanedFiles(to: cloudManager.appFolderURL)
                }
        }
    }
}
