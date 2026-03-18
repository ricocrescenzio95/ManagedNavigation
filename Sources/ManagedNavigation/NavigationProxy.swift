import SwiftUI

/// A lightweight proxy for navigating within a ``ManagedNavigationStack`` or
/// ``ManagedPresentation``.
///
/// `NavigationProxy` is available to any view inside a ``ManagedNavigationStack``
/// or ``ManagedPresentation`` via the ``SwiftUICore/EnvironmentValues/navigator``
/// environment value. It forwards all operations to the underlying
/// ``NavigationManager``.
///
/// ```swift
/// struct MyView: View {
///     @Environment(\.navigator) private var navigator
///
///     var body: some View {
///         Button("Go to Details") {
///             navigator?.push(DetailsDestination(id: "abc"))
///         }
///     }
/// }
/// ```
public struct NavigationProxy {
  @Binding var navigationManager: NavigationManager
  
  /// The current navigation stack as an array of destinations.
  public var path: [any NavigationDestination] { navigationManager.path }
  
  /// Pushes a single destination onto the navigation stack.
  ///
  /// - Parameter destination: The destination to push.
  public func push(_ destination: some NavigationDestination) {
    navigationManager.push(destination)
  }
  
  /// Pushes multiple destinations onto the navigation stack in order.
  ///
  /// - Parameter destinations: An array of destinations to push.
  public func push(_ destinations: [any NavigationDestination]) {
    navigationManager.push(destinations)
  }
  
  /// Pops back to the last occurrence of the given destination type.
  ///
  /// - Parameter destinationType: The type of destination to pop back to.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popTo<Destination: NavigationDestination>(_ destinationType: Destination.Type) -> Bool {
    navigationManager.popTo(destinationType)
  }

  /// Pops back to the first destination that satisfies the given predicate.
  ///
  /// - Parameter predicate: A closure receiving a ``NavigationManager/NavigationScanContext``.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popTo(where predicate: (NavigationManager.NavigationScanContext) -> Bool) -> Bool {
    navigationManager.popTo(where: predicate)
  }
  
  /// Pops back to the first occurrence of the given destination type.
  ///
  /// - Parameter destinationType: The type of destination to pop back to.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popToFirst<Destination: NavigationDestination>(_ destinationType: Destination.Type) -> Bool {
    navigationManager.popToFirst(destinationType)
  }

  /// Pops back to the destination at the given index.
  ///
  /// - Parameter index: The zero-based index to pop back to.
  /// - Returns: `true` if the stack was modified, `false` if the index is out of bounds.
  @discardableResult public func popTo(at index: Int) -> Bool {
    navigationManager.popTo(at: index)
  }

  /// Pops back to the destination at the given index if it matches the expected type.
  ///
  /// - Parameters:
  ///   - destinationType: The expected type at the given index.
  ///   - index: The zero-based index to pop back to.
  /// - Returns: `true` if the type matches and the stack was trimmed, `false` otherwise.
  @discardableResult public func popTo<Destination: NavigationDestination>(_ destinationType: Destination.Type, at index: Int) -> Bool {
    navigationManager.popTo(destinationType, at: index)
  }

  /// Pops the last destination from the stack.
  ///
  /// - Returns: `true` if a destination was removed, `false` if the stack was empty.
  @discardableResult public func pop() -> Bool {
    navigationManager.pop()
  }
  
  /// Pops all destinations, returning to the root view.
  ///
  /// - Returns: `true` if one or more destinations were removed, `false` otherwise.
  @discardableResult public func popToRoot() -> Bool {
    navigationManager.popToRoot()
  }
  
  public var codable: NavigationManager.CodableRepresentation? {
    navigationManager.codable
  }
  
  public func replace(_ destinations: [any NavigationDestination]) {
    navigationManager = .init(destinations)
  }
  
  public func replace(_ codable: NavigationManager.CodableRepresentation) {
    navigationManager = .init(codable)
  }
}

extension EnvironmentValues {
  /// The navigation proxy for the nearest ``ManagedNavigationStack`` or
  /// ``ManagedPresentation``.
  ///
  /// Use this environment value to push and pop destinations from child views:
  ///
  /// ```swift
  /// @Environment(\.navigator) private var navigator
  /// ```
  @Entry public internal(set) var navigator: NavigationProxy?
}
