# ManagedNavigation — Internal Architecture

This document describes the internal design of the library, with a focus on the
modal presentation system (`ManagedPresentation`) which is the most complex part.

## Overview

The library has two main containers:

- **`ManagedNavigationStack`** — A thin wrapper around SwiftUI's `NavigationStack`.
  It binds `NavigationManager._path` to the stack and injects a `Navigator` into
  the environment. There is very little custom logic here because `NavigationStack`
  already handles the heavy lifting.

- **`ManagedPresentation`** — A custom container that drives sequential sheet and
  full-screen-cover presentations from the same `NavigationManager` path. This is
  where most of the complexity lives, because SwiftUI provides no built-in way to
  present a *stack* of modals programmatically.

Both containers share:
- `NavigationManager` (a value-type struct) as the source of truth.
- `Navigator` (a reference-type class) as the environment bridge for child views.

## Navigator — Why a Class?

`NavigationManager` is a struct held in `@State`. Every mutation produces a new
value, and a `Binding<NavigationManager>` passed through the environment would
change identity on every path update, causing SwiftUI to invalidate *every* child
view that reads it — even views that only call `push()` and never display the path.

`Navigator` solves this by wrapping the binding in an `@Observable` class stored
as `@StateObject`:

```
@Observable
class Navigator: ObservableObject {
    @ObservationIgnored var binding: Binding<NavigationManager>
    var path: [any NavigationDestination] = []
}
```

Key design choices:

- **`@StateObject`** guarantees a single instance for the lifetime of the container,
  so the object identity injected via `.environment(\.navigator, navigator)` never
  changes. No child view is invalidated by the environment injection alone.

- **`binding` is `@ObservationIgnored`**. Calling `navigator.push()` writes through
  the binding (triggering SwiftUI state propagation on the manager), but does *not*
  produce an `@Observable` notification. Views that only call mutations are never
  re-evaluated.

- **`path` is tracked by Observation**. It is only assigned inside `syncPath()`,
  which performs a deep equality check first. Views that read `navigator.path`
  (e.g. breadcrumbs) are re-evaluated only when the path actually changes.

- **Dual conformance** to `@Observable` and `ObservableObject` bridges Swift
  Observation (fine-grained property tracking) with Combine (`@StateObject`
  requirement).

## ManagedPresentation — The Modal Presentation Engine

### The Problem

SwiftUI sheets are strictly sequential: you cannot present two modals at once on
the same parent, and each present/dismiss must wait for the animation to complete
before the next one can start. The library needs to translate arbitrary path changes
(e.g. going from `[A, B, C]` to `[D]`) into a correct sequence of animated
operations.

### Architecture

`ManagedPresentation` is composed of several small, private views. Each exists for
a specific reason — either as an **invalidation boundary** (so that a state change
at one depth doesn't cascade to all depths) or as a **lifecycle requirement** (e.g.
embedding a UIKit view controller inside the presented content).

```
ManagedPresentation
  └─ root (user content with .sheet(for:) / .fullScreenCover(for:) modifiers)
  └─ [background] LevelResolver (depth 0)
       └─ PresentationBody (depth 0)
            ├─ OperationObserver — watches level.operation, sets isPresented
            ├─ .sheet(isPresented:) { content }
            │    └─ presented content
            │         ├─ [background] OperationCompletedObserver
            │         │    └─ PresentationNotifier (UIKit bridge)
            │         └─ [background] LevelResolver (depth 1)
            │              └─ PresentationBody (depth 1)
            │                   └─ ... (recursive)
            └─ .fullScreenCover(isPresented:) { content }
                 └─ (same structure)
```

### The Views

**`LevelResolver`** — Reads `model.levels[depth]` and passes the resulting
`PresentationLevel` to `PresentationBody`. This indirection isolates the array
access: when the model changes, only the resolver at the affected depth
re-evaluates, not every `PresentationBody` in the chain.

**`PresentationBody`** — The core view that holds `.sheet()` and
`.fullScreenCover()` modifiers. It maintains local `@State` for `isPresented` and
`storedDestination`. The stored destination preserves the current content during
dismiss animations, even if the model's destination has already moved on.

**`OperationObserver`** — A zero-size view that watches `level.operation` (the
currently executing operation). When it changes to `.present`, it sets
`isPresented = true`; when `.dismiss`, it sets `isPresented = false`. Isolating
this in its own view prevents the `onChange` from forcing the rest of
`PresentationBody` to re-evaluate.

**`OperationCompletedObserver`** — Lives *inside* the presented content. It embeds
a `PresentationNotifier` so that the UIKit view controller participates in the
sheet's view hierarchy and receives `viewDidAppear` / `viewDidDisappear` at the
correct time. When the animation finishes, it calls
`model.onOperationCompleted(of: level)` to advance the state machine.

**`PresentationNotifier`** — A `UIViewControllerRepresentable` (or
`NSViewControllerRepresentable` on macOS) that converts UIKit lifecycle events into
callbacks. This is the only reliable way to detect when iOS finishes a sheet
present/dismiss animation, as SwiftUI provides no such callback.

### The Snapshot Queue (PresentationModel)

`PresentationModel` is the state machine that serializes path changes into animated
operations.

**Snapshot**: An immutable picture of the desired path (array of `navigationID`s and
destinations).

**Flow**:

1. `onPathChange` creates a `Snapshot` and calls `enqueueSnapshot`.
2. If idle, `processSnapshot` runs immediately. Otherwise the snapshot is stored as
   pending (only the latest is kept — intermediate states are collapsed).
3. `processSnapshot` diffs the new snapshot against `confirmedNavigationIDs` (the
   path the UI has fully animated to):
   - Levels beyond the shared prefix in the *new* path get `.present` queued.
   - The first level beyond the shared prefix in the *old* path gets `.dismiss`
     queued.
   - Shared-prefix levels get their destination updated in place.
4. `executeNextOperation` picks one operation to execute (dismissals first, then
   presentations), setting `level.operation` which triggers `OperationObserver`.
5. When the animation completes, `onOperationCompleted` removes the finished
   operation from the level's queue and calls `executeNextOperation` again.
6. When all operations are done, `confirmAndAdvance` updates
   `confirmedNavigationIDs` and processes the next pending snapshot if any.

### Destination Registration (PreferenceKey)

User-facing modifiers (`.sheet(for:)`, `.fullScreenCover(for:)`) use
`transformPreference(PresentationPreferenceKey.self)` to insert a
`PresentationData` entry keyed by `navigationID`. The dictionary bubbles up through
SwiftUI's preference system and is read via `.backgroundPreferenceValue` in
`ManagedPresentation` (depth 0) and recursively in each `PresentationBody.content`
(deeper depths).

At each depth, the child's registrations are merged into the parent's with child
priority (`{ $1 }`), so a presented sheet can override or extend the available
destinations.

## Data Flow Summary

```
manager.push(X)
    │
    ▼
NavigationManager.path mutates (value type)
    │
    ▼
ManagedPresentation.onChange fires
    ├──▶ model.onPathChange()
    │       └──▶ enqueueSnapshot ──▶ processSnapshot
    │              └──▶ executeNextOperation
    │                     └──▶ level.operation = .present / .dismiss
    │                            └──▶ OperationObserver sets isPresented
    │                                   └──▶ .sheet() / .fullScreenCover() animates
    │                                          └──▶ PresentationNotifier fires
    │                                                 └──▶ onOperationCompleted
    │                                                        └──▶ next operation or confirm
    │
    └──▶ navigator.syncPath()
            └──▶ updates Navigator.path (only if changed)
                    └──▶ child views observing .path re-render
```
