import SwiftUI
import ManagedNavigation

private struct MacOSModifiers: ViewModifier {
  @Environment(\.dismiss) private var dismiss
  var showClose: Bool
  
  func body(content: Content) -> some View {
#if os(macOS)
    content
      .frame(minWidth: 600, minHeight: 500)
      .toolbar {
        if showClose {
          ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
              dismiss()
            }
          }
        }
      }
#else
    content
#endif
  }
}

extension View {
  func macOSModifiers(showClose: Bool = true) -> some View {
    modifier(MacOSModifiers(showClose: showClose))
  }
}
