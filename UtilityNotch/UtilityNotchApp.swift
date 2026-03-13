//
//  UtilityNotchApp.swift
//  UtilityNotch
//

import SwiftUI

@main
struct UtilityNotchApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    private var appState: AppState { AppState.shared }
    
    var body: some Scene {
        // Menu bar icon — the only persistent UI element
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.expand.vertical")
                Text(appState.summaryTextForMenuBar())
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
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
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.summaryTextForMenuBar())
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
            Divider()
        }
        
        Button(appState.isPanelVisible ? "Hide Notch Panel" : "Show Notch Panel") {
            appState.togglePanel()
        }
        .keyboardShortcut("n", modifiers: [.option])
        
        Divider()
        
        Button("Settings…") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Divider()
        
        Button("Quit Utility Notch") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

// MARK: - Settings Root (tabbed)

struct SettingsRootView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .environment(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            ModuleSettingsView()
                .environment(appState)
                .tabItem {
                    Label("Modules", systemImage: "square.grid.2x2")
                }
            
            PermissionsInfoView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(width: 520, height: 460)
    }
}
