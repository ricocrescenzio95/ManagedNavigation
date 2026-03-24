import SwiftUI
import ManagedNavigation

struct ProfileView: View {
  @Environment(\.navigator) private var navigator
  
  @State private var displayName = "Jane Doe"
  @State private var bio = "iOS developer & coffee enthusiast"
  @State private var isEditing = false
  
  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        // MARK: - Breadcrumbs
        NavigationBreadcrumbs()
        
        // MARK: - Avatar
        VStack(spacing: 12) {
          Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 80))
            .foregroundStyle(.blue.gradient)
          
          if isEditing {
            TextField("Display Name", text: $displayName)
              .textFieldStyle(.roundedBorder)
              .multilineTextAlignment(.center)
              .frame(maxWidth: 220)
          } else {
            Text(displayName)
              .font(.title2.bold())
          }
          
          Text("jane.doe@example.com")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.top)
        
        // MARK: - Bio
        GroupBox("Bio") {
          if isEditing {
            TextField("Bio", text: $bio, axis: .vertical)
              .lineLimit(3...6)
          } else {
            Text(bio)
              .frame(maxWidth: .infinity, alignment: .leading)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal)
        
        // MARK: - Stats
        GroupBox("Stats") {
          LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 16) {
            StatItem(value: "128", label: "Posts")
            StatItem(value: "4.2K", label: "Followers")
            StatItem(value: "312", label: "Following")
          }
        }
        .padding(.horizontal)
        
        // MARK: - Preferences
        GroupBox("Preferences") {
          VStack(spacing: 0) {
            PreferenceRow(icon: "bell.fill", title: "Notifications", detail: "On", color: .red)
            Divider()
            PreferenceRow(icon: "lock.fill", title: "Privacy", detail: "Friends Only", color: .blue)
            Divider()
            PreferenceRow(icon: "paintbrush.fill", title: "Theme", detail: "System", color: .purple)
          }
        }
        .padding(.horizontal)
        
        // MARK: - State Restoration
        StateRestorationGrid()
        
        // MARK: - Actions
        VStack(spacing: 12) {
          Button("Pop") {
            navigator?.pop()
          }
          .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        
        Spacer(minLength: 40)
      }
    }
    .navigationTitle("Profile")
    .toolbar {
      Button(isEditing ? "Done" : "Edit") {
        withAnimation { isEditing.toggle() }
      }
    }
    .macOSModifiers()
  }
}

private struct StatItem: View {
  let value: String
  let label: String
  
  var body: some View {
    VStack(spacing: 4) {
      Text(value)
        .font(.title3.bold())
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct PreferenceRow: View {
  let icon: String
  let title: String
  let detail: String
  let color: Color
  
  var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 24)
      Text(title)
      Spacer()
      Text(detail)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 8)
  }
}
