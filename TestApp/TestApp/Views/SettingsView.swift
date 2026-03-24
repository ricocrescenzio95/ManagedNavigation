import SwiftUI
import ManagedNavigation

struct SettingsView: View {
  @Environment(\.navigator) private var navigator
  
  @State private var notificationsEnabled = true
  @State private var darkMode = false
  @State private var autoSave = true
  @State private var selectedLanguage = "English"
  @State private var cacheSize = 50.0
  
  private let languages = ["English", "Italian", "Spanish", "French", "German"]
  
  var body: some View {
    List {
      // MARK: - Breadcrumbs
      Section {
        NavigationBreadcrumbs()
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
      }
      
      // MARK: - General
      Section("General") {
        Picker("Language", selection: $selectedLanguage) {
          ForEach(languages, id: \.self) { Text($0) }
        }
        Toggle("Dark Mode", isOn: $darkMode)
        Toggle("Auto-Save", isOn: $autoSave)
      }
      
      // MARK: - Notifications
      Section("Notifications") {
        Toggle("Enable Notifications", isOn: $notificationsEnabled)
        Button("Push Notification Settings") {
          navigator?.push(PushNotificationsSettingsDestination(id: UUID().uuidString))
        }
      }
      
      // MARK: - Storage
      Section {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Cache Size")
            Spacer()
            Text("\(Int(cacheSize)) MB")
              .foregroundStyle(.secondary)
          }
          Slider(value: $cacheSize, in: 10...200, step: 10)
        }
        HStack {
          Text("Documents")
          Spacer()
          Text("1.2 GB")
            .foregroundStyle(.secondary)
        }
        HStack {
          Text("Temporary Files")
          Spacer()
          Text("340 MB")
            .foregroundStyle(.secondary)
        }
        Button("Clear Cache", role: .destructive) {}
      } header: {
        Text("Storage")
      }
      
      // MARK: - State Restoration
      Section("State Restoration") {
        StateRestorationGrid()
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
      }
      
      // MARK: - About
      Section("About") {
        HStack {
          Text("Version")
          Spacer()
          Text("2.1.0")
            .foregroundStyle(.secondary)
        }
        HStack {
          Text("Build")
          Spacer()
          Text("421")
            .foregroundStyle(.secondary)
        }
      }
      
      // MARK: - Actions
      Section {
        Button("Pop to Root") {
          navigator?.popToRoot()
        }
      }
    }
    .sheet(for: PushNotificationsSettingsDestination.self) { context in
      NavigationStack {
        PushNotificationsSettingsView(id: context.destination.id, isEnabled: notificationsEnabled)
          .task {
            try? await Task.sleep(for: .seconds(2))
            notificationsEnabled = false
            try? await Task.sleep(for: .seconds(2))
            navigator?.replace(PushNotificationsSettingsDestination(id: "changed"), at: context.index)
          }
      }
    }
    .navigationDestination(for: PushNotificationsSettingsDestination.self) {
      PushNotificationsSettingsView(id: $0.id, isEnabled: notificationsEnabled)
    }
    .navigationTitle("Settings")
    .macOSModifiers()
  }
}
