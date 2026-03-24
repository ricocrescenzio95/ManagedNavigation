import SwiftUI
import ManagedNavigation

struct HomeView: View {
  @Environment(\.navigator) private var navigator
  
  @State private var categories = SampleData.categories
  @State private var searchText = ""
  
  var title: String
  var showClose: Bool
  
  private var filteredCategories: [Category] {
    if searchText.isEmpty { return categories }
    return categories.compactMap { category in
      let filtered = category.items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
      return filtered.isEmpty ? nil : Category(id: category.id, title: category.title, icon: category.icon, items: filtered)
    }
  }
  
  var body: some View {
    ScrollView {
      LazyVStack(spacing: 24, pinnedViews: .sectionHeaders) {
        // MARK: - Navigation Breadcrumbs
        Section {
          NavigationBreadcrumbs()
        } header: {
          SectionHeader(
            title: "Navigation",
            icon: "map.fill",
            description: "Current path breadcrumbs. Tap to pop back to any destination."
          )
        }
        
        // MARK: - Category Sections
        ForEach(filteredCategories) { category in
          Section {
            ScrollView(.horizontal) {
              LazyHStack(spacing: 12) {
                ForEach(category.items) { item in
                  CategoryItemCard(item: item)
                }
              }
              .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
          } header: {
            SectionHeader(
              title: category.title,
              icon: category.icon,
              description: "Tap any item to push its destination onto the navigation path."
            )
          }
        }
        
        // MARK: - State Restoration
        Section {
          StateRestorationGrid()
        } header: {
          SectionHeader(
            title: "State Restoration",
            icon: "externaldrive.fill",
            description: "Save, restore, delete or inspect the navigation state as JSON."
          )
        }
        
        // MARK: - Batch Push
        Section {
          BatchPushBuilder()
        } header: {
          SectionHeader(
            title: "Batch Push",
            icon: "square.stack.3d.up.fill",
            description: "Select destinations and push them all at once."
          )
        }

        // MARK: - Stress Tests
        Section {
          StressTestButtons()
        } header: {
          SectionHeader(
            title: "Stress Tests",
            icon: "bolt.fill",
            description: "Programmatic rapid sequences to exercise the presentation queue."
          )
        }

        Spacer(minLength: 40)
      }
    }
    .searchable(text: $searchText, prompt: "Search items...")
    .navigationTitle(title)
    .macOSModifiers(showClose: showClose)
  }
}

// MARK: - Models

private struct Category: Identifiable {
  let id: Int
  let title: String
  let icon: String
  let items: [CategoryItem]
}

private struct CategoryItem: Identifiable {
  let id: Int
  let title: String
  let subtitle: String
  let icon: String
  let color: Color
  let destination: any NavigationDestination
}

private struct Activity: Identifiable {
  let id: Int
  let title: String
  let detail: String
  let icon: String
  let color: Color
  let time: String
}

// MARK: - Sample Data

private enum SampleData {
  static let categories: [Category] = [
    Category(id: 1, title: "Sheets", icon: "rectangle.stack.fill", items: [
      CategoryItem(id: 1, title: "Settings", subtitle: "App settings", icon: "gearshape.fill", color: .blue, destination: SettingsDestination()),
      CategoryItem(id: 2, title: "Profile", subtitle: "User profile", icon: "person.fill", color: .purple, destination: ProfileDestination()),
      CategoryItem(id: 3, title: "Other Dashboard", subtitle: "Another dashboard", icon: "slider.horizontal.below.square.fill.and.square", color: .green, destination: HomeViewDestination()),
      
    ]),
    Category(id: 2, title: "Full Screen Covers", icon: "rectangle.fill", items: [
      CategoryItem(id: 10, title: "Account", subtitle: "Full screen", icon: "person.crop.rectangle.fill", color: .orange, destination: AccountDestination()),
    ]),
  ]
}

// MARK: - Subviews

private struct SectionHeader: View {
  let title: String
  let icon: String
  var description: String? = nil
  
  var body: some View {
    GlassEffectContainer {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Image(systemName: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text(title)
            .font(.headline)
          Spacer()
        }
        if let description {
          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
      .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal, 8)
    }
  }
}

private struct CategoryItemCard: View {
  @Environment(\.navigator) private var navigator
  let item: CategoryItem
  
  var body: some View {
    Button {
      navigator?.push(item.destination)
    } label: {
      VStack(spacing: 10) {
        Image(systemName: item.icon)
          .font(.title2)
          .foregroundStyle(.white)
          .frame(width: 56, height: 56)
          .background(item.color.gradient, in: .rect(cornerRadius: 14))

        VStack(spacing: 2) {
          Text(item.title)
            .font(.caption.bold())
            .lineLimit(1)
          Text(item.subtitle)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(width: 90)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("push-\(item.title.lowercased())")
  }
}

private struct DestinationOption: Identifiable {
  let id: String
  let label: String
  let icon: String
  let color: Color
  let make: () -> any NavigationDestination
}

private let availableDestinations: [DestinationOption] = [
  .init(id: "settings", label: "Settings", icon: "gearshape.fill", color: .blue, make: { SettingsDestination() }),
  .init(id: "profile", label: "Profile", icon: "person.fill", color: .purple, make: { ProfileDestination() }),
  .init(id: "account", label: "Account", icon: "person.crop.rectangle.fill", color: .orange, make: { AccountDestination() }),
  .init(id: "notifications", label: "Notifications", icon: "bell.badge.fill", color: .red, make: { PushNotificationsSettingsDestination(id: UUID().uuidString) }),
  .init(id: "dashboard", label: "Dashboard", icon: "slider.horizontal.below.square.fill.and.square", color: .green, make: { HomeViewDestination() }),
]

private struct BatchPushBuilder: View {
  @Environment(\.navigator) private var navigator
  @State private var selected: [DestinationOption] = []
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Available destinations as tappable chips
      FlowLayout(spacing: 8) {
        ForEach(availableDestinations) { option in
          Button {
            selected.append(option)
          } label: {
            Label(option.label, systemImage: option.icon)
              .font(.caption.bold())
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(option.color.opacity(0.15), in: .capsule)
              .foregroundStyle(option.color)
          }
          .buttonStyle(.plain)
        }
      }
      
      // Selected queue
      if !selected.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Queue (\(selected.count))")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
          
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              ForEach(Array(selected.enumerated()), id: \.offset) { index, option in
                HStack(spacing: 4) {
                  Image(systemName: option.icon)
                    .font(.caption2)
                  Text(option.label)
                    .font(.caption2)
                  Button {
                    selected.remove(at: index)
                  } label: {
                    Image(systemName: "xmark.circle.fill")
                      .font(.caption2)
                  }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(option.color.opacity(0.12), in: .capsule)
                .foregroundStyle(option.color)
              }
            }
          }
        }
      }
      
      // Actions
      HStack(spacing: 12) {
        Button {
          let destinations = selected.map { $0.make() }
          navigator?.push(destinations)
          selected.removeAll()
        } label: {
          Label("Push All", systemImage: "arrow.right.circle.fill")
            .font(.caption.bold())
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .disabled(selected.isEmpty)
        
        Button(role: .destructive) {
          selected.removeAll()
        } label: {
          Label("Clear", systemImage: "trash")
            .font(.caption.bold())
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .disabled(selected.isEmpty)
      }
    }
    .padding(.horizontal)
  }
}

private struct FlowLayout: Layout {
  var spacing: CGFloat = 8
  
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = computeRows(proposal: proposal, subviews: subviews)
    var height: CGFloat = 0
    for (i, row) in rows.enumerated() {
      let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
      height += rowHeight
      if i < rows.count - 1 { height += spacing }
    }
    return CGSize(width: proposal.width ?? 0, height: height)
  }
  
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let rows = computeRows(proposal: proposal, subviews: subviews)
    var y = bounds.minY
    for row in rows {
      let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
      var x = bounds.minX
      for subview in row {
        let size = subview.sizeThatFits(.unspecified)
        subview.place(at: CGPoint(x: x, y: y), proposal: .init(size))
        x += size.width + spacing
      }
      y += rowHeight + spacing
    }
  }
  
  private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
    let maxWidth = proposal.width ?? .infinity
    var rows: [[LayoutSubviews.Element]] = [[]]
    var currentWidth: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
        rows.append([])
        currentWidth = 0
      }
      rows[rows.count - 1].append(subview)
      currentWidth += size.width + spacing
    }
    return rows
  }
}

// MARK: - Stress Test Row

private struct StressTestRow: View {
  let sequence: (id: Int, title: String, description: String, expected: String)
  let status: String
  let action: () -> Void

  private var isRunning: Bool {
    status == "running-\(sequence.id)"
  }

  private var isDone: Bool {
    status == "done-\(sequence.id)"
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        ZStack {
          Circle()
            .fill(isDone ? .green : isRunning ? .orange : .mint)
            .frame(width: 28, height: 28)
          if isDone {
            Image(systemName: "checkmark")
              .font(.caption2.bold())
              .foregroundStyle(.white)
          } else if isRunning {
            ProgressView()
              .controlSize(.mini)
              .tint(.white)
          } else {
            Text("\(sequence.id)")
              .font(.caption2.bold())
              .foregroundStyle(.white)
          }
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(sequence.title)
            .font(.subheadline.bold())
          Text(sequence.description)
            .font(.caption2)
            .foregroundStyle(.secondary)
          Text("Expected: \(sequence.expected)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }

        Spacer()
      }
      .padding(.vertical, 6)
      .padding(.horizontal, 10)
      .background(.fill.quinary, in: .rect(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .disabled(isRunning)
    .accessibilityIdentifier("stress-sequence-\(sequence.id)")
  }
}

// MARK: - Stress Test Buttons

private struct StressTestButtons: View {
  @Environment(\.navigator) private var navigator
  @State private var status = "idle"

  private static let sequences: [(id: Int, title: String, description: String, expected: String)] = [
    (1,  "Push→Replace→Pop",
     "push([Settings, Profile, Account]) → replace([Settings, Account]) → pop()",
     "[Settings]"),
    (2,  "Push→PopToRoot→Push",
     "push([Settings, Profile]) → popToRoot → push(Account)",
     "[Account]"),
    (3,  "Rapid Single Pushes",
     "push(Settings) → push(Profile) → push(Account) with 200ms delays",
     "[Settings, Profile, Account]"),
    (4,  "Push→Replace(at:)→Push",
     "push([Settings, Profile]) → replace(Account, at: 0) → push(Settings)",
     "[Account, Profile, Settings]"),
    (5,  "FullScreen→Sheet→PopAll→Push",
     "push(Account fullscreen) → push(Settings sheet) → popToRoot → push(Profile)",
     "[Profile]"),
    (6,  "Deep Push→Rapid Pops",
     "push([Settings, Profile, Account]) → pop() × 3 (no delay)",
     "[] (root)"),
    (7,  "Data-Only Replace",
     "push(Settings) → replace(Settings, at: 0) same navigationID",
     "[Settings]"),
    (8,  "Empty→Full→Empty→Full",
     "push([Settings, Profile]) → popToRoot + push([Account, Settings]) → popToRoot + push(Profile)",
     "[Profile]"),
    (9,  "PopToRoot→Immediate Push",
     "push([Settings, Profile]) → popToRoot + push(Account) same tick",
     "[Account]"),
    (10, "Partial Pop",
     "push([Settings, Profile, Account]) → popTo(at: 0)",
     "[Settings]"),
    (11, "Immediate Replace",
     "push(Settings) → replace(Profile, at: 0) same tick",
     "[Profile]"),
    (12, "Pop 1→Push New",
     "push([Settings, Profile, Account]) → pop → push(Account)",
     "[Settings, Profile, Account]"),
    (13, "Double PopToRoot→Push",
     "popToRoot × 2 (empty) → push(Settings)",
     "[Settings]"),
    (14, "Interleaved Push-Pop",
     "push(Settings) → pop + push(Profile) → pop + push(Account)",
     "[Account]"),
    (15, "PopTo by Type",
     "push([Settings, Profile, Account]) → popTo(SettingsDestination.self)",
     "[Settings]"),
    (16, "Replace Full Path",
     "push([Settings, Profile]) → replace([Account, Settings])",
     "[Account, Settings]"),
    (17, "Duplicate NavigationID",
     "push(Settings) → push(Settings) → pop()",
     "[Settings]"),
    (18, "Pop During Present",
     "push([Settings, Profile, Account]) → immediate pop × 1",
     "[Settings, Profile]"),
    (19, "Recycled Levels",
     "push([Settings, Profile, Account]) → popToRoot → push(Profile)",
     "[Profile]"),
    (20, "Deep Registration Data Update",
     "push([Settings, PushNotifications(aaa)]) → replace PushNotifications(bbb) at: 1",
     "[Settings, Notifications] with updated id"),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Self.sequences, id: \.id) { seq in
        StressTestRow(
          sequence: seq,
          status: status,
          action: { runSequence(seq.id) }
        )
      }

      // For UITests completion
      Text(status)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("stress-status")
    }
    .padding(.horizontal)
  }

  private func runSequence(_ id: Int) {
    switch id {
    case 1:  runSequence1()
    case 2:  runSequence2()
    case 3:  runSequence3()
    case 4:  runSequence4()
    case 5:  runSequence5()
    case 6:  runSequence6()
    case 7:  runSequence7()
    case 8:  runSequence8()
    case 9:  runSequence9()
    case 10: runSequence10()
    case 11: runSequence11()
    case 12: runSequence12()
    case 13: runSequence13()
    case 14: runSequence14()
    case 15: runSequence15()
    case 16: runSequence16()
    case 17: runSequence17()
    case 18: runSequence18()
    case 19: runSequence19()
    case 20: runSequence20()
    default: break
    }
  }

  // Sequence 1: push([Settings, Profile, Account]) → sleep → replace with [Settings, Account] → sleep → pop
  // Expected final state: [Settings]
  private func runSequence1() {
    guard let navigator else { return }
    status = "running-1"
    navigator.push([SettingsDestination(), ProfileDestination(), AccountDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(150))
      navigator.replace([SettingsDestination(), AccountDestination()])
      try? await Task.sleep(for: .milliseconds(150))
      navigator.pop()
      status = "done-1"
    }
  }

  // Sequence 2: push([Settings, Profile]) → sleep → popToRoot → sleep → push(Account)
  // Expected final state: [Account]
  private func runSequence2() {
    guard let navigator else { return }
    status = "running-2"
    navigator.push([SettingsDestination(), ProfileDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(150))
      navigator.popToRoot()
      try? await Task.sleep(for: .milliseconds(150))
      navigator.push(AccountDestination())
      status = "done-2"
    }
  }

  // Sequence 3: push(Settings) → sleep → push(Profile) → sleep → push(Account)
  // Expected final state: [Settings, Profile, Account]
  private func runSequence3() {
    guard let navigator else { return }
    status = "running-3"
    navigator.push(SettingsDestination())
    Task {
      try? await Task.sleep(for: .milliseconds(200))
      navigator.push(ProfileDestination())
      try? await Task.sleep(for: .milliseconds(200))
      navigator.push(AccountDestination())
      status = "done-3"
    }
  }

  // Sequence 4: push([Settings, Profile]) → sleep → replace(Account, at: 0) → sleep → push(Settings)
  // Expected final state: [Account, Profile, Settings]
  private func runSequence4() {
    guard let navigator else { return }
    status = "running-4"
    navigator.push([SettingsDestination(), ProfileDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(200))
      navigator.replace(AccountDestination(), at: 0)
      try? await Task.sleep(for: .milliseconds(200))
      navigator.push(SettingsDestination())
      status = "done-4"
    }
  }

  // Sequence 5: push(Account fullscreen) → sleep → push(Settings sheet on top) → sleep → popToRoot → sleep → push(Profile)
  // Exercises fullScreenCover with a sheet layered on top, then clearing everything and pushing a sheet.
  // Expected final state: [Profile]
  private func runSequence5() {
    guard let navigator else { return }
    status = "running-5"
    navigator.push(AccountDestination())
    Task {
      try? await Task.sleep(for: .milliseconds(150))
      navigator.push(SettingsDestination())
      try? await Task.sleep(for: .milliseconds(150))
      navigator.popToRoot()
      try? await Task.sleep(for: .milliseconds(150))
      navigator.push(ProfileDestination())
      status = "done-5"
    }
  }

  // Sequence 6: push 3 destinations → sleep → pop → pop → pop rapidly (no sleeps between pops)
  // Exercises rapid successive pop() calls.
  // Expected final state: [] (root)
  private func runSequence6() {
    guard let navigator else { return }
    status = "running-6"
    navigator.push([SettingsDestination(), ProfileDestination(), AccountDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(300))
      navigator.pop()
      navigator.pop()
      navigator.pop()
      status = "done-6"
    }
  }

  // Sequence 7: push(Settings) → wait for it to appear → replace(Settings, at: 0)
  // Same navigationID → should be a data-only update, no dismiss/present.
  // The sheet should remain visible and stable.
  // Expected final state: [Settings] (still presented, never dismissed)
  private func runSequence7() {
    guard let navigator else { return }
    status = "running-7"
    navigator.push(SettingsDestination())
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      navigator.replace(SettingsDestination(), at: 0)
      try? await Task.sleep(for: .milliseconds(300))
      status = "done-7"
    }
  }

  // Sequence 8: push([Settings, Profile]) → sleep → popToRoot → push([Account, Settings]) → sleep → popToRoot → push(Profile)
  // Rapid full-stack replacement cycles.
  // Expected final state: [Profile]
  private func runSequence8() {
    guard let navigator else { return }
    status = "running-8"
    navigator.push([SettingsDestination(), ProfileDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(150))
      navigator.popToRoot()
      navigator.push([AccountDestination(), SettingsDestination()])
      try? await Task.sleep(for: .milliseconds(150))
      navigator.popToRoot()
      navigator.push(ProfileDestination())
      status = "done-8"
    }
  }

  // Sequence 9: push([Settings, Profile]) → sleep enough for presentation → popToRoot + immediate push(Account)
  // popToRoot and push happen in the same runloop tick — tests that dismiss and push are correctly queued.
  // Expected final state: [Account]
  private func runSequence9() {
    guard let navigator else { return }
    status = "running-9"
    navigator.push([SettingsDestination(), ProfileDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      navigator.popToRoot()
      navigator.push(AccountDestination())
      status = "done-9"
    }
  }

  // Sequence 10: push([Settings, Profile, Account]) → sleep → popTo(at: 0)
  // Partial pop: dismiss top 2 levels, keep bottom one.
  // Expected final state: [Settings]
  private func runSequence10() {
    guard let navigator else { return }
    status = "running-10"
    navigator.push([SettingsDestination(), ProfileDestination(), AccountDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      navigator.popTo(at: 0)
      status = "done-10"
    }
  }

  // Sequence 11: push(Settings) → immediate replace(Profile, at: 0)
  // Replace while the present animation hasn't started yet (same runloop tick).
  // The navigationID changes (Settings→Profile), so it should dismiss Settings and present Profile.
  // Expected final state: [Profile]
  private func runSequence11() {
    guard let navigator else { return }
    status = "running-11"
    navigator.push(SettingsDestination())
    navigator.replace(ProfileDestination(), at: 0)
    Task {
      try? await Task.sleep(for: .milliseconds(300))
      status = "done-11"
    }
  }

  // Sequence 12: push([Settings, Profile, Account]) → sleep → pop → sleep → push(Account)
  // Pop one level then push a new one. The stack goes [S, P, A] → [S, P] → [S, P, A].
  // Expected final state: [Settings, Profile, Account] — Account on top.
  private func runSequence12() {
    guard let navigator else { return }
    status = "running-12"
    navigator.push([SettingsDestination(), ProfileDestination(), AccountDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      navigator.pop()
      try? await Task.sleep(for: .milliseconds(500))
      navigator.push(AccountDestination())
      status = "done-12"
    }
  }

  // Sequence 13: popToRoot (already empty) → popToRoot again → sleep → push(Settings)
  // Double popToRoot on empty path must not crash or corrupt state.
  // Expected final state: [Settings]
  private func runSequence13() {
    guard let navigator else { return }
    status = "running-13"
    navigator.popToRoot()
    navigator.popToRoot()
    Task {
      try? await Task.sleep(for: .milliseconds(200))
      navigator.push(SettingsDestination())
      status = "done-13"
    }
  }

  // Sequence 14: push(S) → sleep → pop → push(P) → sleep → pop → push(A)
  // Interleaved push-pop cycles with different destinations each time.
  // Expected final state: [Account]
  private func runSequence14() {
    guard let navigator else { return }
    status = "running-14"
    navigator.push(SettingsDestination())
    Task {
      try? await Task.sleep(for: .milliseconds(200))
      navigator.popToRoot()
      navigator.push(ProfileDestination())
      try? await Task.sleep(for: .milliseconds(200))
      navigator.popToRoot()
      navigator.push(AccountDestination())
      status = "done-14"
    }
  }

  // Sequence 15: push([Settings, Profile, Account]) → sleep → popTo(SettingsDestination.self)
  // Uses type-based popTo to dismiss everything above Settings.
  // Expected final state: [Settings]
  private func runSequence15() {
    guard let navigator else { return }
    status = "running-15"
    navigator.push([SettingsDestination(), ProfileDestination(), AccountDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      navigator.popTo(SettingsDestination.self)
      status = "done-15"
    }
  }

  // Sequence 16: push([Settings, Profile]) → sleep → replace([Account, Settings])
  // Full path replacement via replace(_ destinations:).
  // Expected final state: [Account, Settings]
  private func runSequence16() {
    guard let navigator else { return }
    status = "running-16"
    navigator.push([SettingsDestination(), ProfileDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      navigator.replace([AccountDestination(), SettingsDestination()])
      status = "done-16"
    }
  }

  // Sequence 17: push(Settings) → sleep → push(Settings) again → sleep → pop()
  // Duplicate navigationID: two sheets of the same type stacked.
  // Expected final state: [Settings] (one Settings remains)
  private func runSequence17() {
    guard let navigator else { return }
    status = "running-17"
    navigator.push(SettingsDestination())
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      navigator.push(SettingsDestination())
      try? await Task.sleep(for: .milliseconds(500))
      navigator.pop()
      status = "done-17"
    }
  }

  // Sequence 18: push([Settings, Profile, Account]) → immediate pop()
  // Pop while present animations are still in flight.
  // Expected final state: [Settings, Profile]
  private func runSequence18() {
    guard let navigator else { return }
    status = "running-18"
    navigator.push([SettingsDestination(), ProfileDestination(), AccountDestination()])
    navigator.pop()
    Task {
      try? await Task.sleep(for: .milliseconds(300))
      status = "done-18"
    }
  }

  // Sequence 19: push([Settings, Profile, Account]) → sleep → popToRoot → sleep → push(Profile)
  // Verifies that levels are recycled correctly after a deep stack is fully dismissed.
  // Expected final state: [Profile]
  private func runSequence19() {
    guard let navigator else { return }
    status = "running-19"
    navigator.push([SettingsDestination(), ProfileDestination(), AccountDestination()])
    Task {
      try? await Task.sleep(for: .milliseconds(500))
      navigator.popToRoot()
      try? await Task.sleep(for: .milliseconds(500))
      navigator.push(ProfileDestination())
      status = "done-19"
    }
  }

  // Sequence 20: push([Settings, PushNotifications(id:"aaa")]) → sleep → replace PushNotifications(id:"bbb") at: 1
  // PushNotificationsSettingsDestination is registered inside SettingsView (deep registration).
  // Same navigationID, different data → no dismiss/present, just data update in place.
  // Expected final state: [Settings, Notifications] with id updated to "bbb"
  private func runSequence20() {
    guard let navigator else { return }
    status = "running-20"
    navigator.push([SettingsDestination(), PushNotificationsSettingsDestination(id: "aaa")])
    Task {
      try? await Task.sleep(for: .milliseconds(1500))
      navigator.replace(PushNotificationsSettingsDestination(id: "bbb"), at: 1)
      try? await Task.sleep(for: .milliseconds(500))
      status = "done-20"
    }
  }
}
