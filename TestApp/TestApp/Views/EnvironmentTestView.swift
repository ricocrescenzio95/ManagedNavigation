import SwiftUI
import ManagedNavigation

enum CustomEnvironment: String {
  case `default`
  case modified
}
extension EnvironmentValues {
  @Entry var customEnvironment = CustomEnvironment.default
}

struct EnvironmentTestDestination: NavigationDestination {}

struct EnvironmentTestView: View {
  @Environment(\.navigator) private var navigator
  @Environment(\.customEnvironment) private var environment

  @State private var notificationsEnabled = true
  @State private var darkMode = false
  @State private var autoSave = true
  @State private var selectedLanguage = "English"
  @State private var cacheSize = 50.0
  
  private let languages = ["English", "Italian", "Spanish", "French", "German"]
  
  var body: some View {
    List {
      // MARK: - Breadcrumbs
      Section {
        NavigationBreadcrumbs()
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
      }
      // MARK: - Main
      Section("Environment") {
        Text(environment.rawValue)
          .accessibilityIdentifier("environment-parent-value")
        Button("Open child") {
          navigator?.push(InheritEnvironmentTestDestination())
        }
        .accessibilityIdentifier("environment-open-child")
      }
    }
    .navigationTitle("Environment Parent")
    .sheet(for: InheritEnvironmentTestDestination.self) { _ in
      NavigationStack {
        InheritEnvironmentTestView()
      }
    }
    .navigationDestination(for: InheritEnvironmentTestDestination.self) { _ in
      InheritEnvironmentTestView()
    }
  }
}

private struct InheritEnvironmentTestDestination: NavigationDestination {}

private struct InheritEnvironmentTestView: View {
  @Environment(\.customEnvironment) private var environment
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    List {
      // MARK: - Breadcrumbs
      Section {
        NavigationBreadcrumbs()
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
      }
      // MARK: - Main
      Section("Environment") {
        Text(environment.rawValue)
          .accessibilityIdentifier("environment-child-value")
        Button("Dismiss") {
          dismiss()
        }
        .accessibilityIdentifier("environment-dismiss-child")
      }
    }
    .navigationTitle("Environment Child")
  }
}
