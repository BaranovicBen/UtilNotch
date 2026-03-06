//
//  UtilityNotchApp.swift
//  UtilityNotch
//

import SwiftUI

@main
struct UtilityNotchApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        // Menu bar icon — the only persistent UI element
        MenuBarExtra("Utility Notch", systemImage: "rectangle.expand.vertical") {
            MenuBarView()
                .environment(appState)
        }
        
        // Separate settings window (opened via ⌘, or menu)
        Settings {
            SettingsRootView()
                .environment(appState)
        }
    }
}

// MARK: - Menu Bar Dropdown

/// Simple menu that appears when clicking the menu bar icon.
struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Button(appState.isPanelVisible ? "Hide Notch Panel" : "Show Notch Panel") {
            appState.togglePanel()
        }
        .keyboardShortcut("n", modifiers: [.option])
        
        Divider()
        
        SettingsLink {
            Text("Settings…")
        }
        
        Divider()
        
        Button("Quit Utility Notch") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

// MARK: - Placeholder Settings (replaced in Segment 7)

struct SettingsRootView: View {
    var body: some View {
        Text("Settings — coming soon")
            .frame(width: 480, height: 320)
    }
}
