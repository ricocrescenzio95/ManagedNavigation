import SwiftUI

#if DEBUG
import OSLog
private let logger = Logger(subsystem: "ManagedNavigation", category: "PresentationModifier")
#endif

struct PresentationData {
  enum PresentationType {
    case sheet
    case fullScreenCover
  }
  var view: (any NavigationDestination, _ index: Int) -> any View
  var presentationType: PresentationType
  var onDismiss: ((any NavigationDestination, _ index: Int) -> Void)?
}

struct PresentationPreferenceKey: PreferenceKey {
  typealias Value = [ObjectIdentifier: PresentationData]
  
  static var defaultValue: Value { .init() }
  
  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.merge(nextValue()) { $1 }
  }
}

/// The context passed to presentation content and dismiss closures.
///
/// Contains the destination instance that triggered the presentation and
/// its index in the ``NavigationManager``'s path.
public struct PresentationContext<D: NavigationDestination> {
  /// The destination instance that triggered this presentation.
  public var destination: D
  /// The zero-based index of this presentation in the manager's path.
  public var index: Int
}

private struct PresentationDestinationModifier<D: NavigationDestination, C: View>: ViewModifier {
  @Environment(\.navigator) private var navigator
  
  var data: D.Type
  var viewContent: (PresentationContext<D>) -> C
  var onDismiss: ((PresentationContext<D>) -> Void)?
  var presentationType: PresentationData.PresentationType
  
  func body(content: Content) -> some View {
    content
      .transformPreference(PresentationPreferenceKey.self) { value in
        value[data.id] = .init(
          view: { viewContent(.init(destination: $0 as! D, index: $1)) },
          presentationType: presentationType,
          onDismiss: { onDismiss?(.init(destination: $0 as! D, index: $1)) }
        )
      }
      .onAppear {
        #if DEBUG
        if navigator == nil {
          logger.log(level: .fault, "sheet(for:content:) and fullScreenCover(for:content:) modifiers are allowed only in ManagedPresentation children")
        }
        #endif
      }
  }
}

extension View {
  /// Registers a sheet presentation for a specific destination type.
  ///
  /// Use this modifier inside a ``ManagedPresentation`` to associate a
  /// ``NavigationDestination`` type with a sheet. When that destination is
  /// pushed onto the ``NavigationManager``'s path, the sheet is presented
  /// automatically.
  ///
  /// The sheet is matched by ``NavigationDestination/navigationID``.
  /// Replacing the destination with another instance of the same type
  /// updates the sheet content without dismissing and re-presenting it.
  ///
  /// ```swift
  /// ManagedPresentation(manager: $manager) {
  ///     MyRootView()
  ///         .sheet(for: SettingsDestination.self) { settings in
  ///             SettingsView(settings)
  ///         }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - data: The destination type that triggers this sheet.
  ///   - onDismiss: An optional closure called when the sheet is dismissed.
  ///   - content: A view builder that receives the destination instance and
  ///     returns the sheet content.
  public func sheet<D: NavigationDestination, C: View>(
    for data: D.Type,
    onDismiss: ((PresentationContext<D>) -> Void)? = nil,
    @ViewBuilder content: @escaping (PresentationContext<D>) -> C
  ) -> some View {
    modifier(
      PresentationDestinationModifier(
        data: data,
        viewContent: content,
        onDismiss: onDismiss,
        presentationType: .sheet
      )
    )
  }
  
  /// Registers a full-screen cover presentation for a specific destination type.
  ///
  /// Use this modifier inside a ``ManagedPresentation`` to associate a
  /// ``NavigationDestination`` type with a full-screen cover. When that
  /// destination is pushed onto the ``NavigationManager``'s path, the cover
  /// is presented automatically.
  ///
  /// The cover is matched by ``NavigationDestination/navigationID``.
  /// Replacing the destination with another instance of the same type
  /// updates the cover content without dismissing and re-presenting it.
  ///
  /// ```swift
  /// ManagedPresentation(manager: $manager) {
  ///     MyRootView()
  ///         .fullScreenCover(for: OnboardingDestination.self) { _ in
  ///             OnboardingView()
  ///         }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - data: The destination type that triggers this full-screen cover.
  ///   - onDismiss: An optional closure called when the cover is dismissed.
  ///   - content: A view builder that receives the destination instance and
  ///     returns the cover content.
  @available(macOS, unavailable)
  public func fullScreenCover<D: NavigationDestination, C: View>(
    for data: D.Type,
    onDismiss: ((PresentationContext<D>) -> Void)? = nil,
    @ViewBuilder content: @escaping (PresentationContext<D>) -> C
  ) -> some View {
    modifier(
      PresentationDestinationModifier(
        data: data,
        viewContent: content,
        onDismiss: onDismiss,
        presentationType: .fullScreenCover
      )
    )
  }
}
