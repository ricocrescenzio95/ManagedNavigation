# Getting Started with ManagedNavigation

Set up type-safe, programmatic navigation in your SwiftUI app.

## Overview

This guide walks you through the core concepts of ManagedNavigation:
defining destinations, setting up a navigation stack, pushing and popping
views, and accessing navigation from child views.

## Define Your Destinations

Conform a struct to ``NavigationDestination`` to make it a valid destination.
The protocol inherits from `Hashable` and provides a
``NavigationDestination/navigationID`` for identifying destination kinds.

```swift
import ManagedNavigation

// A destination without parameters:
struct HomeDestination: NavigationDestination {}

// A destination with parameters:
struct DetailsDestination: NavigationDestination {
    var id: String
}
```

The default ``NavigationDestination/navigationID`` is the type name as a
`String`. You can customize it if needed:

```swift
struct SettingsDestination: NavigationDestination {
    static var navigationID: String { "settings" }
}
```

## Set Up the Navigation Stack

Create a ``NavigationManager`` as `@State` and pass it to
``ManagedNavigationStack``. Register your destinations using
SwiftUI's `.navigationDestination(for:)` modifier inside the root view.

```swift
struct ContentView: View {
    @State var manager = NavigationManager()

    var body: some View {
        ManagedNavigationStack(manager: $manager) {
            VStack {
                Button("Go Home") {
                    manager.push(HomeDestination())
                }
                Button("Go to Details") {
                    manager.push(DetailsDestination(id: "abc"))
                }
            }
            .navigationDestination(for: HomeDestination.self) { _ in
                HomeView()
            }
            .navigationDestination(for: DetailsDestination.self) {
                DetailsView(id: $0.id)
            }
        }
    }
}
```

## Push and Pop Destinations

``NavigationManager`` provides several ways to navigate:

### Pushing

```swift
// Push a single destination:
manager.push(DetailsDestination(id: "abc"))

// Push multiple destinations at once:
manager.push([HomeDestination(), DetailsDestination(id: "abc")])
```

### Popping

```swift
// Pop the last destination:
manager.pop()

// Pop to the root:
manager.popToRoot()

// Pop to the last occurrence of a type:
manager.popTo(HomeDestination.self)

// Pop to the first occurrence of a type:
manager.popToFirst(HomeDestination.self)

// Pop to a specific index:
manager.popTo(at: 0)

// Pop with a custom predicate:
manager.popTo(where: { context in
    if let details = context.destination as? DetailsDestination {
        return details.id == "abc"
    }
    return false
})
```

All pop methods return a `Bool` indicating whether the operation succeeded,
and are marked `@discardableResult` so you can ignore the return value when
you don't need it.

## Navigate from Child Views

Child views inside a ``ManagedNavigationStack`` can access the navigation
through the ``SwiftUICore/EnvironmentValues/navigator`` environment value, which
provides a ``NavigationProxy``:

```swift
struct HomeView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        Button("Go to Details") {
            navigator?.push(DetailsDestination(id: "hello"))
        }
    }
}
```

``NavigationProxy`` exposes the same push and pop methods as
``NavigationManager``.

## Inspect the Navigation Stack

You can inspect the current state of the stack through
``NavigationManager/path``:

```swift
Text("Stack depth: \(manager.path.count)")

ForEach(Array(manager.path.enumerated()), id: \.offset) { index, destination in
    Text("\(index): \(String(describing: type(of: destination)))")
}
```

For advanced inspection during pop operations, use ``NavigationManager/popTo(where:)``
with a ``NavigationManager/NavigationScanContext``:

```swift
manager.popTo(where: { context in
    // Access the full path
    let total = context.path.count

    // Cast the current destination to a specific type
    if let details = context.destination as? DetailsDestination {
        return details.id == "target"
    }
    return false
})
```

You can also inspect the ``NavigationManager/NavigationScanContext/destinationID``
to identify destination kinds without casting:

```swift
manager.popTo(where: { context in
    context.destinationID == "HomeDestination"
})
```
## Present Sheets and Full-Screen Covers

``ManagedPresentation`` lets you drive modal presentations from the same
``NavigationManager`` path. Register destinations with
``SwiftUICore/View/sheet(for:onDismiss:content:)`` or
``SwiftUICore/View/fullScreenCover(for:onDismiss:content:)``, then push
destinations onto the manager to present them.

```swift
@State var manager = NavigationManager()

ManagedPresentation(manager: $manager) {
    VStack {
        Button("Open Settings") {
            manager.push(SettingsDestination())
        }
        Button("Open Profile") {
            manager.push(ProfileDestination())
        }
    }
    .sheet(for: SettingsDestination.self) { _ in
        SettingsView()
    }
    .sheet(for: ProfileDestination.self) { _ in
        ProfileView()
    }
}
```

### Nested Presentations

Presentations can be nested: if the presented view also registers
destinations with `.sheet(for:)`, pushing multiple destinations will
present them as a stack of modals.

```swift
ManagedPresentation(manager: $manager) {
    RootView()
        .sheet(for: SettingsDestination.self) { _ in
            SettingsView()
                .sheet(for: NotificationsDestination.self) { _ in
                    NotificationsView()
                }
        }
}

// Present Settings, then Notifications on top:
manager.push([SettingsDestination(), NotificationsDestination()])
```

Child views inside presented sheets can use the
``SwiftUICore/EnvironmentValues/navigator`` environment value to push and
pop destinations, just like in a ``ManagedNavigationStack``.

## Save and Restore the Navigation Stack

If all your destinations conform to `Codable`, you can serialize the entire
navigation stack for persistence. This works just like
`NavigationPath.CodableRepresentation`.

### Making Destinations Codable

Add `Codable` conformance alongside ``NavigationDestination``:

```swift
struct HomeDestination: NavigationDestination, Codable {}

struct DetailsDestination: NavigationDestination, Codable {
    var id: String
}
```

### Saving State

Use the ``NavigationManager/codable`` property to get a serializable snapshot.
It returns `nil` if any destination in the stack is not `Codable`.

```swift
func saveNavigationState() {
    guard let representation = manager.codable else { return }
    if let data = try? JSONEncoder().encode(representation) {
        UserDefaults.standard.set(data, forKey: "navigationState")
    }
}
```

### Restoring State

Decode a ``NavigationManager/CodableRepresentation`` and pass it to
``NavigationManager/init(_:)-(CodableRepresentation)`` to rebuild the navigation stack:

```swift
func restoreNavigationState() -> NavigationManager {
    guard let data = UserDefaults.standard.data(forKey: "navigationState"),
          let representation = try? JSONDecoder().decode(
              NavigationManager.CodableRepresentation.self, from: data
          )
    else {
        return NavigationManager()
    }
    return NavigationManager(representation)
}
```

