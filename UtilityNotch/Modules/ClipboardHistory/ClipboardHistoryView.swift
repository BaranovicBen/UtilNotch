import SwiftUI

/// Clipboard History view — displays a scrollable list of recent clipboard entries.
/// Mock data in beta. Replace with real NSPasteboard monitoring later.
struct ClipboardHistoryView: View {
    @State private var entries: [ClipboardEntry] = ClipboardEntry.mockEntries
    @State private var searchText: String = ""
    
    private var filteredEntries: [ClipboardEntry] {
        if searchText.isEmpty { return entries }
        return entries.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Clipboard History", systemImage: "doc.on.clipboard")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(entries.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)
            
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search clipboard…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 10)
            
            // List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredEntries) { entry in
                        ClipboardRow(entry: entry) {
                            copyToClipboard(entry)
                        } onDelete: {
                            deleteEntry(entry.id)
                        }
                    }
                }
            }
            
            // Footer hint
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("Click to copy • Real clipboard monitoring requires Accessibility permission")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Actions
    
    private func copyToClipboard(_ entry: ClipboardEntry) {
        // MARK: TODO — replace with real pasteboard write
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.content, forType: .string)
    }
    
    private func deleteEntry(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            entries.removeAll { $0.id == id }
        }
    }
}

// MARK: - Row

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.content)
                    .lineLimit(2)
                    .font(.callout)
                Text(entry.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if isHovering {
                HStack(spacing: 6) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovering ? Color.white.opacity(0.04) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { onCopy() }
        .onHover { isHovering = $0 }
    }
}

// MARK: - Model

struct ClipboardEntry: Identifiable {
    let id = UUID()
    let content: String
    let icon: String
    let timeAgo: String
    
    /// Mock data for beta
    static let mockEntries: [ClipboardEntry] = [
        ClipboardEntry(content: "https://developer.apple.com/documentation/swiftui", icon: "link", timeAgo: "Just now"),
        ClipboardEntry(content: "Meeting notes: discussed roadmap priorities and Q2 deadlines", icon: "doc.text", timeAgo: "2 min ago"),
        ClipboardEntry(content: "struct ContentView: View { var body: some View { Text(\"Hello\") } }", icon: "curlybraces", timeAgo: "5 min ago"),
        ClipboardEntry(content: "benjamin@example.com", icon: "envelope", timeAgo: "12 min ago"),
        ClipboardEntry(content: "The quick brown fox jumps over the lazy dog", icon: "doc.text", timeAgo: "30 min ago"),
        ClipboardEntry(content: "/Users/benjamin/Documents/project/readme.md", icon: "folder", timeAgo: "1 hr ago"),
        ClipboardEntry(content: "🎉 Ship it!", icon: "face.smiling", timeAgo: "2 hrs ago"),
    ]
}
