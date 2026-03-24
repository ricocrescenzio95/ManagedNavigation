import SwiftUI

/// A navigation stack that is driven by a ``NavigationManager``.
///
/// `ManagedNavigationStack` wraps SwiftUI's `NavigationStack` and connects it
/// to a ``NavigationManager`` binding, giving you full programmatic control
/// over the navigation path.
///
/// ```swift
/// @State var manager = NavigationManager()
///
/// ManagedNavigationStack(manager: $manager) {
///     VStack {
///         Button("Go Home") {
///             manager.push(HomeDestination())
///         }
///     }
///     .navigationDestination(for: HomeDestination.self) { _ in
///         HomeView()
///     }
/// }
/// ```
///
/// Child views can access the navigation stack through the ``SwiftUICore/EnvironmentValues/navigator``
/// environment value, which provides a ``Navigator``.
public struct ManagedNavigationStack<Root: View>: View {
  @Binding var manager: NavigationManager
  
  // Use StateObject to ensure single instance when creating in init
  @StateObject private var navigator: Navigator

  var root: Root

  /// Creates a managed navigation stack.
  ///
  /// - Parameters:
  ///   - manager: A binding to the ``NavigationManager`` that controls this stack.
  ///   - root: A view builder that produces the root view of the navigation stack.
  public init(
    manager: Binding<NavigationManager>,
    @ViewBuilder root: () -> Root
  ) {
    _manager = manager
    _navigator = StateObject(wrappedValue: Navigator(manager))
    self.root = root()
  }

  public var body: some View {
    NavigationStack(path: $manager._path) {
      root
    }
    .environment(\.navigator, navigator)
    .onChange(of: manager.path.map { AnyHashable($0) }, initial: true) {
      navigator.syncPath()
    }
  }
}
