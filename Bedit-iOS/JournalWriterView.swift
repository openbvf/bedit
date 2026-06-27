import SwiftUI
import BvfAppKit

struct JournalWriterView: View {
    @Environment(iCloudManager.self) var cloudManager
    @State private var entryText = ""
    @State private var isReady = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var lastSaveDate: Date?
    @State private var showingSaveAlert = false
    @State private var draftNotification: String?
    @FocusState private var isTextEditorFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var inactivityTimer: Timer?

    @State private var draftService = DraftService()
    @State private var publicKeyURL: URL?
    @State private var iCloudURL: URL?

    var body: some View {
        NavigationView {
            JournalWriterContentView(
                entryText: $entryText,
                isReady: $isReady,
                isSaving: $isSaving,
                errorMessage: errorMessage,
                draftNotification: draftNotification,
                lastSaveDate: lastSaveDate,
                isTextEditorFocused: $isTextEditorFocused,
                onSave: saveEntry
            )
            .navigationBarHidden(true)
            .onAppear {
                if cloudManager.isAvailable {
                    setupApp()
                    promoteDraft()
                }
            }
            .onChange(of: cloudManager.isAvailable) { _, available in
                if available && !isReady {
                    setupApp()
                    promoteDraft()
                }
            }
            .onChange(of: isReady) { _, ready in
                if ready {
                    isTextEditorFocused = true
                    resetInactivityTimer()
                }
            }
            .onChange(of: entryText) {
                if isReady && !entryText.isEmpty {
                    saveDraft()
                    resetInactivityTimer()
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background && isReady && !entryText.isEmpty {
                    saveDraft()
                    entryText = ""
                }
                // When returning to active (from background or inactive)
                if newPhase == .active && oldPhase == .background {
                    Task {
                        await loadPublicKey()
                    }

                    // Promote draft (may be discarded if encrypted with old key)
                    promoteDraft()
                }
            }
            .alert(isPresented: $showingSaveAlert) {
                Alert(
                    title: Text("Entry Saved"),
                    message: Text("Your journal entry has been encrypted and saved locally."),
                    primaryButton: .default(Text("New Entry")) {
                        entryText = ""
                        clearDraft()
                    },
                    secondaryButton: .default(Text("Continue"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay {
            if scenePhase != .active {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
            }
        }
    }

    private var canSave: Bool {
        !entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isReady &&
        !isSaving
    }

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
            Task { @MainActor in
                saveEntry()
                entryText = ""
            }
        }
    }

    private func setupApp() {
        guard cloudManager.isAvailable,
              let beditFolder = cloudManager.appFolderURL,
              let publicKey = cloudManager.sharedPublicKeyURL else {
            errorMessage = "iCloud Drive is required. Enable iCloud in Settings → [Your Name] → iCloud → iCloud Drive."
            return
        }

        iCloudURL = beditFolder
        publicKeyURL = publicKey

        do {
            try FileManager.default.createDirectory(
                at: iCloudURL!,
                withIntermediateDirectories: true
            )
        } catch {
            errorMessage = "Failed to create journal directory: \(error.localizedDescription)"
            return
        }

        Task {
            await loadPublicKey()
        }
    }


    private func loadPublicKey() async {
        guard let publicKeyURL = publicKeyURL else { return }

        do {
            guard FileManager.default.fileExists(atPath: publicKeyURL.path) else {
                errorMessage = "iCloud must be set up in this app on a computer first."
                return
            }

            let _ = try Data(contentsOf: publicKeyURL)

            isReady = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load encryption key: \(error.localizedDescription)"
            isReady = false
        }
    }

    private func saveEntry() {
        let content = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty,
              let iCloudURL = iCloudURL,
              let publicKeyURL = publicKeyURL else { return }

        isSaving = true

        Task {
            do {
                let fileURL = try await BvfStore.write(
                    data: Data(content.utf8),
                    to: iCloudURL,
                    publicKeyURL: publicKeyURL,
                    suffix: "txt"
                )

                await MainActor.run {
                    isSaving = false
                    lastSaveDate = Date()
                    errorMessage = nil
                    showingSaveAlert = false
                    clearDraft()
                    entryText = ""

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }

    private func saveDraft() {
        guard let publicKeyURL = publicKeyURL else {
            return
        }

        _ = draftService.saveDraft(
            text: entryText,
            publicKeyURL: publicKeyURL
        )
    }

    private func promoteDraft() {
        guard let iCloudURL = iCloudURL else {
            return
        }

        if let notification = draftService.promoteDraftOnLaunch(folderURL: iCloudURL, publicKeyURL: publicKeyURL) {
            draftNotification = notification

            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                draftNotification = nil
            }
        }
    }

    private func clearDraft() {
        _ = draftService.clearDraft()
    }

}

struct JournalWriterContentView: View {
    @Binding var entryText: String
    @Binding var isReady: Bool
    @Binding var isSaving: Bool
    let errorMessage: String?
    let draftNotification: String?
    let lastSaveDate: Date?
    @FocusState.Binding var isTextEditorFocused: Bool
    let onSave: () -> Void

    @State private var hide = false

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                TextEditor(text: $entryText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .scrollDismissesKeyboard(.interactively)
                    .focused($isTextEditorFocused)
                    .opacity(hide ? 0 : 1)

                toolbarView
            }
        }
    }

    private var headerView: some View {
        HStack {
            if errorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundColor(.orange)
            } else if !isReady {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                ReadyIndicatorView(isReady: isReady)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .lineLimit(2)
            } else if let notification = draftNotification {
                Text(notification)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: {
                hide.toggle()
            }) {
                Text("Hide")
            }
            .buttonStyle(.bordered)
            .tint(hide ? .accentColor : .secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }

    private var toolbarView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let lastSave = lastSaveDate {
                    TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                        Text("Saved \(lastSave.relativeTimeString())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button(action: onSave) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Label("Save", systemImage: "lock.doc")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }

    private var canSave: Bool {
        !entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isReady &&
        !isSaving
    }
}
