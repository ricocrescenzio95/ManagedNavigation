/// A type that can be pushed onto a ``ManagedNavigationStack`` or presented
/// via a ``ManagedPresentation``.
///
/// Conform your destination types to `NavigationDestination` to use them with
/// ``NavigationManager``. The protocol inherits from `Hashable`, so your
/// types must also satisfy that requirement.
///
/// Every conforming type has a ``navigationID`` that uniquely identifies the
/// destination *kind*. The default implementation returns the type name as a
/// `String`:
///
/// ```swift
/// struct HomeDestination: NavigationDestination {}
/// // HomeDestination.navigationID == "HomeDestination"
/// ```
///
/// You can provide a custom value when you need stable identifiers:
///
/// ```swift
/// struct SettingsDestination: NavigationDestination {
///     static var navigationID: String { "settings" }
/// }
/// ```
public protocol NavigationDestination: Hashable {
  associatedtype NavigationID
  
  /// A string that uniquely identifies this destination kind.
  static var navigationID: NavigationID { get }
}

extension NavigationDestination {
  public static var navigationID: String { String(describing: Self.self) }
  
  /// A string that uniquely identifies this destination kind.
  public var navigationID: String { Self.navigationID }
  
  public var type: Self.Type { Self.self }
}
