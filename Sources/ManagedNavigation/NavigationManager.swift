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
public struct NavigationManager {
  var _path = NavigationPath() {
    didSet {
      let delta = oldValue.count - _path.count
      if delta > 0, path.count >= delta {
        path.removeLast(delta)
      } else if delta < 0, _path.count > path.count {
        #if DEBUG
        fatalError("_path increased outside of NavigationManager. Use manager.push() instead of NavigationLink.")
        #else
        self = .init(path)
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
  
  /// Creates an empty navigation manager with no destinations on the stack.
  public init() {}
  
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
  public init(_ path: [any NavigationDestination]) {
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
    self = .init(newPath)
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
  /// ``NavigationManager/init(_:)-(CodableRepresentation)`` to restore the manager from a previously
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
  public init(_ codable: CodableRepresentation) {
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
