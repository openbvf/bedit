import AppIntents

struct BeditShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveEntryIntent(),
            phrases: [
                "Save to \(.applicationName)"
            ],
            shortTitle: "Save Bedit Entry",
            systemImageName: "square.and.pencil"
        )
    }
}
