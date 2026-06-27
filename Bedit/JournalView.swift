import SwiftUI
import BvfAppKitDecrypt

struct JournalView: View {
    @Environment(FileAccessManager.self) private var fileAccessManager
    @Environment(iCloudManager.self) private var cloudManager
    @AppStorage("journalAutosaveInterval") private var journalAutosaveInterval: Double = 60.0
    @State private var autosaveTask: Task<Void, Never>?

    @State private var journalEntryBody: String = ""
    @State private var hasPromotedDraftThisSession: Bool = false
    @State private var hide = false
    @State private var responseMessage: ResponseMessage?
    @State private var draftNotification: String?
    @State private var showICloudPrompt = false
    @FocusState private var isTextEditorFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("bedit.textSize") private var textSize: Double = 14

    @State private var showTypingFlash = false
    @State private var flashTask: Task<Void, Never>?

    private let draftService = DraftService()

    private var publicKeyURL: URL? { fileAccessManager.capturePublicKeyURL }
    private var folderURL: URL? { fileAccessManager.captureFolderURL }

    func writeFile() {
        guard let pubKeyURL = publicKeyURL,
              let folderURL = folderURL else {
            responseMessage = ResponseMessage("Missing required folder or public key file", type: .error)
            return
        }

        guard let textData = journalEntryBody.data(using: .utf8) else {
            responseMessage = ResponseMessage("Failed to encode text", type: .error)
            return
        }

        Task {
            do {
                _ = try await BvfStore.write(
                    data: textData,
                    to: folderURL,
                    publicKeyURL: pubKeyURL,
                    suffix: "txt"
                )
                await MainActor.run {
                    clearDraft()
                    journalEntryBody = ""
                    responseMessage = ResponseMessage("Saved at \(Date().timeString)", type: .success)
                }
            } catch {
                await MainActor.run {
                    responseMessage = ResponseMessage(error.localizedDescription, type: .error)
                }
            }
        }
    }

    private func saveDraft() {
        guard let pubKeyURL = publicKeyURL else {
            return
        }

        _ = draftService.saveDraft(
            text: journalEntryBody,
            publicKeyURL: pubKeyURL
        )
    }

    private func promoteDraft() {
        // Only promote once per app session — re-promotion on phase change would resurrect a draft the user just discarded.
        guard !hasPromotedDraftThisSession,
              let folderURL = folderURL else {
            return
        }

        hasPromotedDraftThisSession = true

        if let notification = draftService.promoteDraftOnLaunch(folderURL: folderURL, publicKeyURL: publicKeyURL) {
            draftNotification = notification

            Task {
                try? await Task.sleep(for: .seconds(5))
                draftNotification = nil
            }
        }
    }

    private func clearDraft() {
        _ = draftService.clearDraft()
    }

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .padding(.top, 8)

                TextEditor(text: $journalEntryBody)
                    .font(.system(size: textSize))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .focused($isTextEditorFocused)
                    .opacity(hide ? 0 : 1)
            }
        }
        .alert("iCloud Drive Required", isPresented: $showICloudPrompt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Bedit is set to iCloud Write-Only mode. Enable iCloud Drive in System Settings to continue.")
        }
        .task {
            promoteDraft()

            if fileAccessManager.isCloudWriteMode && !cloudManager.isAvailable {
                showICloudPrompt = true
            }

            isTextEditorFocused = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                DispatchQueue.main.async {
                    isTextEditorFocused = true
                }
            }
        }
        .onDisappear {
            autosaveTask?.cancel()
        }
        .onChange(of: journalEntryBody) { _, _ in
            if hide {
                showTypingFlash = true
                flashTask?.cancel()
                flashTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    showTypingFlash = false
                }
            }

            if !journalEntryBody.isEmpty {
                saveDraft()
            } else {
                clearDraft()
            }

            autosaveTask?.cancel()
            autosaveTask = Task {
                let interval = journalAutosaveInterval > 0 ? journalAutosaveInterval : 60
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, !journalEntryBody.isEmpty else { return }
                writeFile()
            }
        }
    }

    private var isReady: Bool {
        publicKeyURL != nil && folderURL != nil
    }

    private var setupErrorMessage: ResponseMessage? {
        fileAccessManager.validateCaptureConfiguration(folderName: "journal folder")
    }

    private var headerView: some View {
        HStack {
            ReadyIndicatorView(isReady: isReady)

            // Status priority: response message > setup error > draft notification.
            if let message = responseMessage {
                Text(message.text)
                    .font(.caption)
                    .foregroundColor(message.type.color)
                    .lineLimit(2)
                    .transition(.opacity)
            } else if let error = setupErrorMessage {
                Text(error.text)
                    .font(.caption)
                    .foregroundColor(error.type.color)
                    .lineLimit(2)
            } else if let notification = draftNotification {
                Text(notification)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .transition(.opacity)
            }

            Spacer()

            Button(action: {
                hide.toggle()
            }) {
                Text("Hide")
            }
            .buttonStyle(.bordered)
            .tint(showTypingFlash ? .white : (hide ? .accentColor : .secondary))
            .keyboardShortcut("I", modifiers: .command)

            Button(action: {
                if !journalEntryBody.isEmpty {
                    writeFile()
                }
            }) {
                Label("Save", systemImage: "lock.doc")
            }
            .buttonStyle(.borderedProminent)
            .disabled(journalEntryBody.isEmpty)
            .keyboardShortcut("S", modifiers: .command)
        }
    }

}
