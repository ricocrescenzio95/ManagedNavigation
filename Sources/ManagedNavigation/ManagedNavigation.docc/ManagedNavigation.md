# ``ManagedNavigation``

Programmatic, type-safe navigation for SwiftUI apps.

![AppIcon](app-icon)

ManagedNavigation provides a thin layer on top of SwiftUI's `NavigationStack`
and modal presentations that gives you full programmatic control over push
navigation, sheets, and full-screen covers. Instead of relying on
`NavigationLink` or managing separate `@State` booleans for each modal, you
drive everything through a centralized ``NavigationManager``.

Key features:

- **Protocol-based destinations** — Conform your types to
  ``NavigationDestination``. Each destination type gets a
  ``NavigationDestination/id`` for identification.
- **Programmatic navigation** — Push and pop destinations from anywhere using
  ``NavigationManager`` or the ``Navigator`` environment value.
- **Rich pop operations** — Pop to a specific type, index, or use a custom
  predicate with ``NavigationManager/NavigationScanContext``.
- **Batch push** — Push multiple destinations in a single call.
- **Modal presentations** — Drive sheets and full-screen covers from the same
  path-based model using ``ManagedPresentation``.
- **State persistence** — Save and restore the navigation stack via
  ``NavigationManager/CodableRepresentation``.

## Quick Start

```swift
import ManagedNavigation

// 1. Define your destinations
struct HomeDestination: NavigationDestination {}

struct DetailsDestination: NavigationDestination {
    var id: String
}

// 2. Create a NavigationManager
@State var manager = NavigationManager()

// 3a. Push navigation
ManagedNavigationStack(manager: $manager) {
    Button("Go to Details") {
        manager.push(DetailsDestination(id: "abc"))
    }
    .navigationDestination(for: HomeDestination.self) { _ in
        HomeView()
    }
    .navigationDestination(for: DetailsDestination.self) {
        DetailsView(id: $0.id)
    }
}

// 3b. Modal presentations
ManagedPresentation(manager: $manager) {
    Button("Open Settings") {
        manager.push(SettingsDestination())
    }
    .sheet(for: SettingsDestination.self) { context in
        SettingsView()
    }
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``ManagedNavigationStack``
- ``NavigationManager``

### Defining Destinations

- ``NavigationDestination``

### Navigating from Child Views

- ``Navigator``
- ``SwiftUICore/EnvironmentValues/navigator``

### Inspecting the Stack

- ``NavigationManager/path``
- ``NavigationManager/NavigationScanContext``

### Modal Presentations

- ``ManagedPresentation``
- ``PresentationContext``
- ``SwiftUICore/View/sheet(for:onDismiss:content:)``
- ``SwiftUICore/View/fullScreenCover(for:onDismiss:content:)``

### Saving and Restoring State

- ``NavigationManager/CodableRepresentation``
- ``NavigationManager/codable``
- ``NavigationManager/init(_:)-(CodableRepresentation)``
