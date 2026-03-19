import SwiftUI
import ManagedNavigation

struct SettingsDestination: NavigationDestination, Codable {}
struct PushNotificationsSettingsDestination: NavigationDestination, Codable {}
struct ProfileDestination: NavigationDestination, Codable {}
struct AccountDestination: NavigationDestination, Codable {}

struct PresentationExample: View {
  @State private var manager = NavigationManager()
  
  var body: some View {
    ManagedPresentation(manager: $manager) {
      NavigationStack {
        VStack(spacing: 16) {
          Section("Sheets") {
            Button("Settings") {
              manager.push(SettingsDestination())
            }
            Button("Profile") {
              manager.push(ProfileDestination())
            }
          }
          
          Section("Full Screen Cover") {
            Button("Account") {
              manager.push(AccountDestination())
            }
          }
          
          Divider().padding(.horizontal)
          
          Section("Multiple") {
            Button("Settings → Profile → Notifications") {
              manager.push([
                SettingsDestination(),
                ProfileDestination(),
                PushNotificationsSettingsDestination(),
              ])
            }
            Button("Replace path: Account") {
              manager = NavigationManager([AccountDestination()])
            }
          }
        }
        .padding()
        .navigationTitle("Presentation")
        .debugView()
      }
      .buttonStyle(.glass)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .sheet(for: SettingsDestination.self) { _ in
        SettingsView()
      }
      .sheet(for: ProfileDestination.self) { _ in
        ProfileView()
      }
      #if os(macOS)
      // macOS has no API to present full screen, fallback to sheet
      .sheet(for: AccountDestination.self) { _ in
        AccountView()
      }
      #else
      .fullScreenCover(for: AccountDestination.self) { _ in
        AccountView()
      }
      #endif
    }
  }
}

struct SettingsView: View {
  @Environment(\.navigator) private var navigator
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Button("Push Notifications") {
          navigator?.push(PushNotificationsSettingsDestination())
        }
        Button("Pop to root") {
          navigator?.popToRoot()
        }
      }
      .buttonStyle(.glass)
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationTitle("Settings")
      .sheet(for: PushNotificationsSettingsDestination.self) { _ in
        PushNotificationsSettings()
      }
      .debugView()
    }
  }
}

struct PushNotificationsSettings: View {
  @Environment(\.navigator) private var navigator
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Button("Pop to Settings") {
          navigator?.popTo(SettingsDestination.self)
        }
        Button("Pop to root") {
          navigator?.popToRoot()
        }
      }
      .buttonStyle(.glass)
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationTitle("Notifications")
      .debugView()
    }
  }
}

struct ProfileView: View {
  @Environment(\.navigator) private var navigator
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("Profile content")
          .foregroundStyle(.secondary)
        Button("Pop") {
          navigator?.pop()
        }
      }
      .buttonStyle(.glass)
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationTitle("Profile")
      .debugView()
    }
  }
}
struct AccountView: View {
  @Environment(\.navigator) private var navigator
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("Full-screen cover")
          .foregroundStyle(.secondary)
        Button("Dismiss") {
          navigator?.pop()
        }
      }
      .buttonStyle(.glass)
      .padding(.horizontal)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationTitle("Account")
      .debugView()
    }
  }
}

private struct PresentationDebugView: View {
  @AppStorage("presentations") private var path: Data?

  var body: some View {
    DebugView(path: $path)
  }
}

private extension View {
  func debugView() -> some View {
    safeAreaBar(edge: .bottom) {
      PresentationDebugView()
    }
  }
}
