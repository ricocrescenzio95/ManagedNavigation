import SwiftUI

/// A container view that manages modal presentations driven by a ``NavigationManager``.
///
/// `ManagedPresentation` works like ``ManagedNavigationStack`` but for modal
/// presentations (sheets and full-screen covers) instead of push navigation.
/// Child views register their presentation destinations using
/// ``SwiftUICore/View/sheet(for:onDismiss:content:)`` and
/// ``SwiftUICore/View/fullScreenCover(for:onDismiss:content:)``, and the
/// manager's path controls which modals are presented.
///
/// ```swift
/// @State var manager = NavigationManager()
///
/// ManagedPresentation(manager: $manager) {
///     VStack {
///         Button("Open Settings") {
///             manager.push(SettingsDestination())
///         }
///     }
///     .sheet(for: SettingsDestination.self) { _ in
///         SettingsView()
///     }
/// }
/// ```
///
/// Presentations are displayed recursively: if `SettingsView` itself
/// registers a `.sheet(for:)`, pushing the corresponding destination onto
/// the manager's path will present it on top of the settings sheet.
///
/// Child views can access the navigation manager through the
/// ``SwiftUICore/EnvironmentValues/navigator`` environment value.
public struct ManagedPresentation<Root: View>: View {
  @Binding var manager: NavigationManager
  var root: Root
  
  /// Creates a managed presentation container.
  ///
  /// - Parameters:
  ///   - manager: A binding to the ``NavigationManager`` that drives the presentations.
  ///   - root: A view builder that produces the root content. Use
  ///     ``SwiftUICore/View/sheet(for:onDismiss:content:)`` or
  ///     ``SwiftUICore/View/fullScreenCover(for:onDismiss:content:)`` inside
  ///     this content to register presentation destinations.
  public init(
    manager: Binding<NavigationManager>,
    @ViewBuilder root: () -> Root
  ) {
    _manager = manager
    self.root = root()
  }
  
  public var body: some View {
    root
      .environment(\.navigator, .init(navigationManager: $manager))
      .backgroundPreferenceValue(PresentationPreferenceKey.self) { presentations in
        PresentationBody(
          manager: $manager,
          isParentReady: true,
          presentations: presentations,
          path: manager.path,
          depth: 0,
        )
      }
  }
}

private struct PresentationBody: View {
  struct IdentifiableDestination: Identifiable {
    var id: AnyHashable {
      destination.navigationID
    }
    var destination: any NavigationDestination
    init?(_ destination: (some NavigationDestination)?) {
      if let destination {
        self.destination = destination
      } else {
        return nil
      }
    }
  }

  @State private var isFullyPresented = false
  @Binding var manager: NavigationManager
  var isParentReady: Bool
  var presentations: [AnyHashable: PresentationData]
  var path: [any NavigationDestination]
  var depth: Int
  
  var destination: (any NavigationDestination)? {
    manager.path.indices.contains(depth) ? manager.path[depth] : nil
  }
  
  var body: some View {
    Color.clear
      .sheet(item: .init(
        get: { destination(for: .sheet) },
        set: { setItem($0) }
      ), onDismiss: { destination.flatMap { onDismiss?($0) } }) {
        content(item: $0.destination)
      }
    #if !os(macOS)
      .fullScreenCover(item: .init(
        get: { destination(for: .fullScreenCover) },
        set: { setItem($0) }
      ), onDismiss: { destination.flatMap { onDismiss?($0) } }) {
        content(item: $0.destination)
      }
    #endif
  }
  
  private func destination(for presentationType: PresentationData.PresentationType) -> IdentifiableDestination? {
    if let destination, isParentReady {
      let isCorrectPresentation = presentationData(for: destination)?.presentationType == presentationType
      return isCorrectPresentation ? IdentifiableDestination(destination) : nil
    } else {
      return nil
    }
  }
  
  private func setItem(_ item: IdentifiableDestination?) {
    guard item == nil else { return }
    if depth == 0 {
      manager.popToRoot()
    } else {
      manager.popTo(at: depth - 1)
    }
  }
  
  private var onDismiss: ((any NavigationDestination) -> Void)? {
    presentationData(for: destination)?.onDismiss
  }
  
  private func presentationData(for destination: (any NavigationDestination)?) -> PresentationData? {
    if let destination {
      presentations[destination.navigationID]
    } else {
      nil
    }
  }
  
  @ViewBuilder private func content(
    item: any NavigationDestination
  ) -> some View {
    if let data = presentationData(for: item) {
      data.view(item)
        .environment(\.navigator, .init(navigationManager: $manager))
        .background {
          OnPresentedNotifier {
            isFullyPresented = true
          }
        }
        .backgroundPreferenceValue(PresentationPreferenceKey.self) { newPresentations in
          let presentations = presentations.merging(newPresentations) { $1 }
          if !path.isEmpty {
            PresentationBody(
              manager: $manager,
              isParentReady: isFullyPresented,
              presentations: presentations,
              path: Array(path.suffix(from: 1)),
              depth: depth + 1,
            )
          }
        }
    } else {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.yellow)
    }
  }
}
