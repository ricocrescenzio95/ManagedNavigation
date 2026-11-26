# Getting Started with ManagedNavigation

Set up type-safe, programmatic navigation in your SwiftUI app.

## Overview

This guide walks you through the core concepts of ManagedNavigation:
defining destinations, setting up a navigation stack, pushing and popping
views, accessing navigation from child views, and reaching the navigators of
nested containers.

## Define Your Destinations

Conform a struct to ``NavigationDestination`` to make it a valid destination.
The protocol inherits from `Hashable` and provides a
``NavigationDestination/id`` for identifying destination kinds.

```swift
import ManagedNavigation

// A destination without parameters:
struct HomeDestination: NavigationDestination {}

// A destination with parameters:
struct DetailsDestination: NavigationDestination {
    var id: String
}
```

The default ``NavigationDestination/id`` is the `ObjectIdentifier` of the
type itself, which guarantees uniqueness across modules.

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

### Pushing Conditionally

Several variants push a destination only when a condition is met. They all
return a `Bool` that tells you whether the destination was actually pushed.

```swift
// Stack: [Home, Details(id: "abc")]

// Push only if an equal destination (same type and values) is not on the stack:
manager.pushIfNotPresent(DetailsDestination(id: "abc")) // false
manager.pushIfNotPresent(DetailsDestination(id: "xyz")) // true

// Push only if no destination of the same type is on the stack,
// regardless of its values:
manager.pushIfTypeNotPresent(DetailsDestination(id: "123")) // false
manager.pushIfTypeNotPresent(SettingsDestination())         // true

// Push only if the top of the stack is not equal to the destination.
// Useful to avoid duplicate pushes caused by double taps:
manager.pushIfNotOnTop(SettingsDestination()) // false

// Push only if a custom condition, evaluated on the current manager, is true:
manager.push(ProfileDestination(), if: { $0.count < 5 })
```

You can also pass an array to ``NavigationManager/pushIfNotPresent(_:)-(NavigationDestination)``
to push, in order, only the destinations that are not already on the stack.
Each destination is checked right before it is pushed, so duplicates inside
the array are skipped as well.

```swift
// Stack: [Home]
manager.pushIfNotPresent([
    HomeDestination(),             // skipped
    DetailsDestination(id: "abc"), // pushed
    DetailsDestination(id: "abc")  // skipped
])
// Stack: [Home, Details(id: "abc")]
```

### Popping

```swift
// Pop the last destination:
manager.pop()

// Pop a given number of destinations:
manager.pop(2)

// Pop to the root:
manager.popToRoot()

// Pop to the last occurrence of a type:
manager.popTo(HomeDestination.self)

// Pop to the first occurrence of a type:
manager.popToFirst(HomeDestination.self)

// Pop to a specific index:
manager.popTo(at: 0)

// Pop with a custom predicate, scanning from the bottom of the stack:
manager.popTo(where: { context in
    if let details = context.destination as? DetailsDestination {
        return details.id == "abc"
    }
    return false
})

// Pop with a custom predicate, scanning from the top of the stack:
manager.popToLast(where: { context in
    context.destination is HomeDestination
})

// Pop for as long as the destination on top satisfies a predicate:
// Stack: [Home, Details, Settings, Settings] → [Home, Details]
manager.pop(while: { $0 is SettingsDestination })
```

All pop methods return a `Bool` indicating whether the operation succeeded,
and are marked `@discardableResult` so you can ignore the return value when
you don't need it.

### Combining Push and Pop

Some navigation flows are "go back if you've already been there, otherwise
go forward". These methods cover that case in a single call:

```swift
// Stack: [Home, Details(id: "abc"), Settings]

// If an equal destination is on the stack, pop back to it; otherwise push.
// Returns true if pushed, false if popped.
manager.pushOrPopTo(DetailsDestination(id: "abc")) // false
// Stack: [Home, Details(id: "abc")]

// Same, but matching by type and ignoring values:
manager.pushOrPopToType(DetailsDestination(id: "other")) // false

// Clear the stack and push a single destination:
manager.popToRoot(thenPush: ProfileDestination())
// Stack: [Profile]
```

### Replacing, Inserting and Removing

```swift
// Replace the destination at a specific index:
manager.replace(ProfileDestination(id: "new"), at: 1)
// Stack: [Home, Details, Settings] → [Home, Profile, Settings]

// Replace the destination on top of the stack:
manager.replaceLast(with: SettingsDestination())

// Insert a destination at a specific index:
// Stack: [Home, Settings] → [Home, Details(id: "abc"), Settings]
manager.insert(DetailsDestination(id: "abc"), at: 1)

// Remove the destination at a specific index, keeping the ones above it:
// Stack: [Home, Details, Settings] → [Home, Settings]
manager.remove(at: 1)

// Remove all destinations of a type:
manager.removeAll(of: DetailsDestination.self)

// Remove all destinations equal to a given one:
manager.removeAll(DetailsDestination(id: "abc"))

// Replace the entire stack:
manager.setPath([HomeDestination(), DetailsDestination(id: "abc")])
```

The stack above the modified index is always preserved. Because
`NavigationPath` only supports append/removeLast, the path is rebuilt
from the modification index onward. The manager's ``NavigationManager/id``
and its transaction are preserved by these operations.

`setPath(_:)` combines well with ``NavigationManager/withoutAnimation(body:)``
for deep links, since the whole stack is rebuilt in a single step.

## Navigate from Child Views

Child views inside a ``ManagedNavigationStack`` or a ``ManagedPresentation``
can access the navigation through the
``SwiftUICore/EnvironmentValues/navigator`` environment value, which
provides a ``Navigator``:

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

``Navigator`` exposes the same push, pop, query and stack-modification
methods as ``NavigationManager``, including all the conditional and
combined variants described above:

```swift
navigator?.pushIfNotPresent(DetailsDestination(id: "hello"))
navigator?.pushOrPopTo(HomeDestination())
navigator?.popToRoot(thenPush: ProfileDestination())
```

## Identify Navigation Managers

Every ``NavigationManager`` has an ``NavigationManager/id``. By default a
random unique identifier is generated, but you can provide your own when
creating the manager:

```swift
@State var manager = NavigationManager(id: "main")

// With an initial path:
@State var manager = NavigationManager(
    [HomeDestination(), DetailsDestination(id: "abc")],
    id: "main"
)
```

The `id` is stable for the whole lifetime of the manager: the operations
that rebuild the stack, such as ``NavigationManager/replace(_:at:)`` and
``NavigationManager/setPath(_:)``, keep it unchanged.

### Access Ancestor Navigators by ID

When managed containers are nested (for example a ``ManagedNavigationStack``
inside a ``ManagedPresentation``, or a stack inside a presented sheet), the
``SwiftUICore/EnvironmentValues/navigator`` value only gives you the nearest
one. To reach the navigators of the containers further up the view
hierarchy, use the ``SwiftUICore/EnvironmentValues/navigators`` environment
value and look up the ``Navigator`` by the `id` of its manager.

Each ``ManagedNavigationStack`` and ``ManagedPresentation`` registers its
navigator in this container for all of its descendants, so `navigators`
contains the navigator of every ancestor container, plus the nearest one.

```swift
struct ContentView: View {
    @State var modalManager = NavigationManager(id: "modal")
    @State var stackManager = NavigationManager(id: "stack")

    var body: some View {
        ManagedPresentation(manager: $modalManager) {
            ManagedNavigationStack(manager: $stackManager) {
                RootView()
                    .navigationDestination(for: DetailsDestination.self) {
                        DetailsView(id: $0.id)
                    }
                    .sheet(for: SettingsDestination.self) { _ in
                        SettingsView()
                    }
            }
        }
    }
}

struct RootView: View {
    // The nearest navigator: the one of the stack.
    @Environment(\.navigator) private var navigator
    // Every ancestor navigator, looked up by manager id.
    @Environment(\.navigators) private var navigators

    var body: some View {
        VStack {
            Button("Push Details") {
                navigator?.push(DetailsDestination(id: "abc"))
            }
            Button("Open Settings") {
                // Drives the ManagedPresentation above the stack.
                navigators["modal"]?.push(SettingsDestination())
            }
        }
    }
}
```

The subscript returns `nil` when no navigator with that identifier is among
the ancestors of the view.

### Look Up Navigators by Kind or Position

You don't always know, or want to hard-code, the `id` of an ancestor's
manager. Every ``Navigator`` has a ``Navigator/kind``: ``Navigator/Kind/stack``
for a ``ManagedNavigationStack`` and ``Navigator/Kind/modal`` for a
``ManagedPresentation``. ``NavigatorsContainer`` uses it, and the position of
each container in the hierarchy, to find the navigator you need:

```swift
// Hierarchy: ManagedPresentation(root) > ManagedNavigationStack(a)
//            > ManagedPresentation(sheet) > ManagedNavigationStack(b)
@Environment(\.navigators) private var navigators

navigators.nearest              // Stack(b), same as \.navigator
navigators.outermost            // Presentation(root)
navigators.ancestor(1)          // Presentation(sheet)

navigators.nearestStack         // Stack(b)
navigators.nearestModal         // Presentation(sheet)
navigators.outermost(.modal)    // Presentation(root)
navigators.ancestor(1, of: .stack) // Stack(a)
navigators.navigators(of: .stack)  // [Stack(a), Stack(b)]
```

For example, to present a sheet from the nearest presentation, push onto the
stack one level further up, or dismiss every modal from anywhere:

```swift
Button("Open Settings") {
    navigators.nearestModal?.push(SettingsDestination())
}
Button("Show details on the outer stack") {
    navigators.ancestor(1, of: .stack)?.push(DetailsDestination(id: "abc"))
}
Button("Dismiss everything") {
    navigators.outermost(.modal)?.popToRoot()
}
```

To walk up from a navigator you already have, use
``NavigatorsContainer/parent(of:kind:)``. Pass a `kind` to skip enclosing
containers of the other kind:

```swift
if let stack = navigators.nearestStack {
    let presenter = navigators.parent(of: stack, kind: .modal)
}
```

Every lookup returns `nil` when no matching navigator is among the ancestors.
``NavigatorsContainer/count``, ``NavigatorsContainer/isEmpty`` and
``NavigatorsContainer/contains(_:)`` tell you what is available without
looking a navigator up.

> Note: Navigators are only collected going **down** the view hierarchy.
> Containers that are siblings (for example one ``ManagedNavigationStack``
> per tab of a `TabView`) cannot see each other's navigators. To coordinate
> them, share the managers from a common parent.

> Tip: Use meaningful, stable identifiers. If a nested container uses the
> same `id` as one of its ancestors, it shadows it: the lookup returns the
> innermost navigator.

## Inspect the Navigation Stack

You can inspect the current state of the stack through
``NavigationManager/path``:

```swift
Text("Stack depth: \(manager.path.count)")

ForEach(Array(manager.path.enumerated()), id: \.offset) { index, destination in
    Text("\(index): \(String(describing: type(of: destination)))")
}
```

### Query Helpers

Convenience members save you from accessing ``NavigationManager/path`` by hand:

```swift
manager.isEmpty // true if the stack has no destinations
manager.count   // number of destinations on the stack
manager.top     // the destination on top, or nil if the stack is empty

// Check by value (type and values) or by type:
manager.contains(DetailsDestination(id: "abc"))
manager.contains(DetailsDestination.self)

// Index of the last destination of a type:
manager.lastIndex(of: HomeDestination.self)

// The last destination of a type, already cast, to read its parameters:
if let details = manager.last(of: DetailsDestination.self) {
    print(details.id)
}
```

These are also available on ``Navigator``.

### Advanced Inspection

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

You can also use ``NavigationDestination/matchesDestination(_:)`` to check
whether two destinations are the same kind without casting:

```swift
manager.popTo(where: { context in
    context.destination.matchesDestination(HomeDestination())
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

> Tip: Presentations are identified by
> ``NavigationDestination/navigationID``, not by the full value of the
> destination. If you replace a destination in the path with another
> instance of the same type but different data, the presented sheet or
> cover updates its content in place without being dismissed and
> re-presented.

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
``NavigationManager/init(_:id:)-(CodableRepresentation,_)`` to rebuild the navigation stack.
Pass an `id` if you want the restored manager to keep a specific identifier:

```swift
func restoreNavigationState() -> NavigationManager {
    guard let data = UserDefaults.standard.data(forKey: "navigationState"),
          let representation = try? JSONDecoder().decode(
              NavigationManager.CodableRepresentation.self, from: data
          )
    else {
        return NavigationManager(id: "main")
    }
    return NavigationManager(representation, id: "main")
}
```

## Disable Animations

Use ``NavigationManager/withoutAnimation(body:)`` (or
``Navigator/withoutAnimation(body:)`` from child views) to perform
navigation changes without animation. This is especially useful for
state restoration or deep-link handling where animated transitions would
look jarring:

```swift
// On the manager
manager.withoutAnimation {
    $0.push([
        HomeDestination(),
        DetailsDestination(id: "abc"),
    ])
}

// From a child view
navigator?.withoutAnimation {
    $0.popToRoot()
}
```
