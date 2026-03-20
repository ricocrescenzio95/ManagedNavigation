import SwiftUI
import Observation

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
/// Presentations are identified by their ``NavigationDestination/navigationID``.
/// If you replace a destination in the path with another instance of the
/// same type (same `navigationID`) but different data, the presented view
/// updates in place without a dismiss/present cycle.
///
/// Child views can access the navigation manager through the
/// ``SwiftUICore/EnvironmentValues/navigator`` environment value.
public struct ManagedPresentation<Root: View>: View {
  @State private var model = PresentationModel()
  
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
      .onChange(
        of: manager.path.map { AnyHashable($0) },
        initial: true
      ) { old, new in
        // Create all necessary levels
        let needed = max(old.count, new.count)
        while model.levels.count < needed {
          model.levels.append(PresentationLevel())
        }

        // Update all destinations with latest path
        for (index, destination) in manager.path.enumerated() {
          model.levels[index].destination = destination
        }

        // Clear ongoing operations
        model.levels.forEach { $0.operations = [] }

        // Set all dismiss and present, by checking only navigationID to avoid
        // closing and reopening a sheet/fullScreenCover when only other data changed
        let old = old.map { AnyHashable(($0.base as! any NavigationDestination).navigationID) }
        let new = new.map { AnyHashable(($0.base as! any NavigationDestination).navigationID) }
        let prefixLength = zip(old, new).prefix(while: { $0 == $1 }).count
        for index in prefixLength..<old.count {
          model.levels[index].operations.append(.dismiss)
        }
        for index in prefixLength..<new.count {
          model.levels[index].operations.append(.present)
        }
      }
      .backgroundPreferenceValue(PresentationPreferenceKey.self) { presentations in
        PresentationBody(
          manager: $manager,
          presentations: presentations,
          level: model.levels[0],
          depth: 0,
        )
        .environment(model)
      }
      .environment(\.navigator, $manager)
  }
}

private struct PresentationBody: View {
  @Environment(PresentationModel.self) private var model

  @State private var isPresented = false
  @State private var storedDestination: (any NavigationDestination)?
  @Binding var manager: NavigationManager

  var presentations: [AnyHashable: PresentationData]
  var level: PresentationLevel
  var depth: Int

  var destination: (any NavigationDestination)? { level.destination }

  var shouldWaitForOtherOperations: Bool {
    if level.operations.contains(.dismiss) {
      model.operations.contains { $0.key < depth && $0.value.contains(.dismiss) }
    } else if level.operations.contains(.present) {
      model.operations.contains { $0.value.contains(.dismiss) }
    } else {
      false
    }
  }

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .allowsHitTesting(false)
      .onChange(of: model.operations) { _, operations in
        guard !shouldWaitForOtherOperations else { return }
        if operations[depth]?.contains(.dismiss) == true {
          isPresented = false
        } else if operations[depth]?.contains(.present) == true {
          isPresented = true
          storedDestination = destination
        }
      }
      .sheet(
        isPresented: .init(get: { isPresented(for: .sheet) }, set: { setPresented($0) }),
        onDismiss: { storedDestination.flatMap { onDismiss?($0, depth) } }
      ) {
        content
      }
      .onChange(of: destination.map { AnyHashable($0) }) {
        if isPresented, !shouldWaitForOtherOperations,
           let destination,
           let navID = storedDestination?.navigationID,
           AnyHashable(navID) == AnyHashable(destination.navigationID) {
          storedDestination = destination
        }
      }
#if !os(macOS)
      .fullScreenCover(
        isPresented: .init(get: { isPresented(for: .fullScreenCover) }, set: { setPresented($0) }),
        onDismiss: { storedDestination.flatMap { onDismiss?($0, depth) } }
      ) {
        content
      }
#endif
  }

  private func isPresented(for presentationType: PresentationData.PresentationType) -> Bool {
    guard let destination = storedDestination else { return false }
    let effectiveType = presentationData(for: destination)?.presentationType ?? .sheet
    return effectiveType == presentationType && isPresented
  }

  private func setPresented(_ isPresented: Bool) {
    guard !isPresented else {
      self.isPresented = true
      return
    }

    // A new present is already queued — don't tear down.
    if level.operations.contains(.present) {
      return
    }

    self.isPresented = false

    // User swipe-to-dismiss while idle — sync the manager.
    if depth == 0 {
      manager.popToRoot()
    } else {
      manager.popTo(at: depth - 1)
    }
  }

  private var onDismiss: ((any NavigationDestination, Int) -> Void)? {
    presentationData(for: storedDestination)?.onDismiss
  }

  private func presentationData(for destination: (any NavigationDestination)?) -> PresentationData? {
    if let destination {
      presentations[AnyHashable(destination.navigationID)]
    } else {
      nil
    }
  }

  @ViewBuilder private var content: some View {
    Group {
      if let destination = storedDestination, let data = presentationData(for: destination) {
        AnyView(data.view(destination, depth))
      } else {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.yellow)
      }
    }
    .backgroundPreferenceValue(PresentationPreferenceKey.self) {
      let nextDepth = depth + 1
      PresentationBody(
        manager: $manager,
        presentations: presentations.merging($0) { $1 },
        level: model.levels.indices.contains(nextDepth) ? model.levels[nextDepth] : .init(),
        depth: nextDepth,
      )
      .environment(model)
    }
    .environment(\.navigator, $manager)
    .background {
      OnPresentedNotifier {
        level.operations.removeAll { $0 == .present }
      } onDismissed: {
        level.operations.removeAll { $0 == .dismiss }
        // Only clear the destination if no new present is pending.
        // A rapid dismiss→present sequence can cause onDismissed to fire
        // after the new present was already set up.
        if !level.operations.contains(.present) {
          storedDestination = nil
        }
      }
      .frame(width: 0, height: 0)
      .allowsHitTesting(false)
    }
  }
}

@Observable
private class PresentationLevel {
  enum Operation: Equatable {
    case present
    case dismiss
  }
  
  var destination: (any NavigationDestination)?
  var operations: [Operation] = []
}

@Observable
private class PresentationModel {
  var levels: [PresentationLevel] = [.init()]

  var operations: [Int: [PresentationLevel.Operation]] {
    var dict = [Int: [PresentationLevel.Operation]](minimumCapacity: levels.count)
    for (offset, level) in levels.enumerated() {
      dict[offset] = level.operations
    }
    return dict
  }
}
