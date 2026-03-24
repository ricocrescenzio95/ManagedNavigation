import SwiftUI
import Observation

/// A stable reference wrapper around a ``NavigationManager`` binding.
///
/// `Navigator` is an `@Observable` reference type that holds a
/// `Binding<NavigationManager>` internally.  Because it is a class its
/// identity stays the same across SwiftUI view updates, which prevents
/// unnecessary view invalidation when passed through the environment.
///
/// The ``path`` property **is** tracked by Observation, so views that
/// read it (e.g. breadcrumbs, badges) will update when the navigation
/// stack changes.  Views that only *call* mutation methods like
/// ``push(_:)-(NavigationDestination)`` or ``pop()`` without reading ``path`` in their
/// `body` will **not** be invalidated.
///
/// You don't create a `Navigator` yourself.  ``ManagedNavigationStack``
/// and ``ManagedPresentation`` inject one into the environment
/// automatically.  Access it from any child view with:
///
/// ```swift
/// @Environment(\.navigator) private var navigator
///
/// Button("Go") {
///     navigator?.push(DetailsDestination(id: "abc"))
/// }
/// ```
@Observable
public class Navigator: ObservableObject {
  // MARK: - Internal storage

  /// The binding that connects back to the owning @State NavigationManager.
  /// Ignored by Observation so that reading/writing it does not trigger
  /// view invalidation on its own.
  @ObservationIgnored
  var binding: Binding<NavigationManager>

  /// The current navigation path.  This **is** tracked by Observation,
  /// so any view that reads it in its `body` will update when it changes.
  public internal(set) var path: [any NavigationDestination] = []

  // MARK: - Init

  init(_ binding: Binding<NavigationManager>) {
    self.binding = binding
    self.path = binding.wrappedValue.path
  }

  /// Syncs the observable ``path`` with the current manager state.
  /// Called by the owning container view when the manager's path changes.
  func syncPath() {
    let managerPath = binding.wrappedValue.path
    // Only assign if actually different to avoid unnecessary observation notifications.
    if !pathEquals(managerPath) {
      path = managerPath
    }
  }

  private func pathEquals(_ other: [any NavigationDestination]) -> Bool {
    guard path.count == other.count else { return false }
    return zip(path, other).allSatisfy {
      let isEqual = $0.equalsDestination($1)
      return isEqual
    }
  }

  // MARK: - Push

  /// Pushes a single destination onto the navigation stack.
  ///
  /// - Parameter destination: The destination to push.
  public func push(_ destination: some NavigationDestination) {
    binding.wrappedValue.push(destination)
  }

  /// Pushes multiple destinations onto the navigation stack in order.
  ///
  /// - Parameter destinations: An array of destinations to push.
  public func push(_ destinations: [any NavigationDestination]) {
    binding.wrappedValue.push(destinations)
  }

  // MARK: - Replace

  /// Replaces the destination at the given index with a new destination.
  ///
  /// - Parameters:
  ///   - destination: The new destination to insert.
  ///   - index: The zero-based index of the destination to replace.
  /// - Returns: `true` if the replacement succeeded, `false` if the index is out of bounds.
  @discardableResult public func replace(_ destination: any NavigationDestination, at index: Int) -> Bool {
    binding.wrappedValue.replace(destination, at: index)
  }

  /// Replaces the entire navigation stack with the given destinations.
  ///
  /// - Parameter destinations: The new destinations to set as the path.
  public func replace(_ destinations: [any NavigationDestination]) {
    binding.wrappedValue = .init(destinations)
  }

  /// Replaces the entire navigation stack from a previously saved codable representation.
  ///
  /// - Parameter codable: The codable representation to restore from.
  public func replace(_ codable: NavigationManager.CodableRepresentation) {
    binding.wrappedValue = .init(codable)
  }

  // MARK: - Pop

  /// Pops back to the last occurrence of the given destination type.
  ///
  /// - Parameter destinationType: The type of destination to pop back to.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popTo<Destination: NavigationDestination>(_ destinationType: Destination.Type) -> Bool {
    binding.wrappedValue.popTo(destinationType)
  }

  /// Pops back to the first destination that satisfies the given predicate.
  ///
  /// - Parameter predicate: A closure receiving a ``NavigationManager/NavigationScanContext``.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popTo(where predicate: (NavigationManager.NavigationScanContext) -> Bool) -> Bool {
    binding.wrappedValue.popTo(where: predicate)
  }

  /// Pops back to the first occurrence of the given destination type.
  ///
  /// - Parameter destinationType: The type of destination to pop back to.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popToFirst<Destination: NavigationDestination>(_ destinationType: Destination.Type) -> Bool {
    binding.wrappedValue.popToFirst(destinationType)
  }

  /// Pops back to the destination at the given index.
  ///
  /// - Parameter index: The zero-based index to pop back to.
  /// - Returns: `true` if the stack was modified, `false` if the index is out of bounds.
  @discardableResult public func popTo(at index: Int) -> Bool {
    binding.wrappedValue.popTo(at: index)
  }

  /// Pops back to the destination at the given index if it matches the expected type.
  ///
  /// - Parameters:
  ///   - destinationType: The expected type at the given index.
  ///   - index: The zero-based index to pop back to.
  /// - Returns: `true` if the type matches and the stack was trimmed, `false` otherwise.
  @discardableResult public func popTo<Destination: NavigationDestination>(_ destinationType: Destination.Type, at index: Int) -> Bool {
    binding.wrappedValue.popTo(destinationType, at: index)
  }

  /// Pops the last destination from the stack.
  ///
  /// - Returns: `true` if a destination was removed, `false` if the stack was empty.
  @discardableResult public func pop() -> Bool {
    binding.wrappedValue.pop()
  }

  /// Pops all destinations, returning to the root view.
  ///
  /// - Returns: `true` if one or more destinations were removed, `false` otherwise.
  @discardableResult public func popToRoot() -> Bool {
    binding.wrappedValue.popToRoot()
  }

  // MARK: - Codable

  /// A codable representation of the navigation path, or `nil` if any
  /// destination does not conform to `Codable`.
  public var codable: NavigationManager.CodableRepresentation? {
    binding.wrappedValue.codable
  }
}

extension EnvironmentValues {
  /// The navigator for the nearest ``ManagedNavigationStack`` or
  /// ``ManagedPresentation``.
  ///
  /// Use this environment value to push and pop destinations from child views:
  ///
  /// ```swift
  /// @Environment(\.navigator) private var navigator
  /// ```
  @Entry public internal(set) var navigator: Navigator?
}
