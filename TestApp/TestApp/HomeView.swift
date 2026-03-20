import SwiftUI
import ManagedNavigation

struct HomeView: View {
  @Environment(\.navigator) private var navigator
  
  @State private var categories = SampleData.categories
  @State private var searchText = ""
  
  var title: String
  
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
        
        Spacer(minLength: 40)
      }
    }
    .searchable(text: $searchText, prompt: "Search items...")
    .navigationTitle(title)
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
    .background(.bar)
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
  .init(id: "notifications", label: "Notifications", icon: "bell.badge.fill", color: .red, make: { PushNotificationsSettingsDestination(id: UUID()) }),
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
