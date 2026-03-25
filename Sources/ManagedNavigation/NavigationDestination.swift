/// A type that can be pushed onto a ``ManagedNavigationStack`` or presented
/// via a ``ManagedPresentation``.
///
/// Conform your destination types to `NavigationDestination` to use them with
/// ``NavigationManager``. The protocol inherits from `Hashable`, so your
/// types must also satisfy that requirement.
///
/// Every conforming type has an ``id`` that uniquely identifies the
/// destination *kind*. The default implementation returns the
/// `ObjectIdentifier` of the type itself:
///
/// ```swift
/// struct HomeDestination: NavigationDestination {}
/// // HomeDestination.id == ObjectIdentifier(HomeDestination.self)
/// ```
public protocol NavigationDestination: Hashable {}

extension NavigationDestination {
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
  public func matchesDestination<Other: NavigationDestination>(_ other: Other) -> Bool {
    Self.id == Other.id
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

extension NavigationDestination {
  /// The default navigation ID, derived from the `ObjectIdentifier` of the type.
  public static var id: ObjectIdentifier { ObjectIdentifier(Self.self) }
  
  /// A hashable value that uniquely identifies this destination kind.
  public var navigationID: ObjectIdentifier { Self.id }
}
