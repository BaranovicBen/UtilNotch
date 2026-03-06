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
