import SwiftUI

/// Clipboard History utility module - tracks recent pasteboard contents locally.
struct ClipboardHistoryModule: UtilityModule {
    let id = "clipboardHistory"
    let name = "Clipboard History"
    let icon = "doc.on.clipboard"
    let contentTint = UNConstants.clipboardContentTint
    var isEnabled = true
    let supportsBackground = true
    
    func makeMainView() -> AnyView {
        AnyView(ClipboardModuleView())
    }
    
    func makeSettingsView() -> AnyView? {
        AnyView(ClipboardHistorySettingsView())
    }
}

private struct ClipboardHistorySettingsView: View {
    @AppStorage(ClipboardHistorySettingsKey.maxItems) private var maxItems: Int = ClipboardHistorySettingsKey.defaultMaxItems

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clipboard History Settings")
                .font(.headline)

            Picker("Maximum stored items", selection: $maxItems) {
                ForEach([10, 20, 30, 50, 100, 200], id: \.self) { limit in
                    Text("\(limit)").tag(limit)
                }
            }

            Text("Older clipboard entries are deleted locally when the limit is exceeded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onChange(of: maxItems) { _, newValue in
            trimPersistedHistory(to: newValue)
        }
    }

    private func trimPersistedHistory(to limit: Int) {
        let safeLimit = min(max(limit, 5), 200)
        let persistence = PersistenceManager.shared
        var items = persistence.load([ClipboardHistoryItem].self, key: .clipboardHistory) ?? []
        guard items.count > safeLimit else { return }
        items.removeLast(items.count - safeLimit)
        persistence.save(items, key: .clipboardHistory)
    }
}
