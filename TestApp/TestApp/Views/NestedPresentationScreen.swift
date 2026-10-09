import Foundation
import ManagedNavigation
import SwiftUI

// Just a mock for a DI provider that modifies the environment of a view.

struct NestedTestModule: Sendable {
  var id: UUID
  var resolveValue: @Sendable () -> String
}

struct NestedTestContext: Sendable {
  var module: NestedTestModule
  var locale: Locale
  var calendar: Calendar
  var now: @Sendable () -> Date

  static func sample() -> NestedTestContext {
    NestedTestContext(
      module: .init(id: UUID(), resolveValue: { "test-context" }),
      locale: Locale(identifier: "it_IT"),
      calendar: Calendar(identifier: .gregorian),
      now: { .now }
    )
  }
}

private struct NestedContextStorageKey: EnvironmentKey {
  static let defaultValue: [ObjectIdentifier: any Sendable] = [:]
}

extension EnvironmentValues {
  var nestedContextStorage: [ObjectIdentifier: any Sendable] {
    get { self[NestedContextStorageKey.self] }
    set { self[NestedContextStorageKey.self] = newValue }
  }

  subscript<T: Sendable>(nestedContext type: T.Type) -> T? {
    get { nestedContextStorage[ObjectIdentifier(type)] as? T }
    set { nestedContextStorage[ObjectIdentifier(type)] = newValue }
  }
}

struct NestedContextEnvView<Content: View>: View {
  let context: NestedTestContext
  let content: () -> Content

  init(context: NestedTestContext, @ViewBuilder content: @escaping () -> Content) {
    self.context = context
    self.content = content
  }

  var body: some View {
    // Model a generic SwiftUI view that refreshes after it appears (for example,
    // when async data changes) while it also transforms the environment.
    content()
      .environment(\.locale, context.locale)
      .environment(\.calendar, context.calendar)
      .transformEnvironment(\.self) { environment in
        environment[nestedContext: NestedTestModule.self] = context.module
      }
  }
}

private struct NestedPresentationScreen<Next: NavigationDestination, D: View>: View {
  @Environment(\.navigator) private var navigator
  @Environment(\.nestedContextStorage) private var nestedContextStorage
  @State private var appeared = false
  
  let level: Int
  let nextDestination: Next?
  @ViewBuilder let destination: () -> D

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Text("Nested level \(level)")
          .accessibilityIdentifier("nested-level-\(level)")

        if let module = nestedContextStorage[ObjectIdentifier(NestedTestModule.self)] as? NestedTestModule {
          Text(module.resolveValue())
            .accessibilityIdentifier("nested-context-value")
        }

        if let nextDestination {
          Button("Open level \(level + 1)") {
            navigator?.push(nextDestination)
          }
          .accessibilityIdentifier("push-nested-level-\(level + 1)")
        }
        if appeared {
          Text("Appeared")
        }
      }
      .navigationTitle("Nested Level \(level)")
    }
    .onAppear {
      appeared = true
    }
    .sheet(for: Next.self) { _ in
      NestedContextEnvView(context: .sample()) {
        destination()
      }
    }
  }
}

struct NestedPresentationLevel1View: View {
  var body: some View {
    NestedPresentationScreen(level: 1, nextDestination: NestedLevel2Destination()) {
      NestedPresentationLevel2View()
    }
  }
}

private struct NestedPresentationLevel2View: View {
  var body: some View {
    NestedPresentationScreen(level: 2, nextDestination: NestedLevel3Destination()) {
      NestedPresentationLevel3View()
    }
  }
}

private struct NestedPresentationLevel3View: View {
  var body: some View {
    NestedPresentationScreen(level: 3, nextDestination: NestedLevel4Destination()) {
      NestedPresentationLevel4View()
    }
  }
}

private struct NestedPresentationLevel4View: View {
  var body: some View {
    NestedPresentationScreen(level: 4, nextDestination: nil as NestedLevel4Destination?) {}
  }
}
