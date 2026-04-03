import SwiftUI
import ManagedNavigation

struct PushNotificationsSettingsView: View {
  @Environment(\.navigator) private var navigator
  
  var id: String
  var isEnabled: Bool
  
  @State private var pushEnabled = true
  @State private var soundEnabled = true
  @State private var badgesEnabled = true
  @State private var previewStyle = "Always"
  @State private var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22)) ?? .now
  @State private var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7)) ?? .now
  
  private let previewStyles = ["Always", "When Unlocked", "Never"]
  
  var body: some View {
    List {
      // MARK: - Breadcrumbs
      Section {
        NavigationBreadcrumbs()
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
      }
      
      Group {
        // MARK: - ID
        Section {
          HStack {
            Text("Destination ID")
            Spacer()
            Text(id)
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
        
        // MARK: - General
        Section("General") {
          Toggle("Push Notifications", isOn: $pushEnabled)
          Toggle("Sounds", isOn: $soundEnabled)
            .disabled(!pushEnabled)
          Toggle("Badge Count", isOn: $badgesEnabled)
            .disabled(!pushEnabled)
          Picker("Preview Style", selection: $previewStyle) {
            ForEach(previewStyles, id: \.self) { Text($0) }
          }
          .disabled(!pushEnabled)
        }
        
        // MARK: - Quiet Hours
        Section("Quiet Hours") {
          DatePicker("From", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
          DatePicker("Until", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
        }
        
        // MARK: - Categories
        Section("Categories") {
          NotificationCategoryRow(icon: "envelope.fill", title: "Messages", color: .blue, enabled: true)
          NotificationCategoryRow(icon: "heart.fill", title: "Social", color: .pink, enabled: true)
          NotificationCategoryRow(icon: "cart.fill", title: "Purchases", color: .green, enabled: false)
          NotificationCategoryRow(icon: "megaphone.fill", title: "Marketing", color: .orange, enabled: false)
        }
        
        // MARK: - State Restoration
        Section("State Restoration") {
          StateRestorationGrid()
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        
        // MARK: - Actions
        Section {
          Button("Pop to Settings") {
            navigator?.popTo(SettingsDestination.self)
          }
          Button("Pop to Root") {
            navigator?.popToRoot()
          }
          .tint(.red)
        }
        .buttonStyle(.glass)
      }
      .disabled(!isEnabled)
    }
    .navigationTitle("Notifications")
    .macOSModifiers()
  }
}

private struct NotificationCategoryRow: View {
  let icon: String
  let title: String
  let color: Color
  @State var enabled: Bool
  
  var body: some View {
    Toggle(isOn: $enabled) {
      Label(title, systemImage: icon)
        .foregroundStyle(enabled ? color : .secondary)
    }
  }
}
