/// A type that can be pushed onto a ``ManagedNavigationStack`` or presented
/// via a ``ManagedPresentation``.
///
/// Conform your destination types to `NavigationDestination` to use them with
/// ``NavigationManager``. The protocol inherits from `Hashable`, so your
/// types must also satisfy that requirement.
///
/// Every conforming type has an ``id`` that uniquely identifies the
/// destination *kind*. The default implementation returns the type name as a
/// `String`:
///
/// ```swift
/// struct HomeDestination: NavigationDestination {}
/// // HomeDestination.id == "HomeDestination"
/// ```
///
/// You can provide a custom value when you need stable identifiers:
///
/// ```swift
/// struct SettingsDestination: NavigationDestination {
///     static var id: String { "settings" }
/// }
/// ```
public protocol NavigationDestination: Hashable {
  associatedtype NavigationID: Hashable = String
  
  /// An hashable that uniquely identifies this destination kind.
  static var id: NavigationID { get }
}

extension NavigationDestination {
  /// An hashable that uniquely identifies this destination kind.
  public var navigationID: NavigationID { Self.id }
  
  /// The concrete type of this destination.
  public var type: Self.Type { Self.self }
  
  /// Returns `true` when this destination's ``navigationID`` equals the given value.
  ///
  /// Use this to compare a destination against a raw identifier without
  /// needing a concrete `NavigationDestination` instance:
  ///
  /// ```swift
  /// if destination.matchesID("settings") { … }
  /// ```
  ///
  /// - Parameter id: A hashable value to compare against this destination's ``navigationID``.
  /// - Returns: `true` if `id` can be cast to ``NavigationID`` and is equal
  ///   to this destination's ``navigationID``; otherwise `false`.
  public func matchesID(_ id: some Hashable) -> Bool {
    if let id = id as? NavigationID {
      navigationID == id
    } else {
      false
    }
  }
  
  /// Returns `true` when the given destination is the same type and has a
  /// matching ``navigationID``.
  ///
  /// This performs an **identity-level** comparison based only on the
  /// ``navigationID``. Two destinations that carry different associated data
  /// (e.g. different parameters) will still match as long as they share the
  /// same type and identifier:
  ///
  /// ```swift
  /// let a = ProfileDestination(userID: 1)
  /// let b = ProfileDestination(userID: 2)
  /// a.matchesDestination(b) // true – same type and navigationID
  /// ```
  ///
  /// To check full value equality (including all stored properties), use
  /// ``equalsDestination(_:)`` instead.
  ///
  /// - Parameter other: Another navigation destination to compare against.
  /// - Returns: `true` if `other` is the same type as `Self` and shares the
  ///   same ``navigationID``; otherwise `false`.
  public func matchesDestination(_ other: some NavigationDestination) -> Bool {
    if let other = other as? Self {
      navigationID == other.navigationID
    } else {
      false
    }
  }
  
  /// Returns `true` when the given destination is the same type and is
  /// fully equal (as defined by `Hashable` / `Equatable` conformance).
  ///
  /// Unlike ``matchesDestination(_:)``, this method compares the **entire
  /// value**, including all stored properties:
  ///
  /// ```swift
  /// let a = ProfileDestination(userID: 1)
  /// let b = ProfileDestination(userID: 2)
  /// a.equalsDestination(b)   // false – different userID
  /// a.equalsDestination(a)   // true
  /// ```
  ///
  /// - Parameter other: Another navigation destination to compare against.
  /// - Returns: `true` if `other` is the same type as `Self` and is equal
  ///   according to `==`; otherwise `false`.
  public func equalsDestination(_ other: some NavigationDestination) -> Bool {
    if let other = other as? Self {
      self == other
    } else {
      false
    }
  }
}

extension NavigationDestination where NavigationID == String {
  /// The default navigation ID, derived from the type name.
  public static var id: String { String(describing: Self.self) }
}
