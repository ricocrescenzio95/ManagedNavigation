# ``ManagedNavigation``

Programmatic, type-safe navigation for SwiftUI apps.

![AppIcon](app-icon)

ManagedNavigation provides a thin layer on top of SwiftUI's `NavigationStack`
that gives you full programmatic control over the navigation path. Instead of
relying solely on `NavigationLink`, you can push, pop, and inspect destinations
using a centralized ``NavigationManager``.

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

// 3. Wrap your root view
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
- ``SwiftUICore/View/sheet(for:onDismiss:content:)``
- ``SwiftUICore/View/fullScreenCover(for:onDismiss:content:)``

### Saving and Restoring State

- ``NavigationManager/CodableRepresentation``
- ``NavigationManager/codable``
- ``NavigationManager/init(_:)-(CodableRepresentation)``
