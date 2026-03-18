import SwiftUI
import OSLog

private let logger = Logger(subsystem: "ManagedNavigation", category: "PresentationModifier")

struct PresentationData {
  enum PresentationType {
    case sheet
    case fullScreenCover
  }
  var view: (any NavigationDestination) -> AnyView
  var presentationType: PresentationType
  var onDismiss: ((any NavigationDestination) -> Void)?
}

struct PresentationPreferenceKey: PreferenceKey {
  typealias Value = [AnyHashable: PresentationData]
  
  static var defaultValue: Value { .init() }
  
  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.merge(nextValue()) { $1 }
  }
}

private struct PresentationDestinationModifier<D: NavigationDestination, C: View>: ViewModifier {
  @Environment(\.navigator) private var navigator
  
  var data: D.Type
  var viewContent: (D) -> C
  var onDismiss: ((D) -> Void)?
  var presentationType: PresentationData.PresentationType
  
  func body(content: Content) -> some View {
    content
      .transformPreference(PresentationPreferenceKey.self) { value in
        value[data.navigationID] = .init(
          view: {
            AnyView(viewContent($0 as! D))
          },
          presentationType: presentationType,
          onDismiss: { onDismiss?($0 as! D) }
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
    onDismiss: ((D) -> Void)? = nil,
    @ViewBuilder content: @escaping (D) -> C
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
    onDismiss: ((D) -> Void)? = nil,
    @ViewBuilder content: @escaping (D) -> C
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
