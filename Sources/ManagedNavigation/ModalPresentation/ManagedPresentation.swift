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

        let destinations = manager.path

        // Only update destinations on levels with no in-flight operations.
        // Levels with active operations use snapshot-assigned destinations.
        model.updateIdleDestinations(from: destinations)

        // Build snapshot of navigationIDs and enqueue
        let navigationIDs = new.map {
          AnyHashable(($0.base as! any NavigationDestination).navigationID)
        }
        model.enqueueSnapshot(.init(navigationIDs: navigationIDs, destinations: destinations))
      }
      .backgroundPreferenceValue(PresentationPreferenceKey.self) { presentations in
        PresentationBody(
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
  @Environment(\.navigator) private var navigator
  
  @State private var isPresented = false
  @State private var storedDestination: (any NavigationDestination)?

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
          // Don't dismiss while UIKit is still animating a present.
          guard !level.isPresenting else { return }
          isPresented = false
        } else if operations[depth]?.contains(.present) == true {
          // Don't re-execute a present that's already in progress.
          // The onChange can re-fire due to eager destination updates on
          // the model, even though the operations haven't actually changed.
          guard !level.isPresenting else { return }
          level.isPresenting = true
          isPresented = true
          storedDestination = destination
        }
      }
      .onChange(of: level.isPresenting) { _, isTransitioning in
        // When a present transition finishes, retry any pending dismiss.
        if !isTransitioning,
           level.operations.contains(.dismiss),
           !shouldWaitForOtherOperations {
          isPresented = false
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
      navigator?.popToRoot()
    } else {
      navigator?.popTo(at: depth - 1)
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
        presentations: presentations.merging($0) { $1 },
        level: model.levels.indices.contains(nextDepth) ? model.levels[nextDepth] : .init(),
        depth: nextDepth,
      )
      .environment(model)
    }
    .environment(\.navigator, navigator)
    .background {
      OnPresentedNotifier {
        level.isPresenting = false
        level.operations.removeAll { $0 == .present }
        model.onOperationCompleted()
      } onDismissed: {
        level.operations.removeAll { $0 == .dismiss }
        // Only clear the destination if no new present is pending.
        // A rapid dismiss→present sequence can cause onDismissed to fire
        // after the new present was already set up.
        if !level.operations.contains(.present) {
          storedDestination = nil
        }
        model.onOperationCompleted()
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

  /// `true` while UIKit is animating a present transition for this level.
  /// Set when `isPresented` becomes `true`, cleared when `onPresented` fires.
  var isPresenting = false
}

@Observable
private class PresentationModel {
  struct Snapshot {
    let navigationIDs: [AnyHashable]
    let destinations: [any NavigationDestination]
  }

  var levels: [PresentationLevel] = [.init()]

  /// The navigationID array that the UI has fully animated to.
  private var confirmedNavigationIDs: [AnyHashable] = []

  /// The snapshot currently being processed, or nil if idle.
  private var activeSnapshot: Snapshot?

  /// Pending snapshots waiting to be processed (collapsed to at most one).
  private var pendingSnapshots: [Snapshot] = []

  var operations: [Int: [PresentationLevel.Operation]] {
    var dict = [Int: [PresentationLevel.Operation]](minimumCapacity: levels.count)
    for (offset, level) in levels.enumerated() {
      dict[offset] = level.operations
    }
    return dict
  }

  var allOperationsComplete: Bool {
    levels.allSatisfy { $0.operations.isEmpty }
  }

  /// Updates destinations on levels that have no in-flight operations.
  /// Levels that are part of an active snapshot keep their snapshot-assigned
  /// destinations until those operations complete.
  func updateIdleDestinations(from path: [any NavigationDestination]) {
    for (index, destination) in path.enumerated() where index < levels.count {
      if levels[index].operations.isEmpty {
        levels[index].destination = destination
      }
    }
  }

  func enqueueSnapshot(_ snapshot: Snapshot) {
    if activeSnapshot == nil {
      processSnapshot(snapshot)
    } else {
      // Collapse: only keep the latest pending snapshot.
      // This would discard intermediate snapshot that didn't start and jump
      // straight to the final result.
      pendingSnapshots = [snapshot]
    }
  }

  func onOperationCompleted() {
    guard activeSnapshot != nil, allOperationsComplete else { return }
    confirmAndAdvance()
  }

  private func processSnapshot(_ snapshot: Snapshot) {
    activeSnapshot = snapshot

    levels.forEach { $0.operations = [] }

    let old = confirmedNavigationIDs
    let new = snapshot.navigationIDs
    let prefixLength = zip(old, new).prefix(while: { $0 == $1 }).count

    // Set destinations from the snapshot for levels that will be presented.
    for index in prefixLength..<new.count {
      levels[index].destination = snapshot.destinations[index]
      levels[index].operations.append(.present)
    }

    for index in prefixLength..<old.count {
      levels[index].operations.append(.dismiss)
    }

    // Update idle levels (shared prefix) with latest destination data.
    for index in 0..<prefixLength {
      levels[index].destination = snapshot.destinations[index]
    }

    if allOperationsComplete {
      confirmAndAdvance()
    }
  }

  private func confirmAndAdvance() {
    if let active = activeSnapshot {
      confirmedNavigationIDs = active.navigationIDs
    }
    activeSnapshot = nil

    if let next = pendingSnapshots.first {
      pendingSnapshots.removeFirst()
      processSnapshot(next)
    }
  }
}
