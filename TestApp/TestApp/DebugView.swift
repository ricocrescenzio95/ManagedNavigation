import SwiftUI
import ManagedNavigation

struct DebugView: View {
  @Environment(\.navigator) private var navigator: NavigationProxy!

  @Binding var path: Data?
  @State private var isPathInspectorOpen = false
  @State private var toast: Toast?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // MARK: - State Restoration
      VStack(alignment: .leading, spacing: 6) {
        Label("State Restoration", systemImage: "externaldrive")
          .font(.caption.bold())
          .foregroundStyle(.secondary)
        
        HStack(spacing: 12) {
          Button {
            path = try? JSONEncoder().encode(navigator.codable)
            showToast("State saved", icon: "checkmark.circle.fill", tint: .green)
          } label: {
            Label("Save", systemImage: "square.and.arrow.down")
          }
          .disabled(navigator?.codable == nil)
          
          Button {
            if let path, let codable = try? JSONDecoder().decode(
              NavigationManager.CodableRepresentation.self, from: path
            ) {
              navigator?.replace(codable)
              showToast("State restored", icon: "arrow.counterclockwise.circle.fill", tint: .blue)
            }
          } label: {
            Label("Restore", systemImage: "arrow.counterclockwise")
          }
          .disabled(path == nil)
          
          Button(role: .destructive) {
            path = nil
            showToast("State deleted", icon: "trash.fill", tint: .red)
          } label: {
            Label("Delete", systemImage: "trash")
          }
          .disabled(path == nil)
          
          Spacer()
          
          Button {
            isPathInspectorOpen = true
          } label: {
            Label("JSON", systemImage: "doc.text.magnifyingglass")
          }
          .sheet(isPresented: $isPathInspectorOpen) {
            PathInspectorView(path: $path)
          }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
      }
      
      Divider()
      
      // MARK: - Path
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 4) {
          Label("Path", systemImage: "map")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
          
          Text("(\(navigator.path.count))")
            .foregroundStyle(.tertiary)
            .font(.caption2)
          
          if navigator.path.isEmpty {
            Text("— root")
              .foregroundStyle(.tertiary)
              .font(.caption2)
          }
        }
        
        ScrollView(.horizontal, showsIndicators: false) {
          let items = navigator.path.enumerated().map {
            IndexedDestination(id: $0.offset, destination: $0.element)
          }
          HStack(spacing: 6) {
            BreadcrumbButton(label: "Root", index: nil, isActive: navigator.path.isEmpty) {
              navigator.popToRoot()
            }
            
            ForEach(items) { item in
              Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.tertiary)
              
              let isLast = item.id == navigator.path.count - 1
              BreadcrumbButton(
                label: String(describing: type(of: item.destination)),
                index: item.id,
                isActive: isLast
              ) {
                navigator.popTo(where: { context in
                  context.index == item.id
                })
              }
            }
          }
        }
        .contentMargins(.horizontal, 4)
      }
    }
    .padding()
    .glassEffect(.regular, in: .rect(cornerRadius: 16))
    .padding(.horizontal)
    .padding(.bottom, 4)
    .font(.caption2)
    .overlay(alignment: .top) {
      if let toast {
        ToastView(toast: toast)
          .transition(.blurReplace)
          .offset(y: -50)
      }
    }
    .animation(.snappy, value: toast)
  }
  
  private func showToast(_ message: String, icon: String, tint: Color) {
    toast = Toast(message: message, icon: icon, tint: tint)
    Task {
      try? await Task.sleep(for: .seconds(1.5))
      if self.toast?.message == message {
        self.toast = nil
      }
    }
  }
}

private struct Toast: Equatable {
  var message: String
  var icon: String
  var tint: Color
}

private struct ToastView: View {
  var toast: Toast
  
  var body: some View {
    Label(toast.message, systemImage: toast.icon)
      .font(.caption.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(toast.tint.gradient, in: .capsule)
      .shadow(color: toast.tint.opacity(0.3), radius: 8, y: 4)
  }
}

private struct BreadcrumbButton: View {
  var label: String
  var index: Int?
  var isActive: Bool = false
  var action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack(spacing: 2) {
        if let index {
          Text("\(index + 1).")
            .foregroundStyle(.tertiary)
        }
        Text(label)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
    }
    .buttonStyle(.bordered)
    .buttonBorderShape(.capsule)
    .tint(isActive ? .accentColor : .secondary)
  }
}

struct PathInspectorView: View {
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
      #if !os(macOS) && !os(tvOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        if path != nil {
          ToolbarItem(placement: .destructiveAction) {
            Button("Delete", role: .destructive) {
              path = nil
            }
          }
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
