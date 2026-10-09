import SwiftUI
import ManagedNavigation

struct HomeViewDestination: NavigationDestination, Codable {}
struct SettingsDestination: NavigationDestination, Codable {}
struct PushNotificationsSettingsDestination: NavigationDestination, Codable {
  var id: String
}
struct ProfileDestination: NavigationDestination, Codable {}
struct AccountDestination: NavigationDestination, Codable {}
struct NonRegisteredDestination: NavigationDestination {}

struct NestedLevel1Destination: NavigationDestination {}
struct NestedLevel2Destination: NavigationDestination {}
struct NestedLevel3Destination: NavigationDestination {}
struct NestedLevel4Destination: NavigationDestination {}

@main
struct TestApp: App {
  var body: some Scene {
    WindowGroup {
      TabView {
        NavigationStackExample()
          .tabItem {
            Label("Navigation Stack", systemImage: "square.stack.3d.down.forward")
          }
        PresentationExample()
          .tabItem {
            Label("Presentation", systemImage: "rectangle.stack")
          }
      }
    }
  }
}
