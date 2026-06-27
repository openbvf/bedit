import SwiftUI

struct BeditSettingsSection: View {
    @AppStorage("journalAutosaveInterval") private var journalAutosaveInterval: Double = 60.0

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Autosave after \(Int(journalAutosaveInterval)) seconds of inactivity")
                    .foregroundStyle(.primary)

                Slider(value: $journalAutosaveInterval, in: 3...120, step: 1)
            }
        }
    }
}
