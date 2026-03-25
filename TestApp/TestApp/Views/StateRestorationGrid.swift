import SwiftUI
import ManagedNavigation

struct StateRestorationGrid: View {
  @Environment(\.navigator) private var navigator
  @AppStorage("savedPath") private var savedPath: Data?
  @State private var isPathInspectorOpen = false
  @State private var decodedPathCount = 0
  
  private var pathCount: Int { navigator?.path.count ?? 0 }
  private var hasSaved: Bool { savedPath != nil }
  private var canSave: Bool { navigator?.codable != nil }

  var body: some View {
    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
      // Save
      StateActionCard(
        title: "Save",
        detail: "\(pathCount) destination\(pathCount == 1 ? "" : "s")",
        icon: "square.and.arrow.down.fill",
        color: .green,
        disabled: !canSave
      ) {
        savedPath = try? JSONEncoder().encode(navigator?.codable)
      }

      // Restore
      StateActionCard(
        title: "Restore",
        detail: hasSaved ? "Apply \(decodedPathCount) destination(s)" : "No saved state",
        icon: "arrow.counterclockwise.circle.fill",
        color: .blue,
        disabled: !hasSaved
      ) {
        if let savedPath, let codable = try? JSONDecoder().decode(
          NavigationManager.CodableRepresentation.self, from: savedPath
        ) {
          navigator?.replace(codable)
        }
      }

      // Delete
      StateActionCard(
        title: "Delete",
        detail: hasSaved ? "Remove saved" : "Nothing saved",
        icon: "trash.fill",
        color: .red,
        disabled: !hasSaved
      ) {
        savedPath = nil
      }

      // Inspect JSON
      StateActionCard(
        title: "Inspect",
        detail: hasSaved ? "View JSON" : "Save first",
        icon: "doc.text.magnifyingglass",
        color: .purple,
        disabled: !hasSaved
      ) {
        isPathInspectorOpen = true
      }
      .sheet(isPresented: $isPathInspectorOpen) {
        PathInspectorView(path: $savedPath)
      }
    }
    .padding(.horizontal)
    .onChange(of: savedPath, initial: true) { _, savedPath in
      if let savedPath, let codable = try? JSONDecoder().decode(
        NavigationManager.CodableRepresentation.self, from: savedPath
      ) {
        decodedPathCount = NavigationManager(codable).path.count
      }
    }
  }
}

private struct StateActionCard: View {
  let title: String
  let detail: String
  let icon: String
  let color: Color
  var disabled: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: icon)
            .font(.title3)
            .foregroundStyle(disabled ? .secondary : color)
          Spacer()
        }
        Text(title)
          .font(.title3.bold())
          .foregroundStyle(disabled ? .secondary : .primary)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.leading)
      .lineLimit(1)
      .truncationMode(.middle)
      .padding(8)
    }
    .buttonBorderShape(.roundedRectangle(radius: 16))
    .buttonStyle(.glass)
    .disabled(disabled)
  }
}

struct PathInspectorView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var path: Data?

  var body: some View {
    NavigationStack {
      Group {
        if let path {
          if let json = prettyJSON(from: path) {
            ScrollView {
              Text(json)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
          } else {
            ContentUnavailableView(
              "Corrupted Data",
              systemImage: "exclamationmark.triangle",
              description: Text("The saved state could not be read.")
            )
          }
        } else {
          ContentUnavailableView(
            "No Saved State",
            systemImage: "tray",
            description: Text("Save the navigation state to inspect it here.")
          )
        }
      }
      .navigationTitle("Path Inspector")
      .safeAreaInset(edge: .bottom) {
        Button("Close") {
          dismiss()
        }
      }
    }
  }
  
  private func prettyJSON(from data: Data) -> String? {
    guard let object = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
          let string = String(data: pretty, encoding: .utf8)
    else {
      return String(data: data, encoding: .utf8)
    }
    return string
  }
}
