import SwiftUI
import ManagedNavigation

struct IndexedDestination: Identifiable {
  var id: Int
  var destination: any NavigationDestination
}

struct NavigationBreadcrumbs: View {
  @Environment(\.navigator) private var navigator

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        let path = navigator?.path ?? []
        let items = path.enumerated().map {
          IndexedDestination(id: $0.offset, destination: $0.element)
        }
        LazyHStack(spacing: 6) {
          Button {
            navigator?.popToRoot()
          } label: {
            Text("Root")
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
          }
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .tint(path.isEmpty ? .accentColor : .secondary)

          ForEach(items) { item in
            Image(systemName: "chevron.right")
              .font(.system(size: 8, weight: .bold))
              .foregroundStyle(.tertiary)

            let isLast = item.id == path.count - 1
            Button {
              navigator?.popTo(where: { $0.index == item.id })
            } label: {
              HStack(spacing: 2) {
                Text("\(item.id + 1).")
                  .foregroundStyle(.tertiary)
                Text(String(describing: type(of: item.destination)))
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(isLast ? .accentColor : .secondary)
          }
        }
        .font(.caption2)
        .frame(height: 40)
        .padding(.horizontal)
      }
      .contentMargins(.horizontal, 4)
      .onChange(of: navigator?.path.count ?? 0, initial: true) { _, new in
        proxy.scrollTo(new - 1, anchor: .leading)
      }
    }
  }
}
