import SwiftUI

extension EnvironmentValues {
  /// The navigation proxy for the nearest ``ManagedNavigationStack`` or
  /// ``ManagedPresentation``.
  ///
  /// Use this environment value to push and pop destinations from child views:
  ///
  /// ```swift
  /// @Environment(\.navigator) private var navigator
  /// ```
  @Entry public internal(set) var navigator: Binding<NavigationManager>?
}

extension Binding where Value == NavigationManager {
  /// The current navigation stack as an array of destinations.
  public var path: [any NavigationDestination] { wrappedValue.path }
  
  /// Pushes a single destination onto the navigation stack.
  ///
  /// - Parameter destination: The destination to push.
  public func push(_ destination: some NavigationDestination) {
    wrappedValue.push(destination)
  }
  
  /// Pushes multiple destinations onto the navigation stack in order.
  ///
  /// - Parameter destinations: An array of destinations to push.
  public func push(_ destinations: [any NavigationDestination]) {
    wrappedValue.push(destinations)
  }
  
  /// Replaces the destination at the given index with a new destination.
  ///
  /// - Parameters:
  ///   - destination: The new destination to insert.
  ///   - index: The zero-based index of the destination to replace.
  /// - Returns: `true` if the replacement succeeded, `false` if the index is out of bounds.
  @discardableResult public func replace(_ destination: any NavigationDestination, at index: Int) -> Bool {
    wrappedValue.replace(destination, at: index)
  }
  
  /// Pops back to the last occurrence of the given destination type.
  ///
  /// - Parameter destinationType: The type of destination to pop back to.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popTo<Destination: NavigationDestination>(_ destinationType: Destination.Type) -> Bool {
    wrappedValue.popTo(destinationType)
  }

  /// Pops back to the first destination that satisfies the given predicate.
  ///
  /// - Parameter predicate: A closure receiving a ``NavigationManager/NavigationScanContext``.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popTo(where predicate: (NavigationManager.NavigationScanContext) -> Bool) -> Bool {
    wrappedValue.popTo(where: predicate)
  }
  
  /// Pops back to the first occurrence of the given destination type.
  ///
  /// - Parameter destinationType: The type of destination to pop back to.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popToFirst<Destination: NavigationDestination>(_ destinationType: Destination.Type) -> Bool {
    wrappedValue.popToFirst(destinationType)
  }

  /// Pops back to the destination at the given index.
  ///
  /// - Parameter index: The zero-based index to pop back to.
  /// - Returns: `true` if the stack was modified, `false` if the index is out of bounds.
  @discardableResult public func popTo(at index: Int) -> Bool {
    wrappedValue.popTo(at: index)
  }

  /// Pops back to the destination at the given index if it matches the expected type.
  ///
  /// - Parameters:
  ///   - destinationType: The expected type at the given index.
  ///   - index: The zero-based index to pop back to.
  /// - Returns: `true` if the type matches and the stack was trimmed, `false` otherwise.
  @discardableResult public func popTo<Destination: NavigationDestination>(_ destinationType: Destination.Type, at index: Int) -> Bool {
    wrappedValue.popTo(destinationType, at: index)
  }

  /// Pops the last destination from the stack.
  ///
  /// - Returns: `true` if a destination was removed, `false` if the stack was empty.
  @discardableResult public func pop() -> Bool {
    wrappedValue.pop()
  }
  
  /// Pops all destinations, returning to the root view.
  ///
  /// - Returns: `true` if one or more destinations were removed, `false` otherwise.
  @discardableResult public func popToRoot() -> Bool {
    wrappedValue.popToRoot()
  }
  
  /// A codable representation of the navigation path, or `nil` if any
  /// destination does not conform to `Codable`.
  public var codable: NavigationManager.CodableRepresentation? {
    wrappedValue.codable
  }

  /// Replaces the entire navigation stack with the given destinations.
  ///
  /// - Parameter destinations: The new destinations to set as the path.
  public func replace(_ destinations: [any NavigationDestination]) {
    wrappedValue = .init(destinations)
  }

  /// Replaces the entire navigation stack from a previously saved codable representation.
  ///
  /// - Parameter codable: The codable representation to restore from.
  public func replace(_ codable: NavigationManager.CodableRepresentation) {
    wrappedValue = .init(codable)
  }
}
