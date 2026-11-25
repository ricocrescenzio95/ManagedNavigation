import Foundation
import SwiftUI

/// The central state manager for ``ManagedNavigationStack`` and ``ManagedPresentation``.
///
/// `NavigationManager` maintains a typed navigation path and keeps it in sync
/// with SwiftUI's `NavigationPath`. Use it to programmatically push and pop
/// destinations in both push-based navigation and modal presentations.
///
/// ```swift
/// @State var manager = NavigationManager()
///
/// // Push navigation
/// ManagedNavigationStack(manager: $manager) {
///     Button("Go to Details") {
///         manager.push(DetailsDestination(id: "abc"))
///     }
/// }
///
/// // Modal presentations
/// ManagedPresentation(manager: $manager) {
///     Button("Open Settings") {
///         manager.push(SettingsDestination())
///     }
///     .sheet(for: SettingsDestination.self) { _ in
///         SettingsView()
///     }
/// }
/// ```
///
/// You can also create a manager with an initial path:
///
/// ```swift
/// @State var manager = NavigationManager(
///     [HomeDestination(), DetailsDestination(id: "abc")]
/// )
/// ```
public struct NavigationManager: Identifiable {
  var _path = NavigationPath() {
    didSet {
      let delta = oldValue.count - _path.count
      if delta > 0, path.count >= delta {
        path.removeLast(delta)
      } else if delta < 0, _path.count > path.count {
        #if DEBUG
        fatalError("_path increased outside of NavigationManager. Use manager.push() instead of NavigationLink.")
        #else
        self = .init(path, id: id)
        #endif
      }
    }
  }

  /// The current navigation stack as an array of destinations.
  ///
  /// This array reflects the full ordered list of destinations that have been
  /// pushed onto the stack. The first element is the bottom of the stack
  /// (pushed first), and the last element is the top (most recently pushed).
  public private(set) var path = [any NavigationDestination]()
  
  public let id: String
  
  /// Stores the transaction that will be applied when animating in ``ManagedPresentation``.
  var transaction: Transaction?
  
  /// Creates an empty navigation manager with no destinations on the stack.
  public init(id: ID? = nil ) {
    self.id = id ?? UUID().uuidString
  }
  
  /// Creates a navigation manager pre-populated with the given destinations.
  ///
  /// The destinations are pushed in order, so the first argument becomes
  /// the bottom of the stack and the last argument becomes the top.
  ///
  /// ```swift
  /// @State var manager = NavigationManager(
  ///     [HomeDestination(), DetailsDestination(id: "abc")]
  /// )
  /// ```
  ///
  /// - Parameter path: An array of destinations to push onto the stack.
  ///- Parameter id: A custom id for the navigation manager.
  public init(_ path: [any NavigationDestination], id: ID? = nil) {
    self.init(id: id)
    
    for destination in path {
      push(destination)
    }
  }
  
  // MARK: - Push
  
  /// Pushes a single destination onto the navigation stack.
  ///
  /// ```swift
  /// manager.push(DetailsDestination(id: "abc"))
  /// ```
  ///
  /// - Parameter destination: The destination to push.
  public mutating func push(_ destination: some NavigationDestination) {
    path.append(destination)
    _path.append(destination)
  }
  
  /// Pushes multiple destinations onto the navigation stack in order.
  ///
  /// ```swift
  /// manager.push([
  ///     HomeDestination(),
  ///     DetailsDestination(id: "abc"),
  ///     HomeDestination()
  /// ])
  /// ```
  ///
  /// - Parameter destinations: An array of destinations to push, in order.
  public mutating func push(_ destinations: [any NavigationDestination]) {
    for destination in destinations {
      push(destination)
    }
  }
  
  /// Replaces the destination at the given index with a new destination.
  ///
  /// The stack above the replaced index is preserved. Because `NavigationPath`
  /// only supports append/removeLast, the path is rebuilt from the replacement
  /// index onward.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings]
  /// manager.replace(ProfileDestination(), at: 1)
  /// // Stack: [Home, Profile, Settings]
  /// ```
  ///
  /// - Parameters:
  ///   - destination: The new destination to insert.
  ///   - index: The zero-based index in ``path`` of the destination to replace.
  @discardableResult public mutating func replace(_ destination: any NavigationDestination, at index: Int) -> Bool {
    guard path.indices.contains(index) else { return false }
    var newPath = Array(path[..<index])
    newPath.append(destination)
    newPath.append(contentsOf: path[(index + 1)...])
    // Rebuild entirely to avoid didSet conflicts
    rebuild(newPath)
    return true
  }
  
  // MARK: - Pop
  
  /// Pops back to the **last** occurrence of the given destination type.
  ///
  /// Searches the stack from the top and pops all destinations above the
  /// last matching one.
  ///
  /// ```swift
  /// manager.popTo(HomeDestination.self)
  /// ```
  ///
  /// - Parameter destinationType: The type of destination to pop back to.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public mutating func popTo<Destination: NavigationDestination>(_ destinationType: Destination.Type) -> Bool {
    guard let targetIndex = path.lastIndex(where: { type(of: $0) == destinationType }) else {
      return false
    }
    
    let itemsToRemove = path.count - targetIndex - 1
    guard itemsToRemove > 0 else { return true }
    
    _path.removeLast(itemsToRemove)
    return true
  }
  
  /// Pops back to the first destination that satisfies the given predicate.
  ///
  /// Scans the stack from the bottom and pops all destinations above the
  /// first one where `predicate` returns `true`.
  ///
  /// ```swift
  /// manager.popTo(where: { context in
  ///     context.destination is HomeDestination && context.index > 0
  /// })
  /// ```
  ///
  /// - Parameter predicate: A closure that receives a ``NavigationScanContext``
  ///   and returns `true` for the destination where the stack should stop.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public mutating func popTo(where predicate: (NavigationScanContext) -> Bool) -> Bool {
    guard let targetIndex = path.indices.first(where: { predicate(.init(path: path, index: $0)) }) else {
      return false
    }
    
    let itemsToRemove = path.count - targetIndex - 1
    guard itemsToRemove > 0 else { return true }
    
    _path.removeLast(itemsToRemove)
    return true
  }
  
  /// Pops back to the **first** occurrence of the given destination type.
  ///
  /// Searches the stack from the bottom and pops all destinations above the
  /// first matching one.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Home, Details]
  /// manager.popToFirst(HomeDestination.self)
  /// // Stack: [Home]
  /// ```
  ///
  /// - Parameter destinationType: The type of destination to pop back to.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public mutating func popToFirst<Destination: NavigationDestination>(_ destinationType: Destination.Type) -> Bool {
    guard let targetIndex = path.firstIndex(where: { type(of: $0) == destinationType }) else {
      return false
    }
    
    let itemsToRemove = path.count - targetIndex - 1
    guard itemsToRemove > 0 else { return true }
    
    _path.removeLast(itemsToRemove)
    return true
  }
  
  /// Pops back to the destination at the given index.
  ///
  /// All destinations above the specified index are removed from the stack.
  ///
  /// - Parameter index: The zero-based index in ``path`` to pop back to.
  /// - Returns: `true` if the stack was modified, `false` if the index is out of bounds.
  @discardableResult public mutating func popTo(at index: Int) -> Bool {
    guard path.indices.contains(index) else { return false }

    let itemsToRemove = path.count - index - 1
    guard itemsToRemove > 0 else { return true }

    _path.removeLast(itemsToRemove)
    return true
  }

  /// Pops back to the destination at the given index, only if it matches the expected type.
  ///
  /// This is a safe variant of ``popTo(at:)`` that also verifies the destination
  /// type before popping, preventing accidental navigation to the wrong screen.
  ///
  /// - Parameters:
  ///   - destinationType: The expected type of the destination at the given index.
  ///   - index: The zero-based index in ``path`` to pop back to.
  /// - Returns: `true` if the destination at `index` matches the type and the stack
  ///   was trimmed, `false` otherwise.
  @discardableResult public mutating func popTo<Destination: NavigationDestination>(_ destinationType: Destination.Type, at index: Int) -> Bool {
    guard path.indices.contains(index), type(of: path[index]) == destinationType else {
      return false
    }

    let itemsToRemove = path.count - index - 1
    guard itemsToRemove > 0 else { return true }

    _path.removeLast(itemsToRemove)
    return true
  }

  /// Pops the last destination from the stack.
  ///
  /// Equivalent to tapping the back button or performing a swipe-back gesture.
  ///
  /// - Returns: `true` if a destination was removed, `false` if the stack was already empty.
  @discardableResult public mutating func pop() -> Bool {
    guard path.count > 0 else {
      return false
    }
    
    _path.removeLast()
    return true
  }
  
  /// Pops all destinations, returning to the root view.
  ///
  /// ```swift
  /// manager.popToRoot()
  /// ```
  ///
  /// - Returns: `true` if one or more destinations were removed, `false` if the stack was already empty.
  @discardableResult public mutating func popToRoot() -> Bool {
    guard path.count > 0 else { return false }
    
    _path.removeLast(_path.count)
    return true
  }
}

// MARK: - Utilities

extension NavigationManager {

  // MARK: Query

  /// A Boolean value indicating whether the stack contains no destinations.
  public var isEmpty: Bool { path.isEmpty }

  /// The number of destinations currently on the stack.
  public var count: Int { path.count }

  /// The destination at the top of the stack, or `nil` if the stack is empty.
  public var top: (any NavigationDestination)? { path.last }

  /// Returns a Boolean value indicating whether the stack contains a destination
  /// equal to the given one.
  ///
  /// Equality takes both the type and the values of the destination into account.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// manager.contains(DetailsDestination(id: "abc")) // true
  /// manager.contains(DetailsDestination(id: "xyz")) // false
  /// ```
  ///
  /// - Parameter destination: The destination to look for.
  /// - Returns: `true` if an equal destination is on the stack, `false` otherwise.
  public func contains(_ destination: some NavigationDestination) -> Bool {
    path.contains(where: { $0.equalsDestination(destination) })
  }

  /// Returns a Boolean value indicating whether the stack contains at least one
  /// destination of the given type.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// manager.contains(DetailsDestination.self) // true
  /// manager.contains(SettingsDestination.self) // false
  /// ```
  ///
  /// - Parameter type: The type of destination to look for.
  /// - Returns: `true` if a destination of that type is on the stack, `false` otherwise.
  public func contains<Destination: NavigationDestination>(_ type: Destination.Type) -> Bool {
    path.contains(where: { Swift.type(of: $0) == type })
  }

  /// Returns the index of the **last** destination of the given type.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Home, Details]
  /// manager.lastIndex(of: HomeDestination.self) // 2
  /// ```
  ///
  /// - Parameter type: The type of destination to look for.
  /// - Returns: The index in ``path`` of the last matching destination, or `nil`
  ///   if none was found.
  public func lastIndex<Destination: NavigationDestination>(of type: Destination.Type) -> Int? {
    path.lastIndex(where: { Swift.type(of: $0) == type })
  }

  /// Returns the **last** destination of the given type, already cast to that type.
  ///
  /// Useful to read the parameters of a destination that is already on the stack.
  ///
  /// ```swift
  /// if let details = manager.last(of: DetailsDestination.self) {
  ///     print(details.id)
  /// }
  /// ```
  ///
  /// - Parameter type: The type of destination to look for.
  /// - Returns: The last matching destination, or `nil` if none was found.
  public func last<Destination: NavigationDestination>(of type: Destination.Type) -> Destination? {
    path.last(where: { Swift.type(of: $0) == type }) as? Destination
  }

  // MARK: Conditional push

  /// Pushes a destination only if an **equal** destination is not already on the stack.
  ///
  /// Equality takes both the type and the values of the destination into account.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// manager.pushIfNotPresent(DetailsDestination(id: "abc")) // false, nothing happens
  /// manager.pushIfNotPresent(DetailsDestination(id: "xyz")) // true, pushed
  /// ```
  ///
  /// - Parameter destination: The destination to push.
  /// - Returns: `true` if the destination was pushed, `false` if an equal one
  ///   was already on the stack.
  @discardableResult public mutating func pushIfNotPresent(_ destination: some NavigationDestination) -> Bool {
    guard !contains(destination) else { return false }
    push(destination)
    return true
  }

  /// Pushes, in order, only the destinations that are not already on the stack.
  ///
  /// Each destination is checked right before it is pushed, so duplicates
  /// inside `destinations` itself are also skipped.
  ///
  /// ```swift
  /// // Stack: [Home]
  /// manager.pushIfNotPresent([
  ///     HomeDestination(),                // skipped
  ///     DetailsDestination(id: "abc"),    // pushed
  ///     DetailsDestination(id: "abc")     // skipped
  /// ])
  /// // Stack: [Home, Details(id: "abc")]
  /// ```
  ///
  /// - Parameter destinations: An array of destinations to push, in order.
  /// - Returns: `true` if at least one destination was pushed, `false` otherwise.
  @discardableResult public mutating func pushIfNotPresent(_ destinations: [any NavigationDestination]) -> Bool {
    var pushed = false
    for destination in destinations where !path.contains(where: { $0.equalsDestination(destination) }) {
      push(destination)
      pushed = true
    }
    return pushed
  }

  /// Pushes a destination only if no destination of the **same type** is already
  /// on the stack, regardless of its values.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// manager.pushIfTypeNotPresent(DetailsDestination(id: "xyz")) // false, a Details is already there
  /// manager.pushIfTypeNotPresent(SettingsDestination())         // true, pushed
  /// ```
  ///
  /// - Parameter destination: The destination to push.
  /// - Returns: `true` if the destination was pushed, `false` if one of the same
  ///   type was already on the stack.
  @discardableResult public mutating func pushIfTypeNotPresent<Destination: NavigationDestination>(_ destination: Destination) -> Bool {
    guard !contains(Destination.self) else { return false }
    push(destination)
    return true
  }

  /// Pushes a destination only if it is not equal to the destination currently
  /// on top of the stack.
  ///
  /// Useful to avoid duplicate pushes caused by double taps.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc")]
  /// manager.pushIfNotOnTop(DetailsDestination(id: "abc")) // false
  /// manager.pushIfNotOnTop(HomeDestination())             // true
  /// ```
  ///
  /// - Parameter destination: The destination to push.
  /// - Returns: `true` if the destination was pushed, `false` if the top of the
  ///   stack is equal to it.
  @discardableResult public mutating func pushIfNotOnTop(_ destination: some NavigationDestination) -> Bool {
    if let last = path.last, last.equalsDestination(destination) { return false }
    push(destination)
    return true
  }

  /// Pushes a destination only if the given condition, evaluated against the
  /// current state of the manager, returns `true`.
  ///
  /// ```swift
  /// manager.push(DetailsDestination(id: "abc"), if: { $0.count < 5 })
  /// ```
  ///
  /// - Parameters:
  ///   - destination: The destination to push.
  ///   - condition: A closure that receives the current manager and returns
  ///     `true` if the destination should be pushed.
  /// - Returns: `true` if the destination was pushed, `false` otherwise.
  @discardableResult public mutating func push(
    _ destination: some NavigationDestination,
    if condition: (NavigationManager) -> Bool
  ) -> Bool {
    guard condition(self) else { return false }
    push(destination)
    return true
  }

  // MARK: Pop

  /// Pops the given number of destinations from the top of the stack.
  ///
  /// If `count` is greater than the number of destinations on the stack,
  /// the stack is emptied.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings]
  /// manager.pop(2)
  /// // Stack: [Home]
  /// ```
  ///
  /// - Parameter count: The number of destinations to remove.
  /// - Returns: `true` if at least one destination was removed, `false` if
  ///   `count` is not positive or the stack was already empty.
  @discardableResult public mutating func pop(_ count: Int) -> Bool {
    guard count > 0, !path.isEmpty else { return false }
    _path.removeLast(min(count, path.count))
    return true
  }

  /// Pops destinations from the top of the stack for as long as the predicate
  /// returns `true`.
  ///
  /// The stack is scanned from the top, and popping stops at the first
  /// destination for which `predicate` returns `false`.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings, Settings]
  /// manager.pop(while: { $0 is SettingsDestination })
  /// // Stack: [Home, Details]
  /// ```
  ///
  /// - Parameter predicate: A closure that receives a destination and returns
  ///   `true` if it should be popped.
  /// - Returns: `true` if at least one destination was removed, `false` otherwise.
  @discardableResult public mutating func pop(while predicate: (any NavigationDestination) -> Bool) -> Bool {
    var count = 0
    for destination in path.reversed() {
      guard predicate(destination) else { break }
      count += 1
    }
    return pop(count)
  }

  /// Pops back to the **last** destination that satisfies the given predicate.
  ///
  /// Unlike ``popTo(where:)``, which scans from the bottom of the stack, this
  /// method scans from the top and stops at the last match.
  ///
  /// ```swift
  /// manager.popToLast(where: { context in
  ///     context.destination is HomeDestination
  /// })
  /// ```
  ///
  /// - Parameter predicate: A closure that receives a ``NavigationScanContext``
  ///   and returns `true` for the destination where the stack should stop.
  /// - Returns: `true` if a matching destination was found, `false` otherwise.
  @discardableResult public mutating func popToLast(where predicate: (NavigationScanContext) -> Bool) -> Bool {
    guard let targetIndex = path.indices.last(where: { predicate(.init(path: path, index: $0)) }) else {
      return false
    }
    return popTo(at: targetIndex)
  }

  // MARK: Combined push / pop

  /// Pops back to an **equal** destination if it is already on the stack,
  /// otherwise pushes the given destination.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc"), Settings]
  /// manager.pushOrPopTo(DetailsDestination(id: "abc")) // false
  /// // Stack: [Home, Details(id: "abc")]
  ///
  /// manager.pushOrPopTo(ProfileDestination()) // true
  /// // Stack: [Home, Details(id: "abc"), Profile]
  /// ```
  ///
  /// - Parameter destination: The destination to pop back to or push.
  /// - Returns: `true` if the destination was pushed, `false` if the stack
  ///   was popped back to an existing one.
  @discardableResult public mutating func pushOrPopTo(_ destination: some NavigationDestination) -> Bool {
    if let index = path.lastIndex(where: { $0.equalsDestination(destination) }) {
      popTo(at: index)
      return false
    }
    push(destination)
    return true
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
  @discardableResult public mutating func pushOrPopToType<Destination: NavigationDestination>(_ destination: Destination) -> Bool {
    if popTo(Destination.self) { return false }
    push(destination)
    return true
  }

  /// Pops all destinations and then pushes the given one, so that it becomes
  /// the only destination on the stack.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings]
  /// manager.popToRoot(thenPush: ProfileDestination())
  /// // Stack: [Profile]
  /// ```
  ///
  /// - Parameter destination: The destination to push after clearing the stack.
  public mutating func popToRoot(thenPush destination: some NavigationDestination) {
    popToRoot()
    push(destination)
  }

  // MARK: Stack modification

  /// Replaces the entire stack with the given destinations.
  ///
  /// The `id` and the transaction of the manager are preserved.
  ///
  /// ```swift
  /// manager.withoutAnimation {
  ///     $0.setPath([HomeDestination(), DetailsDestination(id: "abc")])
  /// }
  /// ```
  ///
  /// - Parameter destinations: The new stack, ordered from bottom to top.
  public mutating func setPath(_ destinations: [any NavigationDestination]) {
    rebuild(destinations)
  }

  /// Replaces the destination at the top of the stack with a new one.
  ///
  /// ```swift
  /// // Stack: [Home, Details]
  /// manager.replaceLast(with: SettingsDestination())
  /// // Stack: [Home, Settings]
  /// ```
  ///
  /// - Parameter destination: The new destination.
  /// - Returns: `true` if the destination was replaced, `false` if the stack was empty.
  @discardableResult public mutating func replaceLast(with destination: any NavigationDestination) -> Bool {
    replace(destination, at: path.count - 1)
  }

  /// Inserts a destination at the given index, shifting the following
  /// destinations up.
  ///
  /// ```swift
  /// // Stack: [Home, Settings]
  /// manager.insert(DetailsDestination(id: "abc"), at: 1)
  /// // Stack: [Home, Details(id: "abc"), Settings]
  /// ```
  ///
  /// - Parameters:
  ///   - destination: The destination to insert.
  ///   - index: The zero-based index at which to insert. Must be between `0`
  ///     and ``count``, inclusive.
  /// - Returns: `true` if the destination was inserted, `false` if the index
  ///   is out of bounds.
  @discardableResult public mutating func insert(_ destination: any NavigationDestination, at index: Int) -> Bool {
    guard index >= 0, index <= path.count else { return false }
    var newPath = path
    newPath.insert(destination, at: index)
    rebuild(newPath)
    return true
  }

  /// Removes the destination at the given index, keeping the ones above it.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings]
  /// manager.remove(at: 1)
  /// // Stack: [Home, Settings]
  /// ```
  ///
  /// - Parameter index: The zero-based index in ``path`` of the destination to remove.
  /// - Returns: `true` if the destination was removed, `false` if the index
  ///   is out of bounds.
  @discardableResult public mutating func remove(at index: Int) -> Bool {
    guard path.indices.contains(index) else { return false }
    var newPath = path
    newPath.remove(at: index)
    rebuild(newPath)
    return true
  }

  /// Removes all destinations of the given type from the stack.
  ///
  /// ```swift
  /// // Stack: [Home, Details, Settings, Details]
  /// manager.removeAll(of: DetailsDestination.self)
  /// // Stack: [Home, Settings]
  /// ```
  ///
  /// - Parameter type: The type of destinations to remove.
  /// - Returns: `true` if at least one destination was removed, `false` otherwise.
  @discardableResult public mutating func removeAll<Destination: NavigationDestination>(of type: Destination.Type) -> Bool {
    let newPath = path.filter { Swift.type(of: $0) != type }
    guard newPath.count != path.count else { return false }
    rebuild(newPath)
    return true
  }

  /// Removes all destinations equal to the given one from the stack.
  ///
  /// ```swift
  /// // Stack: [Home, Details(id: "abc"), Details(id: "xyz")]
  /// manager.removeAll(DetailsDestination(id: "abc"))
  /// // Stack: [Home, Details(id: "xyz")]
  /// ```
  ///
  /// - Parameter destination: The destination to remove.
  /// - Returns: `true` if at least one destination was removed, `false` otherwise.
  @discardableResult public mutating func removeAll(_ destination: some NavigationDestination) -> Bool {
    let newPath = path.filter { !$0.equalsDestination(destination) }
    guard newPath.count != path.count else { return false }
    rebuild(newPath)
    return true
  }

  // MARK: Private

  /// Rebuilds the stack from the given destinations, preserving the manager's
  /// `id` and `transaction`.
  private mutating func rebuild(_ newPath: [any NavigationDestination]) {
    let transaction = self.transaction
    self = .init(newPath, id: id)
    self.transaction = transaction
  }
}

extension NavigationManager: Hashable {
  public static func == (lhs: NavigationManager, rhs: NavigationManager) -> Bool {
    guard lhs.path.count == rhs.path.count else { return false }
    return zip(lhs.path, rhs.path).allSatisfy {
      let isEqual = $0.equalsDestination($1) // type checker fails with direct return (wtf???)
      return isEqual
    }
  }
  public func hash(into hasher: inout Hasher) {
    for destination in path {
      hasher.combine(destination)
    }
  }
}

// MARK: - NavigationScanContext

extension NavigationManager {
  /// Context provided to predicate-based navigation methods like ``popTo(where:)``.
  ///
  /// A `NavigationScanContext` gives you access to the full navigation path,
  /// the index being evaluated, and the destination at that index.
  ///
  /// ```swift
  /// manager.popTo(where: { context in
  ///     context.destination is DetailsDestination
  /// })
  /// ```
  public struct NavigationScanContext {
    /// The full navigation path at the time of scanning.
    public let path: [any NavigationDestination]

    /// The index of the destination currently being evaluated.
    public let index: Int

    /// The destination currently being evaluated.
    public var destination: any NavigationDestination { path[index] }
  }
}

extension NavigationManager {
  /// A serializable representation of a navigation manager's path.
  ///
  /// `CodableRepresentation` mirrors the behavior of
  /// `NavigationPath.CodableRepresentation`: it converts the navigation stack
  /// into a format that can be encoded and decoded with any `Codable`-compatible
  /// encoder or decoder (JSON, Property List, etc.).
  ///
  /// You don't create a `CodableRepresentation` directly. Instead, use the
  /// ``NavigationManager/codable`` property to obtain one, and
  /// ``NavigationManager/init(_:id:)-(CodableRepresentation,_)`` to restore the manager from a previously
  /// saved representation.
  ///
  /// ```swift
  /// // Save
  /// if let representation = manager.codable {
  ///     let data = try JSONEncoder().encode(representation)
  ///     UserDefaults.standard.set(data, forKey: "savedPath")
  /// }
  ///
  /// // Restore
  /// if let data = UserDefaults.standard.data(forKey: "savedPath"),
  ///    let representation = try? JSONDecoder().decode(
  ///        NavigationManager.CodableRepresentation.self, from: data
  ///    ) {
  ///     manager = NavigationManager(representation)
  /// }
  /// ```
  ///
  /// > Important: All destinations in the navigation path must conform to both
  /// > ``NavigationDestination`` and `Codable`. If any destination is not
  /// > `Codable`, the ``NavigationManager/codable`` property returns `nil`.
  ///
  /// > Note: Implementation comes from this [article](https://www.pointfree.co/blog/posts/78-reverse-engineering-swiftui-s-navigationpath-codability).
  public struct CodableRepresentation: Codable {
    typealias Element = any NavigationDestination & Codable
    var elements: [Element] = []
    
    init?(path: [any NavigationDestination]) {
      for destination in path {
        if let destination = destination as? Element {
          elements.append(destination)
        } else {
          return nil
        }
      }
    }
    
    public func encode(to encoder: any Encoder) throws {
      var container = encoder.unkeyedContainer()
      for element in elements.reversed() {
        try container.encode(_mangledTypeName(type(of: element)))
        try container.encode(
          String(decoding: JSONEncoder().encode(element), as: UTF8.self)
        )
      }
    }
    
    public init(from decoder: any Decoder) throws {
      var container = try decoder.unkeyedContainer()
      while !container.isAtEnd {
        let typeName = try container.decode(String.self)
        guard let type = _typeByName(typeName) as? Decodable.Type else {
          throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "\(typeName) is not decodable."
          )
        }
        let encodedValue = try container.decode(String.self)
        guard let value = try JSONDecoder().decode(type, from: Data(encodedValue.utf8)) as? Element else {
          throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "\(typeName) couldn't be casted to a proper NavigationDestination."
          )
        }
        elements.insert(value, at: 0)
      }
    }
  }
  
  /// Creates a navigation manager from a previously serialized representation.
  ///
  /// Use this initializer to restore a navigation stack from a
  /// ``CodableRepresentation`` that was previously obtained via the
  /// ``codable`` property and persisted.
  ///
  /// ```swift
  /// let data = UserDefaults.standard.data(forKey: "savedPath")!
  /// let representation = try JSONDecoder().decode(
  ///     NavigationManager.CodableRepresentation.self, from: data
  /// )
  /// let manager = NavigationManager(representation)
  /// ```
  ///
  /// - Parameter codable: The codable representation to restore from.
  ///- Parameter id: A custom id for the navigation manager.
  public init(_ codable: CodableRepresentation, id: ID? = nil) {
    self.init(id: id)
    push(codable.elements)
  }
  
  /// A codable representation of the navigation path, or `nil` if any
  /// destination in the path does not conform to `Codable`.
  ///
  /// Use this property to serialize the current navigation state for
  /// persistence (e.g. saving to `UserDefaults` or a file).
  ///
  /// ```swift
  /// if let representation = manager.codable {
  ///     let data = try JSONEncoder().encode(representation)
  ///     // Save data...
  /// }
  /// ```
  ///
  /// This property returns `nil` when one or more destinations in the stack
  /// do not conform to `Codable`, similar to how `NavigationPath.codable`
  /// behaves.
  public var codable: CodableRepresentation? {
    CodableRepresentation(path: path)
  }
}

extension NavigationManager {
  /// Performs navigation operations within a specific SwiftUI transaction.
  ///
  /// Use this method to control the animation used for push and pop operations
  /// performed inside `body`. The transaction is also forwarded to
  /// ``ManagedPresentation`` so that modal present/dismiss animations respect it.
  ///
  /// ```swift
  /// var transaction = Transaction(animation: .easeInOut(duration: 0.5))
  /// manager.withTransaction(transaction) {
  ///     $0.push(DetailsDestination(id: "abc"))
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - transaction: The transaction to apply.
  ///   - body: A closure that receives an `inout` reference to the manager.
  /// - Returns: The value returned by `body`.
  @discardableResult public mutating func withTransaction<Result>(
    _ transaction: Transaction,
    body: (inout Self) throws -> Result
  ) rethrows -> Result {
    self.transaction = transaction
    let result = try SwiftUI.withTransaction(transaction) {
      try body(&self)
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
  /// manager.withTransaction(\.animation, .easeInOut) {
  ///     $0.push(DetailsDestination(id: "abc"))
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - keyPath: A writable key path on `Transaction`.
  ///   - value: The value to assign to `keyPath`.
  ///   - body: A closure that receives an `inout` reference to the manager.
  /// - Returns: The value returned by `body`.
  @discardableResult public mutating func withTransaction<V, R>(
    _ keyPath: WritableKeyPath<Transaction, V>,
    _ value: V,
    body: (inout Self) throws -> R
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
  /// manager.withoutAnimation {
  ///     $0.push([
  ///         HomeDestination(),
  ///         DetailsDestination(id: "abc"),
  ///     ])
  /// }
  /// ```
  ///
  /// - Parameter body: A closure that receives an `inout` reference to the manager.
  /// - Returns: The value returned by `body`.
  @discardableResult public mutating func withoutAnimation<Result>(body: (inout Self) throws -> Result) rethrows -> Result {
    try withTransaction(\.disablesAnimations, true, body: body)
  }
}
