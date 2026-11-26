import Testing
import SwiftUI
@testable import ManagedNavigation

// MARK: - Helpers

private func makeNavigator(_ id: String, _ kind: Navigator.Kind) -> Navigator {
  Navigator(.constant(NavigationManager(id: id)), kind: kind)
}

/// Builds a container in registration order (outermost first).
private func makeContainer(_ navigators: [Navigator]) -> NavigatorsContainer {
  var container = NavigatorsContainer()
  navigators.forEach { container.register($0) }
  return container
}

/// Hierarchy: modal(root) > stack(a) > modal(sheet) > stack(b)
private struct Hierarchy {
  let root = makeNavigator("root", .modal)
  let a = makeNavigator("a", .stack)
  let sheet = makeNavigator("sheet", .modal)
  let b = makeNavigator("b", .stack)

  var all: [Navigator] { [root, a, sheet, b] }
  var container: NavigatorsContainer { makeContainer(all) }
}

private func ids(_ navigators: [Navigator]) -> [String] {
  navigators.map(\.id)
}

// MARK: - Basics

@Suite("NavigatorsContainer basics")
struct NavigatorsContainerBasicsTests {
  @Test("Navigator exposes the kind it was created with")
  func navigatorKind() {
    #expect(makeNavigator("s", .stack).kind == .stack)
    #expect(makeNavigator("m", .modal).kind == .modal)
  }

  @Test("Empty container returns nil for every lookup")
  func emptyContainer() {
    let container = NavigatorsContainer()
    let other = makeNavigator("x", .stack)
    #expect(container.isEmpty)
    #expect(container.count == 0)
    #expect(container["x"] == nil)
    #expect(!container.contains("x"))
    #expect(container.nearest == nil)
    #expect(container.outermost == nil)
    #expect(container.ancestor(0) == nil)
    #expect(container.nearestStack == nil)
    #expect(container.nearestModal == nil)
    #expect(container.nearest(.stack) == nil)
    #expect(container.outermost(.modal) == nil)
    #expect(container.ancestor(0, of: .stack) == nil)
    #expect(container.navigators(of: .stack).isEmpty)
    #expect(container.parent(of: other) == nil)
  }

  @Test("Register preserves order from outermost to nearest")
  func registerOrder() {
    let h = Hierarchy()
    let container = h.container
    #expect(container.count == 4)
    #expect(!container.isEmpty)
    #expect(ids(container.navigators) == ["root", "a", "sheet", "b"])
  }
}

// MARK: - Lookup by id

@Suite("NavigatorsContainer lookup by id")
struct NavigatorsContainerIDTests {
  @Test("Subscript finds a navigator by manager id")
  func subscriptByID() {
    let h = Hierarchy()
    #expect(h.container["sheet"] === h.sheet)
    #expect(h.container["root"] === h.root)
    #expect(h.container["missing"] == nil)
  }

  @Test("Subscript returns the innermost navigator when ids are shadowed")
  func shadowedID() {
    let outer = makeNavigator("same", .modal)
    let inner = makeNavigator("same", .stack)
    let container = makeContainer([outer, inner])
    #expect(container["same"] === inner)
  }

  @Test("Contains reports whether an id is among the ancestors")
  func containsID() {
    let h = Hierarchy()
    #expect(h.container.contains("a"))
    #expect(!h.container.contains("missing"))
  }
}

// MARK: - Lookup by position

@Suite("NavigatorsContainer lookup by position")
struct NavigatorsContainerPositionTests {
  @Test("Nearest and outermost")
  func nearestAndOutermost() {
    let h = Hierarchy()
    #expect(h.container.nearest === h.b)
    #expect(h.container.outermost === h.root)
  }

  @Test("Ancestor counts levels from the nearest navigator")
  func ancestorLevels() {
    let h = Hierarchy()
    let container = h.container
    #expect(container.ancestor(0) === h.b)
    #expect(container.ancestor(1) === h.sheet)
    #expect(container.ancestor(2) === h.a)
    #expect(container.ancestor(3) === h.root)
    #expect(container.ancestor(4) == nil)
    #expect(container.ancestor(-1) == nil)
  }

  @Test("Parent returns the directly enclosing navigator")
  func parent() {
    let h = Hierarchy()
    let container = h.container
    #expect(container.parent(of: h.b) === h.sheet)
    #expect(container.parent(of: h.sheet) === h.a)
    #expect(container.parent(of: h.a) === h.root)
    #expect(container.parent(of: h.root) == nil)
  }

  @Test("Parent filtered by kind skips containers of the other kind")
  func parentOfKind() {
    let h = Hierarchy()
    let container = h.container
    #expect(container.parent(of: h.b, kind: .stack) === h.a)
    #expect(container.parent(of: h.b, kind: .modal) === h.sheet)
    #expect(container.parent(of: h.sheet, kind: .modal) === h.root)
    #expect(container.parent(of: h.a, kind: .stack) == nil)
  }

  @Test("Parent of a navigator not in the container is nil")
  func parentOfUnknown() {
    let h = Hierarchy()
    #expect(h.container.parent(of: makeNavigator("b", .stack)) == nil)
  }
}

// MARK: - Lookup by kind

@Suite("NavigatorsContainer lookup by kind")
struct NavigatorsContainerKindTests {
  @Test("Navigators of a kind keep their order")
  func navigatorsOfKind() {
    let h = Hierarchy()
    #expect(ids(h.container.navigators(of: .stack)) == ["a", "b"])
    #expect(ids(h.container.navigators(of: .modal)) == ["root", "sheet"])
  }

  @Test("Nearest and outermost of a kind")
  func nearestAndOutermostOfKind() {
    let h = Hierarchy()
    let container = h.container
    #expect(container.nearest(.stack) === h.b)
    #expect(container.nearest(.modal) === h.sheet)
    #expect(container.outermost(.stack) === h.a)
    #expect(container.outermost(.modal) === h.root)
  }

  @Test("Nearest stack and nearest modal shortcuts")
  func nearestShortcuts() {
    let h = Hierarchy()
    #expect(h.container.nearestStack === h.b)
    #expect(h.container.nearestModal === h.sheet)
  }

  @Test("Ancestor of a kind only counts containers of that kind")
  func ancestorOfKind() {
    let h = Hierarchy()
    let container = h.container
    #expect(container.ancestor(0, of: .stack) === h.b)
    #expect(container.ancestor(1, of: .stack) === h.a)
    #expect(container.ancestor(2, of: .stack) == nil)
    #expect(container.ancestor(0, of: .modal) === h.sheet)
    #expect(container.ancestor(1, of: .modal) === h.root)
    #expect(container.ancestor(-1, of: .modal) == nil)
  }

  @Test("Missing kind returns nil")
  func missingKind() {
    let container = makeContainer([makeNavigator("only", .stack)])
    #expect(container.nearestModal == nil)
    #expect(container.outermost(.modal) == nil)
    #expect(container.ancestor(0, of: .modal) == nil)
    #expect(container.navigators(of: .modal).isEmpty)
    #expect(container.nearestStack?.id == "only")
  }
}
