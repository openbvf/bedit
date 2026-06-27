import SwiftUI
import BvfAppKitDecrypt

@MainActor
@Observable
final class BrowseViewModel: BrowseViewModelBase {
    var searchText = ""
    var searchResults: [Date]?

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    public override var itemTypeName: String { "entries" }

    var isReady: Bool {
        return fileAccessManager.privateKeyURL != nil && fileAccessManager.savedFolderURL != nil
    }

    var setupErrorMessage: String? {
        let hasKey = fileAccessManager.privateKeyURL != nil
        let hasFolder = fileAccessManager.savedFolderURL != nil

        if hasKey && hasFolder { return nil }
        if !hasKey && !hasFolder { return "Missing private key and journal folder. Configure in Settings." }
        if !hasKey { return "Missing private key. Configure in Settings." }
        return "Missing journal folder. Configure in Settings."
    }

    init(fileAccessManager: FileAccessManager, appSettings: AppSettings, syncManager: SyncManager) {
        let range = DateRangePreset.last7Days.dateRange()
        super.init(startDate: range.start, endDate: range.end, appSettings: appSettings, fileAccessManager: fileAccessManager, syncManager: syncManager)
    }

    func initializeFileAccess() {
        updateSyncWatching()
    }

    func updateSyncWatching() {
        syncManager.updateWatchingState()
    }

    public override func applyFilters(to dates: [Date]) -> [Date] {
        let baseDates = searchResults ?? dates
        return filterByTag(baseDates)
    }

    public override func populate(from files: [URL]) {
        searchTask?.cancel()
        searchTask = nil
        searchResults = nil
        searchText = ""
        super.populate(from: files)
    }

    public override func clearSensitiveData(reason: String? = nil) {
        searchTask?.cancel()
        searchTask = nil
        super.clearSensitiveData(reason: reason)
        searchText = ""
        searchResults = nil
    }

    /// Run search for current searchText. Called from view on Enter.
    /// Cancels any in-flight search before starting a new one.
    func runSearch() {
        searchTask?.cancel()
        searchTask = Task {
            let searchTerm = searchText.trimmingCharacters(in: .whitespaces)
            guard !searchTerm.isEmpty else {
                searchResults = nil
                responseMessage = nil
                return
            }
            guard let session,
                  fileAccessManager.savedFolderURL != nil else { return }

            isLoading = true
            defer { isLoading = false }
            responseMessage = ResponseMessage("Searching…", type: .info)

            let files = filesByDate
            let targetDates = dates

            var matches: [Date] = []
            for date in targetDates {
                if Task.isCancelled { break }
                guard let url = files[date] else { continue }
                do {
                    let data = try await session.decrypt(contentsOf: url).data
                    if let content = String(data: data, encoding: .utf8),
                       content.localizedCaseInsensitiveContains(searchTerm) {
                        matches.append(date)
                    }
                } catch {
                    continue
                }
            }

            guard !Task.isCancelled else {
                responseMessage = nil
                return
            }

            searchResults = matches.sorted(by: <)
            responseMessage = ResponseMessage("Found \(matches.count) matches", type: .success)
            searchTask = nil
        }
    }

    /// Dual-mode action for the popover's one button.
    /// While a search is in flight, cancels it (results untouched).
    /// Otherwise clears searchText and any prior results.
    func cancelOrClearSearch() {
        if let task = searchTask, isLoading {
            task.cancel()
            searchTask = nil
            return
        }
        searchTask?.cancel()
        searchTask = nil
        searchText = ""
        searchResults = nil
        responseMessage = nil
    }
}
