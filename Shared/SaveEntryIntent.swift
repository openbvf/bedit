import AppIntents
import BvfAppKit

struct SaveEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Bedit Entry"
    static let description = IntentDescription("Saves an encrypted journal entry to Bedit")

    @Parameter(title: "Text", requestValueDialog: "What would you like to encrypt?")
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: "iCloud.io.bvf.shared"
        ) else {
            return .result(dialog: "iCloud not available")
        }

        #if DEBUG
        let folderURL = containerURL.appendingPathComponent("Documents/Bedit-DEBUG")
        let publicKeyURL = containerURL.appendingPathComponent("Documents/Shared-DEBUG/keys/public.key")
        #else
        let folderURL = containerURL.appendingPathComponent("Documents/Bedit")
        let publicKeyURL = containerURL.appendingPathComponent("Documents/Shared/keys/public.key")
        #endif

        let data = Data(text.utf8)
        _ = try await BvfStore.write(data: data, to: folderURL, publicKeyURL: publicKeyURL, suffix: "txt")

        return .result(dialog: "Encrypted")
    }
}
