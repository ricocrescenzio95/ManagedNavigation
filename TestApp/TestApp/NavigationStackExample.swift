import SwiftUI
import ManagedNavigation

struct DetailsDestination: NavigationDestination, Codable {
  var id: String
}

struct NavigationStackExample: View {
  @State var manager = NavigationManager()
  
  var body: some View {
    ManagedNavigationStack(manager: $manager) {
      HomeView(title: "Navigation Stack")
      .navigationDestination(for: SettingsDestination.self) { _ in
        SettingsView()
      }
      .navigationDestination(for: ProfileDestination.self) { _ in
        ProfileView()
      }
      .navigationDestination(for: HomeViewDestination.self) { _ in
        HomeView(title: "Navigation Stack")
      }
      .navigationDestination(for: AccountDestination.self) { _ in
        AccountView()
      }
    }
  }
}
