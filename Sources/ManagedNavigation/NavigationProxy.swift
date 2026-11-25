import SwiftUI
import Observation

/// An observable object that provides programmatic navigation from any child view.
///
/// You don't create a `Navigator` yourself. ``ManagedNavigationStack``
/// and ``ManagedPresentation`` inject one into the environment
/// automatically. Access it with:
///
/// ```swift
/// @Environment(\.navigator) private var navigator
///
/// Button("Go") {
///     navigator?.push(DetailsDestination(id: "abc"))
/// }
/// ```
@Observable
public class Navigator: ObservableObject, Identifiable {
  // MARK: - Internal storage

  let binding: Binding<NavigationManager>
  
  public var id: NavigationManager.ID { binding.wrappedValue.id }

  /// The current navigation path.
  public internal(set) var path: [any NavigationDestination] = []

  // MARK: - Init

  init(_ binding: Binding<NavigationManager>) {
    self.binding = binding
    self.path = binding.wrappedValue.path
  }

  /// Syncs ``path`` with the current manager state.
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
    binding.wrappedValue = .init(destinations, id: id)
  }

  /// Replaces the entire navigation stack from a previously saved codable representation.
  ///
  /// - Parameter codable: The codable representation to restore from.
  public func replace(_ codable: NavigationManager.CodableRepresentation) {
    binding.wrappedValue = .init(codable, id: id)
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

// MARK: - Utilities

extension Navigator {

  // MARK: Query

  /// A Boolean value indicating whether the stack contains no destinations.
  ///
  /// Forwards to ``NavigationManager/isEmpty``.
  public var isEmpty: Bool { binding.wrappedValue.isEmpty }

  /// The number of destinations currently on the stack.
  ///
  /// Forwards to ``NavigationManager/count``.
  public var count: Int { binding.wrappedValue.count }

  /// The destination at the top of the stack, or `nil` if the stack is empty.
  ///
  /// Forwards to ``NavigationManager/top``.
  public var top: (any NavigationDestination)? { binding.wrappedValue.top }

  /// Returns a Boolean value indicating whether the stack contains a destination
  /// equal to the given one.
  ///
  /// Equality takes both the type and the values of the destination into account.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// navigator.contains(DetailsDestination(id: "abc")) // true
  /// navigator.contains(DetailsDestination(id: "xyz")) // false
  /// ```
  ///
  /// - Parameter destination: The destination to look for.
  /// - Returns: `true` if an equal destination is on the stack, `false` otherwise.
  public func contains(_ destination: some NavigationDestination) -> Bool {
    binding.wrappedValue.contains(destination)
  }

  /// Returns a Boolean value indicating whether the stack contains at least one
  /// destination of the given type.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// navigator.contains(DetailsDestination.self) // true
  /// navigator.contains(SettingsDestination.self) // false
  /// ```
  ///
  /// - Parameter type: The type of destination to look for.
  /// - Returns: `true` if a destination of that type is on the stack, `false` otherwise.
  public func contains<Destination: NavigationDestination>(_ type: Destination.Type) -> Bool {
    binding.wrappedValue.contains(type)
  }

  /// Returns the index of the **last** destination of the given type.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Home, Details]
  /// navigator.lastIndex(of: HomeDestination.self) // 2
  /// ```
  ///
  /// - Parameter type: The type of destination to look for.
  /// - Returns: The index in ``NavigationManager/path`` of the last matching
  ///   destination, or `nil` if none was found.
  public func lastIndex<Destination: NavigationDestination>(of type: Destination.Type) -> Int? {
    binding.wrappedValue.lastIndex(of: type)
  }

  /// Returns the **last** destination of the given type, already cast to that type.
  ///
  /// Useful to read the parameters of a destination that is already on the stack.
  ///
  /// ```swift
  /// if let details = navigator.last(of: DetailsDestination.self) {
  ///     print(details.id)
  /// }
  /// ```
  ///
  /// - Parameter type: The type of destination to look for.
  /// - Returns: The last matching destination, or `nil` if none was found.
  public func last<Destination: NavigationDestination>(of type: Destination.Type) -> Destination? {
    binding.wrappedValue.last(of: type)
  }

  // MARK: Conditional push

  /// Pushes a destination only if an **equal** destination is not already on the stack.
  ///
  /// Equality takes both the type and the values of the destination into account.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// navigator.pushIfNotPresent(DetailsDestination(id: "abc")) // false, nothing happens
  /// navigator.pushIfNotPresent(DetailsDestination(id: "xyz")) // true, pushed
  /// ```
  ///
  /// - Parameter destination: The destination to push.
  /// - Returns: `true` if the destination was pushed, `false` if an equal one
  ///   was already on the stack.
  @discardableResult public func pushIfNotPresent(_ destination: some NavigationDestination) -> Bool {
    binding.wrappedValue.pushIfNotPresent(destination)
  }

  /// Pushes, in order, only the destinations that are not already on the stack.
  ///
  /// Each destination is checked right before it is pushed, so duplicates
  /// inside `destinations` itself are also skipped.
  ///
  /// ```swift
  /// // Stack: [Home]
  /// navigator.pushIfNotPresent([
  ///     HomeDestination(),                // skipped
  ///     DetailsDestination(id: "abc"),    // pushed
  ///     DetailsDestination(id: "abc")     // skipped
  /// ])
  /// // Stack: [Home, Details(id: "abc")]
  /// ```
  ///
  /// - Parameter destinations: An array of destinations to push, in order.
  /// - Returns: `true` if at least one destination was pushed, `false` otherwise.
  @discardableResult public func pushIfNotPresent(_ destinations: [any NavigationDestination]) -> Bool {
    binding.wrappedValue.pushIfNotPresent(destinations)
  }

  /// Pushes a destination only if no destination of the **same type** is already
  /// on the stack, regardless of its values.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// navigator.pushIfTypeNotPresent(DetailsDestination(id: "xyz")) // false, a Details is already there
  /// navigator.pushIfTypeNotPresent(SettingsDestination())         // true, pushed
  /// ```
  ///
  /// - Parameter destination: The destination to push.
  /// - Returns: `true` if the destination was pushed, `false` if one of the same
  ///   type was already on the stack.
  @discardableResult public func pushIfTypeNotPresent<Destination: NavigationDestination>(_ destination: Destination) -> Bool {
    binding.wrappedValue.pushIfTypeNotPresent(destination)
  }

  /// Pushes a destination only if it is not equal to the destination currently
  /// on top of the stack.
  ///
  /// Useful to avoid duplicate pushes caused by double taps.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// navigator.pushIfNotOnTop(DetailsDestination(id: "abc")) // false
  /// navigator.pushIfNotOnTop(HomeDestination())             // true
  /// ```
  ///
  /// - Parameter destination: The destination to push.
  /// - Returns: `true` if the destination was pushed, `false` if the top of the
  ///   stack is equal to it.
  @discardableResult public func pushIfNotOnTop(_ destination: some NavigationDestination) -> Bool {
    binding.wrappedValue.pushIfNotOnTop(destination)
  }

  /// Pushes a destination only if the given condition, evaluated against the
  /// current state of the manager, returns `true`.
  ///
  /// ```swift
  /// navigator.push(DetailsDestination(id: "abc"), if: { $0.count < 5 })
  /// ```
  ///
  /// - Parameters:
  ///   - destination: The destination to push.
  ///   - condition: A closure that receives the current manager and returns
  ///     `true` if the destination should be pushed.
  /// - Returns: `true` if the destination was pushed, `false` otherwise.
  @discardableResult public func push(
    _ destination: some NavigationDestination,
    if condition: (NavigationManager) -> Bool
  ) -> Bool {
    binding.wrappedValue.push(destination, if: condition)
  }

  // MARK: Pop

  /// Pops the given number of destinations from the top of the stack.
  ///
  /// If `count` is greater than the number of destinations on the stack,
  /// the stack is emptied.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings]
  /// navigator.pop(2)
  /// // Stack: [Home]
  /// ```
  ///
  /// - Parameter count: The number of destinations to remove.
  /// - Returns: `true` if at least one destination was removed, `false` if
  ///   `count` is not positive or the stack was already empty.
  @discardableResult public func pop(_ count: Int) -> Bool {
    binding.wrappedValue.pop(count)
  }

  /// Pops destinations from the top of the stack for as long as the predicate
  /// returns `true`.
  ///
  /// The stack is scanned from the top, and popping stops at the first
  /// destination for which `predicate` returns `false`.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings, Settings]
  /// navigator.pop(while: { $0 is SettingsDestination })
  /// // Stack: [Home, Details]
  /// ```
  ///
  /// - Parameter predicate: A closure that receives a destination and returns
  ///   `true` if it should be popped.
  /// - Returns: `true` if at least one destination was removed, `false` otherwise.
  @discardableResult public func pop(while predicate: (any NavigationDestination) -> Bool) -> Bool {
    binding.wrappedValue.pop(while: predicate)
  }

  /// Pops back to the **last** destination that satisfies the given predicate.
  ///
  /// Unlike ``NavigationManager/popTo(where:)``, which scans from the bottom of
  /// the stack, this method scans from the top and stops at the last match.
  ///
  /// ```swift
  /// navigator.popToLast(where: { context in
  ///     context.destination is HomeDestination
  /// })
  /// ```
  ///
  /// - Parameter predicate: A closure that receives a
  ///   ``NavigationManager/NavigationScanContext`` and returns `true` for the
  ///   destination where the stack should stop.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public func popToLast(where predicate: (NavigationManager.NavigationScanContext) -> Bool) -> Bool {
    binding.wrappedValue.popToLast(where: predicate)
  }

  // MARK: Combined push / pop

  /// Pops back to an **equal** destination if it is already on the stack,
  /// otherwise pushes the given destination.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc"), Settings]
  /// navigator.pushOrPopTo(DetailsDestination(id: "abc")) // false
  /// // Stack: [Home, Details(id: "abc")]
  ///
  /// navigator.pushOrPopTo(ProfileDestination()) // true
  /// // Stack: [Home, Details(id: "abc"), Profile]
  /// ```
  ///
  /// - Parameter destination: The destination to pop back to or push.
  /// - Returns: `true` if the destination was pushed, `false` if the stack
  ///   was popped back to an existing one.
  @discardableResult public func pushOrPopTo(_ destination: some NavigationDestination) -> Bool {
    binding.wrappedValue.pushOrPopTo(destination)
  }

  /// Pops back to the last destination of the **same type** if there is one,
  /// otherwise pushes the given destination.
  ///
  /// Values are ignored: an existing destination of the same type is reused
  /// even if its values differ from those of `destination`.
  ///
  /// - Parameter destination: The destination to push if its type is not on the stack.
  /// - Returns: `true` if the destination was pushed, `false` if the stack
  ///   was popped back to an existing one.
  @discardableResult public func pushOrPopToType<Destination: NavigationDestination>(_ destination: Destination) -> Bool {
    binding.wrappedValue.pushOrPopToType(destination)
  }

  /// Pops all destinations and then pushes the given one, so that it becomes
  /// the only destination on the stack.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings]
  /// navigator.popToRoot(thenPush: ProfileDestination())
  /// // Stack: [Profile]
  /// ```
  ///
  /// - Parameter destination: The destination to push after clearing the stack.
  public func popToRoot(thenPush destination: some NavigationDestination) {
    binding.wrappedValue.popToRoot(thenPush: destination)
  }

  // MARK: Stack modification

  /// Replaces the entire stack with the given destinations.
  ///
  /// The `id` and the transaction of the manager are preserved.
  ///
  /// ```swift
  /// navigator.setPath([HomeDestination(), DetailsDestination(id: "abc")])
  /// ```
  ///
  /// - Parameter destinations: The new stack, ordered from bottom to top.
  public func setPath(_ destinations: [any NavigationDestination]) {
    binding.wrappedValue.setPath(destinations)
  }

  /// Replaces the destination at the top of the stack with a new one.
  ///
  /// ```swift
  /// // Stack: [Home, Details]
  /// navigator.replaceLast(with: SettingsDestination())
  /// // Stack: [Home, Settings]
  /// ```
  ///
  /// - Parameter destination: The new destination.
  /// - Returns: `true` if the destination was replaced, `false` if the stack was empty.
  @discardableResult public func replaceLast(with destination: any NavigationDestination) -> Bool {
    binding.wrappedValue.replaceLast(with: destination)
  }

  /// Inserts a destination at the given index, shifting the following
  /// destinations up.
  ///
  /// ```swift
  /// // Stack: [Home, Settings]
  /// navigator.insert(DetailsDestination(id: "abc"), at: 1)
  /// // Stack: [Home, Details(id: "abc"), Settings]
  /// ```
  ///
  /// - Parameters:
  ///   - destination: The destination to insert.
  ///   - index: The zero-based index at which to insert. Must be between `0`
  ///     and ``count``, inclusive.
  /// - Returns: `true` if the destination was inserted, `false` if the index
  ///   is out of bounds.
  @discardableResult public func insert(_ destination: any NavigationDestination, at index: Int) -> Bool {
    binding.wrappedValue.insert(destination, at: index)
  }

  /// Removes the destination at the given index, keeping the ones above it.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings]
  /// navigator.remove(at: 1)
  /// // Stack: [Home, Settings]
  /// ```
  ///
  /// - Parameter index: The zero-based index in ``NavigationManager/path`` of
  ///   the destination to remove.
  /// - Returns: `true` if the destination was removed, `false` if the index
  ///   is out of bounds.
  @discardableResult public func remove(at index: Int) -> Bool {
    binding.wrappedValue.remove(at: index)
  }

  /// Removes all destinations of the given type from the stack.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings, Details]
  /// navigator.removeAll(of: DetailsDestination.self)
  /// // Stack: [Home, Settings]
  /// ```
  ///
  /// - Parameter type: The type of destinations to remove.
  /// - Returns: `true` if at least one destination was removed, `false` otherwise.
  @discardableResult public func removeAll<Destination: NavigationDestination>(of type: Destination.Type) -> Bool {
    binding.wrappedValue.removeAll(of: type)
  }

  /// Removes all destinations equal to the given one from the stack.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc"), Details(id: "xyz")]
  /// navigator.removeAll(DetailsDestination(id: "abc"))
  /// // Stack: [Home, Details(id: "xyz")]
  /// ```
  ///
  /// - Parameter destination: The destination to remove.
  /// - Returns: `true` if at least one destination was removed, `false` otherwise.
  @discardableResult public func removeAll(_ destination: some NavigationDestination) -> Bool {
    binding.wrappedValue.removeAll(destination)
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
  
  /// All navigators for the nearest ``ManagedNavigationStack`` or
  /// ``ManagedPresentation``.
  ///
  /// Use this environment value to push and pop destinations from child views:
  ///
  /// ```swift
  /// @Environment(\.navigators) private var navigators
  /// ```
  @Entry public internal(set) var navigators = NavigatorsContainer()
}

public struct NavigatorsContainer {
  /// All ancestor navigators, ordered from the outermost to the nearest one.
  public internal(set) var navigators = [Navigator]()

  /// The navigator with the given manager id, or `nil` if none is found.
  /// If several share the same id, the nearest (innermost) one wins.
  public subscript(_ id: Navigator.ID) -> Navigator? {
    navigators.last(where: { $0.id == id })
  }

  /// The outermost navigator.
  public var first: Navigator? { navigators.first }

  /// The nearest navigator.
  public var last: Navigator? { navigators.last }

  /// The navigator `level` levels above the nearest one (`0` is the nearest).
  public func ancestor(_ level: Int) -> Navigator? {
    let index = navigators.count - 1 - level
    return navigators.indices.contains(index) ? navigators[index] : nil
  }

  mutating func register(_ navigator: Navigator) {
    navigators.append(navigator)
  }
}

extension Navigator {
  /// Performs navigation operations within a specific SwiftUI transaction.
  ///
  /// Use this method to control the animation used for push and pop operations
  /// performed inside `body`. The transaction is also forwarded to
  /// ``ManagedPresentation`` so that modal present/dismiss animations respect it.
  ///
  /// ```swift
  /// navigator?.withTransaction(Transaction(animation: .easeInOut)) {
  ///     $0.push(DetailsDestination(id: "abc"))
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - transaction: The transaction to apply.
  ///   - body: A closure that receives the navigator.
  /// - Returns: The value returned by `body`.
  @discardableResult public func withTransaction<Result>(
    _ transaction: Transaction,
    body: (Navigator) throws -> Result
  ) rethrows -> Result {
    binding.wrappedValue.transaction = transaction
    let result = try SwiftUI.withTransaction(transaction) {
      try body(self)
    }
    return result
  }
  
  /// Performs navigation operations within a transaction configured by a
  /// single key-path/value pair.
  ///
  /// This is a convenience wrapper around ``withTransaction(_:body:)`` that
  /// creates a `Transaction`, sets the given key path, and applies it.
  ///
  /// ```swift
  /// navigator?.withTransaction(\.animation, .easeInOut) {
  ///     $0.push(DetailsDestination(id: "abc"))
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - keyPath: A writable key path on `Transaction`.
  ///   - value: The value to assign to `keyPath`.
  ///   - body: A closure that receives the navigator.
  /// - Returns: The value returned by `body`.
  @discardableResult public func withTransaction<V, R>(
    _ keyPath: WritableKeyPath<Transaction, V>,
    _ value: V,
    body: (Navigator) throws -> R
  ) rethrows -> R {
    var transaction = Transaction()
    transaction[keyPath: keyPath] = value
    return try withTransaction(transaction, body: body)
  }

  /// Performs navigation operations with animations disabled.
  ///
  /// All push, pop, and modal operations performed inside `body` execute
  /// without animation.
  ///
  /// ```swift
  /// navigator?.withoutAnimation {
  ///     $0.push([
  ///         HomeDestination(),
  ///         DetailsDestination(id: "abc"),
  ///     ])
  /// }
  /// ```
  ///
  /// - Parameter body: A closure that receives the navigator.
  /// - Returns: The value returned by `body`.
  @discardableResult public func withoutAnimation<Result>(body: (Navigator) throws -> Result) rethrows -> Result {
    try withTransaction(\.disablesAnimations, true, body: body)
  }
}
