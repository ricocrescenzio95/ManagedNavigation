# ManagedNavigation

### Programmatic navigation management for SwiftUI

<p>
  <a href="https://github.com/ricocrescenzio95/ManagedNavigation/releases">
    <img src="https://img.shields.io/github/v/release/ricocrescenzio95/ManagedNavigation?include_prereleases&label=Swift%20Package%20Manager">
  </a>
  <a href="https://swiftpackageindex.com/ricocrescenzio95/ManagedNavigation">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fricocrescenzio95%2FManagedNavigation%2Fbadge%3Ftype%3Dswift-versions">
  </a>
  <a href="https://swiftpackageindex.com/ricocrescenzio95/ManagedNavigation">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fricocrescenzio95%2FManagedNavigation%2Fbadge%3Ftype%3Dplatforms">
  </a>
  <a href="https://saythanks.io/to/rico.crescenzio">
    <img src="https://img.shields.io/badge/SayThanks.io-%E2%98%BC-1EAEDB.svg">
  </a>
  <a href="https://www.paypal.com/donate/?hosted_button_id=RWDBC8TS5CNVA">
    <img src="https://img.shields.io/badge/$-donate-ff69b4.svg?maxAge=2592000&amp;style=flat">
  </a>
</p>

## Why ManagedNavigation?

SwiftUI's `NavigationStack` and `NavigationPath` give you the building blocks for programmatic navigation, but they leave significant gaps when building real apps:

- **`NavigationPath` is opaque** — you can append and remove items, but you can't inspect the stack content. Want to know what's at position 2? Or find the last occurrence of a certain screen? You can't.
- **No typed pop operations** — there's no `popTo(SettingsScreen.self)` or `popToFirst(HomeScreen.self)`. You can only `removeLast(_:)` by count, so you need to track positions yourself.
- **No pop-by-predicate** — navigating back to "the first screen where condition X is true" requires manual bookkeeping.
- **No unified modal management** — `NavigationPath` drives push navigation only. Sheets and full-screen covers use separate `@State` bindings with no coordination.
- **No state persistence out of the box** — `NavigationPath.CodableRepresentation` exists but only encodes opaque data. Restoring a path requires re-registering every type, and there's no way to inspect what was saved.
- **Deep links are fragile** — pushing multiple destinations at once works, but coordinating that with modals or knowing exactly where you are in the stack is left entirely to you.

ManagedNavigation solves all of this with a thin layer that keeps a **typed `[any NavigationDestination]` array** in sync with `NavigationPath`, giving you full visibility and control over your navigation state.

## Features

- **Typed navigation path** — inspect any destination by index, type-check, cast, iterate
- **Push single or multiple destinations** in one call
- **Pop to type** — `popTo(HomeDestination.self)` pops to the last occurrence
- **Pop to first** — `popToFirst(HomeDestination.self)` pops to the first occurrence
- **Pop by predicate** — `popTo(where: { $0.destination is DetailsDestination })` for custom logic
- **Pop by index** — `popTo(at: 2)` with optional type safety via `popTo(HomeDestination.self, at: 2)`
- **Modal presentations** — sheets and full-screen covers driven by the same path, with nested presentation support
- **State persistence** — `Codable` representation that preserves type information, encode/decode with any encoder
- **Environment-based proxy** — child views navigate via `@Environment(\.navigator)` without coupling to the manager

## Installation

`ManagedNavigation` can be installed using Swift Package Manager.

1. In Xcode open **File/Swift Packages/Add Package Dependency...** menu.

2. Copy and paste the package URL:

```
https://github.com/ricocrescenzio95/ManagedNavigation
```

For more details refer to [Adding Package Dependencies to Your App](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app) documentation.

## Usage

### Navigation Stack

Use `ManagedNavigationStack` to wrap SwiftUI's `NavigationStack` with a typed, programmatic path:

```swift
@State var manager = NavigationManager()

ManagedNavigationStack(manager: $manager) {
    Button("Go to Details") {
        manager.push(DetailsDestination(id: "abc"))
    }
    .navigationDestination(for: DetailsDestination.self) { destination in
        DetailsView(id: destination.id)
    }
}
```

### Pop Operations

This is where ManagedNavigation shines — operations that SwiftUI simply doesn't offer:

```swift
// Pop to the last occurrence of a type
manager.popTo(HomeDestination.self)

// Pop to the first occurrence
manager.popToFirst(HomeDestination.self)

// Pop with a custom predicate
manager.popTo(where: { context in
    context.destination is DetailsDestination && context.index > 0
})

// Pop to a specific index (with type safety)
manager.popTo(HomeDestination.self, at: 2)

// Inspect the stack at any time
for (i, destination) in manager.path.enumerated() {
    print("\(i): \(destination.navigationID)")
}
```

### Modal Presentations

Use `ManagedPresentation` to manage sheets and full-screen covers with the same path-driven approach — no more juggling separate `@State` booleans:

```swift
@State var manager = NavigationManager()

ManagedPresentation(manager: $manager) {
    Button("Open Settings") {
        manager.push(SettingsDestination())
    }
    .sheet(for: SettingsDestination.self) { _ in
        SettingsView()
    }
    .fullScreenCover(for: AccountDestination.self) { _ in
        AccountView()
    }
}
```

Presentations nest automatically. If `SettingsView` registers its own `.sheet(for:)`, pushing the corresponding destination presents it on top:

```swift
// Push a chain of modals in one call
manager.push([
    SettingsDestination(),
    NotificationsDestination(),
])
// Result: Settings sheet appears, then Notifications sheet on top
```

### Destinations

Define your destinations by conforming to `NavigationDestination`. Add `Codable` for state persistence:

```swift
struct DetailsDestination: NavigationDestination, Codable {
    var id: String
}
```

### State Persistence

Save and restore the entire navigation state — something that requires significant boilerplate with vanilla `NavigationPath`:

```swift
// Save
if let codable = manager.codable {
    let data = try JSONEncoder().encode(codable)
    UserDefaults.standard.set(data, forKey: "savedPath")
}

// Restore
if let data = UserDefaults.standard.data(forKey: "savedPath"),
   let codable = try? JSONDecoder().decode(
       NavigationManager.CodableRepresentation.self, from: data
   ) {
    manager = NavigationManager(codable)
}
```

### Navigation Proxy

Child views can access navigation through the environment without any coupling to the manager:

```swift
struct ChildView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        Button("Pop to root") {
            navigator?.popToRoot()
        }
        Button("Pop to Settings") {
            navigator?.popTo(SettingsDestination.self)
        }
    }
}
```

For advanced usages, please refer to the full Documentation.

## Limitations

- **`NavigationLink` is not supported.** ManagedNavigation takes full control of the navigation path — using `NavigationLink(value:)` will push items directly onto `NavigationPath` and bypass the typed tracking, causing the internal state to go out of sync. Always use `manager.push()` or `navigator?.push()` instead.

- **watchOS is not supported.** The modal presentation system relies on `UIViewControllerRepresentable` (iOS/tvOS/visionOS) or `NSViewControllerRepresentable` (macOS) to detect when a modal has finished presenting. watchOS has no equivalent API.

## Documentation

Use Apple `DocC` generated documentation, from Xcode, `Product > Build Documentation`.

## Found a bug or want new feature?

If you found a bug, you can open an issue as a bug [here](https://github.com/ricocrescenzio95/ManagedNavigation/issues/new?assignees=ricocrescenzio95&labels=bug&template=bug_report.md&title=%5BBUG%5D)

Want a new feature? Open an issue [here](https://github.com/ricocrescenzio95/ManagedNavigation/issues/new?assignees=ricocrescenzio95&labels=enhancement&template=feature_request.md&title=%5BNEW%5D)

### You can also open your own PR and contribute to the project! [Contributing](CONTRIBUTING.md)

## License

This software is provided under the [MIT](LICENSE.md) license
