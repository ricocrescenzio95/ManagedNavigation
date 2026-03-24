import SwiftUI
import Observation

#if DEBUG
import OSLog
private let logger = Logger(subsystem: "ManagedNavigation", category: "ManagedPresentation")
#endif

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
  
  // Use StateObject to ensure single instance when creating in init
  @StateObject private var navigator: Navigator

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
    _navigator = StateObject(wrappedValue: Navigator(manager))
    self.root = root()
  }

  public var body: some View {
    root
      .onChange(
        of: manager.path.map { AnyHashable($0) },
        initial: true
      ) { old, new in
        model.onPathChange(old: old, new: new)
        navigator.syncPath()
      }
      .backgroundPreferenceValue(PresentationPreferenceKey.self) { presentations in
        LevelResolver(presentations: presentations, depth: 0)
          .environment(model)
      }
      .environment(\.navigator, navigator)
  }
}

private struct PresentationBody: View {
  @Environment(\.navigator) private var navigator
  @Environment(PresentationModel.self) var model

  @State private var isPresented = false
  @State private var storedDestination: (any NavigationDestination)?

  var presentations: [AnyHashable: PresentationData]
  var level: PresentationLevel
  var depth: Int

  var destination: (any NavigationDestination)? { level.destination }

  var body: some View {
    OperationObserver(
      level: level,
      isPresented: $isPresented,
      storedDestination: $storedDestination
    )
    .sheet(
      isPresented: .init(get: { isPresented(for: .sheet) }, set: { setPresented($0) }),
      onDismiss: { storedDestination.flatMap { onDismiss?($0, depth) } }
    ) {
      content
    }
    .onChange(of: destination.map { AnyHashable($0) }) {
      if isPresented,
         let destination,
         let storedDestination,
         destination.matchesDestination(storedDestination) {
        self.storedDestination = destination
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
    guard let storedDestination else { return false }
    let effectiveType = presentationData(for: storedDestination)?.presentationType ?? .sheet
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
      if let storedDestination, let data = presentationData(for: storedDestination) {
        AnyView(data.view(storedDestination, depth))
      } else {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.yellow)
        #if DEBUG
          .onAppear {
            if let storedDestination {
              logger.fault("No destination registered for \(String(describing: storedDestination.navigationID)). Use sheet(for:content:) or fullScreenCover(for:content:) to register a destination.")
            }
          }
        #endif
        #if os(macOS)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.background)
          .onTapGesture {
            navigator?.pop()
          }
        #endif
      }
    }
    .backgroundPreferenceValue(PresentationPreferenceKey.self) {
      LevelResolver(
        presentations: presentations.merging($0) { $1 },
        depth: depth + 1
      )
    }
    .background {
      OperationCompletedObserver(level: level, storedDestination: $storedDestination)
    }
  }
}

private struct LevelResolver: View {
  @Environment(PresentationModel.self) var model
  var presentations: [AnyHashable: PresentationData]
  var depth: Int
  
  var body: some View {
    PresentationBody(
      presentations: presentations,
      level: model.levels.indices.contains(depth) ? model.levels[depth] : .init(),
      depth: depth,
    )
  }
}

private struct OperationCompletedObserver: View {
  @Environment(PresentationModel.self) var model
  var level: PresentationLevel
  @Binding var storedDestination: (any NavigationDestination)?
  
  var body: some View {
    PresentationNotifier {
      model.onOperationCompleted(of: level)
    } onDismissed: {
      // Only clear the destination if no new present is pending.
      // A rapid dismiss→present sequence can cause onDismissed to fire
      // after the new present was already set up.
      if !level.operations.contains(.present) {
        storedDestination = nil
      }
      
      model.onOperationCompleted(of: level)
    }
    .frame(width: 0, height: 0)
    .allowsHitTesting(false)
  }
}

private struct OperationObserver: View {
  @Environment(PresentationModel.self) var model

  var level: PresentationLevel
  @Binding var isPresented: Bool
  @Binding var storedDestination: (any NavigationDestination)?

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .allowsHitTesting(false)
      .onChange(of: level.operation, initial: true) { _, operation in
        switch operation {
        case .present:
          isPresented = true
          storedDestination = level.destination
        case .dismiss:
          if isPresented {
            isPresented = false
          } else {
            // Sheet was already dismissed by UIKit (user swipe).
            // No animation will happen, so complete immediately.
            model.onOperationCompleted(of: level)
          }
        case .none: break
        }
      }
  }
}

@Observable
private class PresentationLevel {
  enum Operation: CustomStringConvertible {
    case present
    case dismiss

    var description: String {
      switch self {
      case .present: "present"
      case .dismiss: "dismiss"
      }
    }
  }

  var destination: (any NavigationDestination)?
  var operations: [Operation] = []
  var operation: Operation?
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
  private var processingSnapshot: Snapshot?

  /// Pending snapshots waiting to be processed (collapsed to at most one).
  private var pendingSnapshots: [Snapshot] = []

  func onPathChange(old: [AnyHashable], new: [AnyHashable]) {
    // Create all necessary levels
    let needed = max(old.count, new.count)
    while levels.count < needed {
      levels.append(PresentationLevel())
    }

    let destinations = new.map { $0.base as! any NavigationDestination }

    // Only update destinations on levels with no in-flight operations.
    // Levels with active operations use snapshot-assigned destinations.
    updateIdleDestinations(from: destinations)

    // Build snapshot of navigationIDs and enqueue
    let navigationIDs = destinations.map { AnyHashable($0.navigationID) }
    
    enqueueSnapshot(.init(navigationIDs: navigationIDs, destinations: destinations))
  }
  
  /// Updates destinations on levels that have no in-flight operations.
  /// Levels that are part of an active snapshot keep their snapshot-assigned
  /// destinations until those operations complete.
  func updateIdleDestinations(from path: [any NavigationDestination]) {
    for (index, destination) in path.enumerated() where index < levels.count {
      if levels[index].operations.isEmpty {
        if let existing = levels[index].destination {
          if !existing.equalsDestination(destination) {
            levels[index].destination = destination
          }
        } else {
          levels[index].destination = destination
        }
      }
    }
  }

  func enqueueSnapshot(_ snapshot: Snapshot) {
    if processingSnapshot == nil {
      processSnapshot(snapshot)
    } else {
      // Collapse: only keep the latest pending snapshot.
      // This would discard intermediate snapshot that didn't start and jump
      // straight to the final result.
      pendingSnapshots = [snapshot]
    }
  }

  func onOperationCompleted(of level: PresentationLevel) {
    if let currentOperation = level.operation {
      level.operations.removeAll { $0 == currentOperation }
      level.operation = nil
      executeNextOperation()
    }
  }

  private func processSnapshot(_ snapshot: Snapshot) {
    processingSnapshot = snapshot

    let old = confirmedNavigationIDs
    let new = snapshot.navigationIDs
    let prefixLength = zip(old, new).prefix(while: { $0 == $1 }).count

    // Set destinations from the snapshot for levels that will be presented.
    for index in prefixLength..<new.count {
      levels[index].destination = snapshot.destinations[index]
      levels[index].operations.append(.present)
    }

    if prefixLength < old.count {
      levels[prefixLength].operations.append(.dismiss)
    }

    // Update idle levels (shared prefix) with latest destination data.
    for index in 0..<prefixLength {
      let new = snapshot.destinations[index]
      if let existing = levels[index].destination {
        if !existing.equalsDestination(new) {
          levels[index].destination = new
        }
      } else {
        levels[index].destination = new
      }
    }

    executeNextOperation()
  }
  
  private func executeNextOperation() {
    if let firstDismiss = levels.first(where: { $0.operations.contains(.dismiss) && $0.operation == nil }) {
      let idx = levels.firstIndex(where: { $0 === firstDismiss }) ?? -1
      firstDismiss.operation = .dismiss
    } else if let first = levels.first(where: { $0.operations.contains(.present) && $0.operation == nil }) {
      let idx = levels.firstIndex(where: { $0 === first }) ?? -1
      first.operation = .present
    } else {
      confirmAndAdvance()
    }
  }

  private func confirmAndAdvance() {
    if let snapshot = processingSnapshot {
      confirmedNavigationIDs = snapshot.navigationIDs
    }
    processingSnapshot = nil

    if let next = pendingSnapshots.first {
      pendingSnapshots.removeFirst()
      processSnapshot(next)
    }
  }
}
