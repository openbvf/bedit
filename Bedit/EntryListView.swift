import SwiftUI
import AppKit
import BvfAppKitDecrypt

private struct EntryTextView: NSViewRepresentable {
    let text: String
    let textSize: Double
    let searchText: String
    @Binding var height: CGFloat

    final class Coordinator {
        var lastText: String?
        var lastSize: Double?
        var lastSearchText: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSTextView {
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.drawsBackground = false
        tv.isVerticallyResizable = false
        tv.isHorizontallyResizable = false
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainerInset = .zero
        tv.textContainer?.widthTracksTextView = true
        return tv
    }

    func updateNSView(_ tv: NSTextView, context: Context) {
        let coord = context.coordinator
        let textChanged = coord.lastText != text
        let sizeChanged = coord.lastSize != textSize
        let searchChanged = coord.lastSearchText != searchText

        if !textChanged && !sizeChanged && !searchChanged { return }

        if textChanged || sizeChanged {
            let attributed = NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: textSize),
                    .foregroundColor: NSColor.labelColor
                ]
            )
            tv.textStorage?.setAttributedString(attributed)
            coord.lastText = text
            coord.lastSize = textSize
        }

        if textChanged || sizeChanged || searchChanged {
            let fullRange = NSRange(location: 0, length: tv.textStorage?.length ?? 0)
            tv.layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            tv.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)

            if !searchText.isEmpty {
                let nsString = tv.string as NSString
                var searchRange = NSRange(location: 0, length: nsString.length)
                while searchRange.location < nsString.length {
                    let found = nsString.range(of: searchText, options: .caseInsensitive, range: searchRange)
                    guard found.location != NSNotFound else { break }
                    tv.layoutManager?.addTemporaryAttribute(.backgroundColor, value: NSColor.yellow, forCharacterRange: found)
                    tv.layoutManager?.addTemporaryAttribute(.foregroundColor, value: NSColor.black, forCharacterRange: found)
                    searchRange.location = found.location + found.length
                    searchRange.length = nsString.length - searchRange.location
                }
            }
            coord.lastSearchText = searchText
        }

        if textChanged || sizeChanged {
            tv.layoutManager?.ensureLayout(for: tv.textContainer!)
            let usedRect = tv.layoutManager?.usedRect(for: tv.textContainer!) ?? .zero
            let newHeight = max(usedRect.height, 14)
            if abs(newHeight - height) > 0.5 {
                DispatchQueue.main.async {
                    height = newHeight
                }
            }
        }
    }
}

/// A view that lazily decrypts and displays a single entry
private struct EntryRowView: View {
    let date: Date
    let session: DecryptionSession?
    let searchText: String
    var viewModel: BrowseViewModel
    @State private var text: String = ""
    @State private var textHeight: CGFloat = 14
    @State private var showTagPopover = false
    @State private var errorMessage: String?
    @AppStorage("bedit.textSize") private var textSize: Double = 14

    private var actionCount: Int {
        viewModel.selectedDates.contains(date) ? viewModel.selectedDates.count : 1
    }

    private func label(_ base: String, shortcut: String? = nil) -> String {
        let count = actionCount > 1 ? " (\(actionCount))" : ""
        let hint = shortcut.map { "  \($0)" } ?? ""
        return "\(base)\(count)\(hint)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .italic()
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                EntryTextView(text: text, textSize: textSize, searchText: searchText, height: $textHeight)
                    .frame(maxWidth: .infinity, minHeight: textHeight, alignment: .leading)
            }
            Text(date.timeString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy") {
                viewModel.ensureExclusivelySelected(date)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            .disabled(text.isEmpty)
            Button(label("Manage Tags", shortcut: "⌘T")) {
                viewModel.ensureExclusivelySelected(date)
                showTagPopover = true
            }
            .disabled(!viewModel.metadataLoaded)
            Button(label("Delete", shortcut: "⌘⌫")) {
                viewModel.ensureExclusivelySelected(date)
                viewModel.showDeleteConfirmation = true
            }
            Button(label("Change Date")) {
                viewModel.ensureExclusivelySelected(date)
                viewModel.datePickerValue = date
                viewModel.showDatePicker = true
            }
            Button(label("Export")) {
                viewModel.ensureExclusivelySelected(date)
                Task {
                    await viewModel.exportSelected()
                }
            }
        }
        .tagPopover(
            isPresented: $showTagPopover,
            date: date,
            selectedDates: viewModel.selectedDates,
            viewModel: viewModel
        )
        .task(id: date) {
            try? await Task.sleep(for: .milliseconds(BvfAppKitConfig.decryptionDebounceMs))
            guard !Task.isCancelled else { return }

            guard let session,
                  let url = viewModel.filesByDate[date] else { return }
            do {
                let data = try await Task.detached {
                    try await session.decrypt(contentsOf: url).data
                }.value
                if let string = String(data: data, encoding: .utf8) {
                    text = string
                }
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct EntryListView: View {
    let session: DecryptionSession?
    let folderURL: URL
    let groupedEntryDates: [(day: Date, dates: [Date])]
    let searchText: String
    let viewModel: BrowseViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedEntryDates, id: \.day) { group in
                    Section {
                        ForEach(group.dates, id: \.self) { date in
                            EntryRowView(
                                date: date,
                                session: session,
                                searchText: searchText,
                                viewModel: viewModel
                            )
                                .selectableItem(date: date, isSelected: viewModel.selectedDates.contains(date)) {
                                    viewModel.handleSelection(date, in: viewModel.filteredDates)
                                }
                                .padding(.horizontal)
                        }
                    } header: {
                        Text(group.day.dayWithWeekdayString)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                            .background(.background)
                    }
                }
            }
        }
        .defaultScrollAnchor(.top)
    }
}
