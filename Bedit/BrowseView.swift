import SwiftUI
import AppKit
import BvfAppKitDecrypt

struct BrowseView: View {
    @Environment(FileAccessManager.self) var fileAccessManager
    @Environment(AppSettings.self) var appSettings
    @Environment(SyncManager.self) var syncManager
    @State private var viewModel: BrowseViewModel?

    @FocusState private var isSearchFieldFocused: Bool
    @State private var isSearchPopoverPresented = false
    @State private var showTagSheet = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                let groupedFilteredEntries = groupDatesByDay(viewModel.filteredDates)
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        headerView(viewModel: viewModel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .padding(.top, 8)

                        if let folderURL = viewModel.folderURL {
                            EntryListView(
                                session: viewModel.session,
                                folderURL: folderURL,
                                groupedEntryDates: groupedFilteredEntries,
                                searchText: viewModel.searchText,
                                viewModel: viewModel
                            )
                            .frame(minWidth: 300, minHeight: 200)
                            .background(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        } else {
                            Text("No folder configured")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .browseToolbar(
                    viewModel: viewModel,
                    configuration: BrowseToolbarConfiguration(
                        clearHelpText: "Clear all entries",
                        importFileFilter: isImportableFile,
                        outputSuffix: outputSuffixForFile,
                        fileProcessor: extractText,
                        additionalContent: { AnyView(searchButton(viewModel: viewModel)) },
                        additionalPopoverShowing: $isSearchPopoverPresented
                    ),
                    showTagSheet: $showTagSheet
                )
                .browseModals(
                    viewModel: viewModel,
                    showTagSheet: $showTagSheet
                )
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = BrowseViewModel(fileAccessManager: fileAccessManager, appSettings: appSettings, syncManager: syncManager)
                viewModel = vm
                vm.initializeFileAccess()
            }
        }
    }

    private func headerView(viewModel: BrowseViewModel) -> some View {
        DateRangeRowView(
            startDate: Binding(get: { viewModel.startDate }, set: { viewModel.startDate = $0 }),
            endDate: Binding(get: { viewModel.endDate }, set: { viewModel.endDate = $0 }),
            selectedPreset: Binding(get: { viewModel.selectedPreset }, set: { viewModel.selectedPreset = $0 }),
            isReady: viewModel.isReady,
            isLoading: viewModel.isLoading,
            responseMessage: viewModel.responseMessage,
            setupErrorMessage: viewModel.setupErrorMessage,
            onDecrypt: { await viewModel.loadEntries() }
        )
    }

    private func searchButton(viewModel: BrowseViewModel) -> some View {
        Button(action: {
            isSearchPopoverPresented = true
        }) {
            Image(systemName: "magnifyingglass")
        }
        .help("Search entries")
        .keyboardShortcut("f", modifiers: .command)
        .popover(isPresented: $isSearchPopoverPresented) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Search entries…", text: Binding(
                        get: { viewModel.searchText },
                        set: { viewModel.searchText = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .focused($isSearchFieldFocused)
                    .onSubmit { viewModel.runSearch() }
                    .onAppear {
                        DispatchQueue.main.async { isSearchFieldFocused = true }
                    }

                    if viewModel.isLoading {
                        ProgressView().controlSize(.small)
                    }
                }

                if viewModel.isLoading {
                    Button("Cancel") { viewModel.cancelOrClearSearch() }
                        .buttonStyle(.bordered)
                } else if !viewModel.searchText.isEmpty || viewModel.searchResults != nil {
                    Button("Clear Search") { viewModel.cancelOrClearSearch() }
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
}
