import SwiftUI
import ManagedNavigation

struct PresentationExample: View {
  @State private var manager = NavigationManager()
  
  var body: some View {
    ManagedPresentation(manager: $manager) {
      NavigationStack {
        HomeView(title: "Presentation", showClose: false)
      }
      .sheet(for: SettingsDestination.self) { _ in
        NavigationStack {
          SettingsView()
        }
      }
      .sheet(for: ProfileDestination.self) { _ in
        NavigationStack {
          ProfileView()
        }
      }
      .sheet(for: HomeViewDestination.self) { _ in
        NavigationStack {
          HomeView(title: "Presentation", showClose: true)
        }
      }
      #if os(macOS)
      // macOS has no API to present full screen, fallback to sheet
      .sheet(for: AccountDestination.self) { _ in
        NavigationStack {
          AccountView()
        }
      }
      #else
      .fullScreenCover(for: AccountDestination.self) { _ in
        NavigationStack { 
          AccountView()
        }
      }
      #endif
    }
  }
}
