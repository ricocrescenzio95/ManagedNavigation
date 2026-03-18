import SwiftUI

@main
struct TestApp: App {
  var body: some Scene {
    WindowGroup {
      TabView {
        NavigationStackExample()
          .tabItem {
            Label("Navigation", systemImage: "square.stack.3d.up")
          }
        PresentationExample()
          .tabItem {
            Label("Presentation", systemImage: "rectangle.stack")
          }
      }
    }
  }
}
