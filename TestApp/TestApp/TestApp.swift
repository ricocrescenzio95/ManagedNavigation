import SwiftUI

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
