import SwiftUI
import ManagedNavigation

struct DetailsDestination: NavigationDestination, Codable {
  var id: String
}

struct HomeDestination: NavigationDestination, Codable {}

struct NavigationStackExample: View {
  @AppStorage("path") var path: Data?
  @State var manager = NavigationManager()
  
  var body: some View {
    ManagedNavigationStack(manager: $manager) {
      VStack(spacing: 16) {
        Button("Push Home") {
          manager.push(HomeDestination())
        }
        Button("Push Details") {
          manager.push(DetailsDestination(id: "hello"))
        }
        Button("Push Multiple") {
          manager.push([
            HomeDestination(),
            DetailsDestination(id: "deep"),
            HomeDestination()
          ])
        }
      }
      .navigationTitle("Root")
      .navigationDestination(for: HomeDestination.self) { _ in
        HomeView()
      }
      .navigationDestination(for: DetailsDestination.self) {
        DetailsView(id: $0.id)
      }
      .debugView()
    }
  }
}

struct IndexedDestination: Identifiable {
  var id: Int
  var destination: any Hashable
}

struct HomeView: View {
  @Environment(\.navigator) private var navigator
  
  var body: some View {
    VStack(spacing: 16) {
      Button("Push Details") {
        navigator?.push(DetailsDestination(id: "hello"))
      }
      Button("Push Home again") {
        navigator?.push(HomeDestination())
      }
    }
    .navigationTitle("Home")
    #if !os(macOS) && !os(tvOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .debugView()
  }
}

struct DetailsView: View {
  @Environment(\.navigator) private var navigator
  var id: String
  
  var body: some View {
    VStack(spacing: 16) {
      Text("ID: \(id)")
        .font(.caption)
        .foregroundStyle(.secondary)
      
      Section {
        Button("Push Home") {
          navigator?.push(HomeDestination())
        }
        Button("Push Multiple") {
          navigator?.push([
            HomeDestination(),
            DetailsDestination(id: "batch"),
            HomeDestination()
          ])
        }
      }
      
      Divider().padding(.horizontal)
      
      Section {
        Button("Pop") {
          navigator?.pop()
        }
        Button("Pop to Root") {
          navigator?.popToRoot()
        }
        Button("Pop to last Home") {
          navigator?.popTo(HomeDestination.self)
        }
        Button("Pop to first Home") {
          navigator?.popToFirst(HomeDestination.self)
        }
        Button("Pop to first Details (predicate)") {
          navigator?.popTo(where: { context in
            context.destination is DetailsDestination
          })
        }
      }
    }
    .navigationTitle("Details")
    #if !os(macOS) && !os(tvOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .debugView()
  }
}

#Preview {
  NavigationStackExample()
}

private struct NavigationStackDebugView: View {
  @AppStorage("navigationStack") private var path: Data?

  var body: some View {
    DebugView(path: $path)
  }
}

private extension View {
  func debugView() -> some View {
    frame(maxHeight: .infinity)
      .safeAreaBar(edge: .bottom) {
        NavigationStackDebugView()
      }
  }
}
