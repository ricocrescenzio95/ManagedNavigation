import Foundation
import Testing
import SwiftUI
@testable import ManagedNavigation

struct TestHome: NavigationDestination {}

struct TestDetails: NavigationDestination {
  var id: String
}

struct TestSettings: NavigationDestination {}

// MARK: - Helpers

private func assertPathCount(_ manager: NavigationManager, expected: Int, sourceLocation: SourceLocation = #_sourceLocation) {
  #expect(manager.path.count == expected, sourceLocation: sourceLocation)
  #expect(manager._path.count == expected, sourceLocation: sourceLocation)
}

// MARK: - Initialization

@Suite("Initialization")
struct InitializationTests {
  @Test("Empty initializer creates empty path")
  func emptyInit() {
    let manager = NavigationManager()
    assertPathCount(manager, expected: 0)
  }

  @Test("Initial path populates the stack")
  func initialPath() {
    let manager = NavigationManager([
      TestHome(),
      TestDetails(id: "abc"),
      TestSettings()
    ])
    assertPathCount(manager, expected: 3)
    #expect(type(of: manager.path[0]) == TestHome.self)
    #expect(type(of: manager.path[1]) == TestDetails.self)
    #expect(type(of: manager.path[2]) == TestSettings.self)
  }
}

// MARK: - Push

@Suite("Push")
struct PushTests {
  @Test("Push single destination")
  func pushSingle() {
    var manager = NavigationManager()
    manager.push(TestHome())
    assertPathCount(manager, expected: 1)
    #expect(type(of: manager.path[0]) == TestHome.self)
  }

  @Test("Push array of destinations")
  func pushArray() {
    var manager = NavigationManager()
    manager.push([TestHome(), TestDetails(id: "a"), TestSettings()])
    assertPathCount(manager, expected: 3)
    #expect(type(of: manager.path[0]) == TestHome.self)
    #expect(type(of: manager.path[1]) == TestDetails.self)
    #expect(type(of: manager.path[2]) == TestSettings.self)
  }

  @Test("Push preserves order")
  func pushOrder() {
    var manager = NavigationManager()
    manager.push(TestDetails(id: "first"))
    manager.push(TestDetails(id: "second"))
    let first = manager.path[0] as! TestDetails
    let second = manager.path[1] as! TestDetails
    #expect(first.id == "first")
    #expect(second.id == "second")
  }
}

// MARK: - Pop

@Suite("Pop")
struct PopTests {
  @Test("Pop removes last destination")
  func popLast() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    let result = manager.pop()
    #expect(result == true)
    assertPathCount(manager, expected: 1)
    #expect(type(of: manager.path[0]) == TestHome.self)
  }

  @Test("Pop on empty stack returns false")
  func popEmpty() {
    var manager = NavigationManager()
    let result = manager.pop()
    #expect(result == false)
    assertPathCount(manager, expected: 0)
  }

  @Test("Pop to root clears all destinations")
  func popToRoot() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    let result = manager.popToRoot()
    #expect(result == true)
    assertPathCount(manager, expected: 0)
  }

  @Test("Pop to root on empty stack returns false")
  func popToRootEmpty() {
    var manager = NavigationManager()
    let result = manager.popToRoot()
    #expect(result == false)
  }
}

// MARK: - PopTo (type-based)

@Suite("PopTo by type")
struct PopToTypeTests {
  @Test("PopTo finds last occurrence")
  func popToLastOccurrence() {
    var manager = NavigationManager([
      TestHome(),
      TestDetails(id: "a"),
      TestHome(),
      TestDetails(id: "b")
    ])
    let result = manager.popTo(TestHome.self)
    #expect(result == true)
    assertPathCount(manager, expected: 3)
    #expect(type(of: manager.path[2]) == TestHome.self)
  }

  @Test("PopTo returns false when type not found")
  func popToNotFound() {
    var manager = NavigationManager([TestHome()])
    let result = manager.popTo(TestSettings.self)
    #expect(result == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("PopTo returns true without modifying when already at target")
  func popToAlreadyAtTarget() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    let result = manager.popTo(TestDetails.self)
    #expect(result == true)
    assertPathCount(manager, expected: 2)
  }
}

// MARK: - PopToFirst

@Suite("PopToFirst")
struct PopToFirstTests {
  @Test("PopToFirst finds first occurrence")
  func popToFirstOccurrence() {
    var manager = NavigationManager([
      TestHome(),
      TestDetails(id: "a"),
      TestHome(),
      TestDetails(id: "b")
    ])
    let result = manager.popToFirst(TestHome.self)
    #expect(result == true)
    assertPathCount(manager, expected: 1)
    #expect(type(of: manager.path[0]) == TestHome.self)
  }

  @Test("PopToFirst returns false when type not found")
  func popToFirstNotFound() {
    var manager = NavigationManager([TestHome()])
    let result = manager.popToFirst(TestSettings.self)
    #expect(result == false)
    assertPathCount(manager, expected: 1)
  }
}

// MARK: - PopTo (index-based)

@Suite("PopTo by index")
struct PopToIndexTests {
  @Test("PopTo valid index trims stack")
  func popToValidIndex() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestSettings()
    ])
    let result = manager.popTo(at: 0)
    #expect(result == true)
    assertPathCount(manager, expected: 1)
    #expect(type(of: manager.path[0]) == TestHome.self)
  }

  @Test("PopTo out of bounds returns false")
  func popToOutOfBounds() {
    var manager = NavigationManager([TestHome()])
    let result = manager.popTo(at: 5)
    #expect(result == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("PopTo negative index returns false")
  func popToNegativeIndex() {
    var manager = NavigationManager([TestHome()])
    let result = manager.popTo(at: -1)
    #expect(result == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("PopTo last index returns true without modifying")
  func popToLastIndex() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    let result = manager.popTo(at: 1)
    #expect(result == true)
    assertPathCount(manager, expected: 2)
  }
}

// MARK: - PopTo (type + index)

@Suite("PopTo by type and index")
struct PopToTypeIndexTests {
  @Test("Matching type at index trims stack")
  func matchingTypeAtIndex() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestSettings()
    ])
    let result = manager.popTo(TestHome.self, at: 0)
    #expect(result == true)
    assertPathCount(manager, expected: 1)
  }

  @Test("Wrong type at index returns false")
  func wrongTypeAtIndex() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestSettings()
    ])
    let result = manager.popTo(TestDetails.self, at: 0)
    #expect(result == false)
    assertPathCount(manager, expected: 3)
  }

  @Test("Out of bounds index returns false")
  func outOfBoundsIndex() {
    var manager = NavigationManager([TestHome()])
    let result = manager.popTo(TestHome.self, at: 5)
    #expect(result == false)
  }
}

// MARK: - PopTo (predicate)

@Suite("PopTo by predicate")
struct PopToPredicateTests {
  @Test("Predicate finds matching destination")
  func predicateMatch() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "target"), TestSettings()
    ])
    let result = manager.popTo(where: { context in
      context.destination is TestDetails
    })
    #expect(result == true)
    assertPathCount(manager, expected: 2)
    #expect(type(of: manager.path[1]) == TestDetails.self)
  }

  @Test("Predicate with no match returns false")
  func predicateNoMatch() {
    var manager = NavigationManager([TestHome()])
    let result = manager.popTo(where: { context in
      context.destination is TestSettings
    })
    #expect(result == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("Predicate uses index correctly")
  func predicateWithIndex() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestHome(), TestDetails(id: "b")
    ])
    let result = manager.popTo(where: { context in
      context.index == 1
    })
    #expect(result == true)
    assertPathCount(manager, expected: 2)
  }
}

// MARK: - NavigationScanContext

@Suite("NavigationScanContext")
struct NavigationScanContextTests {
  @Test("destination returns correct element")
  func destinationAccess() {
    let path: [any NavigationDestination] = [TestHome(), TestDetails(id: "abc")]
    let context = NavigationManager.NavigationScanContext(path: path, index: 1)
    #expect(context.destination is TestDetails)
  }

  @Test("destination(as:) returns typed destination on match")
  func destinationAsMatch() {
    let path: [any NavigationDestination] = [TestDetails(id: "abc")]
    let context = NavigationManager.NavigationScanContext(path: path, index: 0)
    let details = context.destination as? TestDetails
    #expect(details?.id == "abc")
  }

  @Test("destination(as:) returns nil on type mismatch")
  func destinationAsMismatch() {
    let path: [any NavigationDestination] = [TestHome()]
    let context = NavigationManager.NavigationScanContext(path: path, index: 0)
    let details = context.destination as? TestDetails
    #expect(details == nil)
  }

  @Test("navigationID returns correct identifier")
  func navigationIDAccess() {
    let path: [any NavigationDestination] = [TestHome(), TestDetails(id: "abc")]
    let homeContext = NavigationManager.NavigationScanContext(path: path, index: 0)
    let detailsContext = NavigationManager.NavigationScanContext(path: path, index: 1)
    #expect(homeContext.destination.navigationID == ObjectIdentifier(TestHome.self))
    #expect(detailsContext.destination.navigationID == ObjectIdentifier(TestDetails.self))
  }
}

// MARK: - CodableRepresentation

struct CodableHome: NavigationDestination, Codable {}

struct CodableDetails: NavigationDestination, Codable {
  var id: String
}

struct NonCodableDestination: NavigationDestination {
  var callback: () -> Void
  static func == (lhs: Self, rhs: Self) -> Bool { true }
  func hash(into hasher: inout Hasher) {}
}

@Suite("CodableRepresentation")
struct CodableRepresentationTests {
  @Test("codable returns representation when all destinations are Codable")
  func codableReturnsRepresentation() {
    let manager = NavigationManager([
      CodableHome(),
      CodableDetails(id: "abc")
    ])
    #expect(manager.codable != nil)
  }

  @Test("codable returns nil when any destination is not Codable")
  func codableReturnsNilForNonCodable() {
    let manager = NavigationManager([
      CodableHome(),
      NonCodableDestination(callback: {})
    ])
    #expect(manager.codable == nil)
  }

  @Test("codable returns representation for empty path")
  func codableEmptyPath() {
    let manager = NavigationManager()
    #expect(manager.codable != nil)
  }

  @Test("Round-trip encode and decode preserves path")
  func roundTrip() throws {
    let original = NavigationManager([
      CodableHome(),
      CodableDetails(id: "first"),
      CodableDetails(id: "second")
    ])

    let representation = try #require(original.codable)
    let data = try JSONEncoder().encode(representation)
    let decoded = try JSONDecoder().decode(
      NavigationManager.CodableRepresentation.self, from: data
    )
    let restored = NavigationManager(decoded)

    assertPathCount(restored, expected: 3)
    #expect(type(of: restored.path[0]) == CodableHome.self)
    #expect(type(of: restored.path[1]) == CodableDetails.self)
    #expect(type(of: restored.path[2]) == CodableDetails.self)
    let details1 = try #require(restored.path[1] as? CodableDetails)
    let details2 = try #require(restored.path[2] as? CodableDetails)
    #expect(details1.id == "first")
    #expect(details2.id == "second")
  }

  @Test("Round-trip preserves empty path")
  func roundTripEmpty() throws {
    let original = NavigationManager()
    let representation = try #require(original.codable)
    let data = try JSONEncoder().encode(representation)
    let decoded = try JSONDecoder().decode(
      NavigationManager.CodableRepresentation.self, from: data
    )
    let restored = NavigationManager(decoded)
    assertPathCount(restored, expected: 0)
  }

  @Test("Decoding fails for unknown type name")
  func decodingFailsForUnknownType() throws {
    // Manually craft JSON with a bogus type name
    let bogusJSON = "[\"NonExistentModule.FakeType\",\"{}\"]"
    let data = Data(bogusJSON.utf8)
    #expect(throws: DecodingError.self) {
      _ = try JSONDecoder().decode(
        NavigationManager.CodableRepresentation.self, from: data
      )
    }
  }

  @Test("init from CodableRepresentation syncs _path and path")
  func initSyncsPath() throws {
    let original = NavigationManager([
      CodableHome(),
      CodableDetails(id: "abc")
    ])
    let representation = try #require(original.codable)
    let data = try JSONEncoder().encode(representation)
    let decoded = try JSONDecoder().decode(
      NavigationManager.CodableRepresentation.self, from: data
    )
    let restored = NavigationManager(decoded)
    assertPathCount(restored, expected: 2)
  }
}

// MARK: - Path sync

@Suite("Path and NavigationPath sync")
struct PathSyncTests {
  @Test("Path stays in sync after mixed operations")
  func syncAfterMixedOps() {
    var manager = NavigationManager()
    manager.push(TestHome())
    manager.push(TestDetails(id: "a"))
    manager.push(TestSettings())
    assertPathCount(manager, expected: 3)

    manager.pop()
    assertPathCount(manager, expected: 2)

    manager.push([TestHome(), TestDetails(id: "b")])
    assertPathCount(manager, expected: 4)

    manager.popTo(at: 1)
    assertPathCount(manager, expected: 2)

    manager.popToRoot()
    assertPathCount(manager, expected: 0)
  }
}

// MARK: - NavigationDestination protocol

@Suite("NavigationDestination")
struct NavigationDestinationTests {
  @Test("navigationID returns Object Identfier of Self by default")
  func defaultNavigationID() {
    #expect(TestHome.id == ObjectIdentifier(TestHome.self))
    #expect(TestDetails.id == ObjectIdentifier(TestDetails.self))
    #expect(TestSettings.id == ObjectIdentifier(TestSettings.self))
  }
}

// MARK: - matchesDestination

@Suite("matchesDestination")
struct MatchesDestinationTests {
  @Test("Returns true for same type even with different data")
  func sameTypeDifferentData() {
    let a = TestDetails(id: "a")
    let b = TestDetails(id: "b")
    #expect(a.matchesDestination(b))
  }

  @Test("Returns true for same type with identical data")
  func sameTypeIdenticalData() {
    let a = TestDetails(id: "a")
    let b = TestDetails(id: "a")
    #expect(a.matchesDestination(b))
  }

  @Test("Returns false for different types")
  func differentTypes() {
    let home = TestHome()
    let settings = TestSettings()
    #expect(!home.matchesDestination(settings))
  }

  @Test("Returns true for value types with no extra properties")
  func noExtraProperties() {
    let a = TestHome()
    let b = TestHome()
    #expect(a.matchesDestination(b))
  }
}

// MARK: - equalsDestination

@Suite("equalsDestination")
struct EqualsDestinationTests {
  @Test("Returns true for fully equal destinations")
  func fullyEqual() {
    let a = TestDetails(id: "abc")
    let b = TestDetails(id: "abc")
    #expect(a.equalsDestination(b))
  }

  @Test("Returns false for same type with different data")
  func sameTypeDifferentData() {
    let a = TestDetails(id: "a")
    let b = TestDetails(id: "b")
    #expect(!a.equalsDestination(b))
  }

  @Test("Returns false for different types")
  func differentTypes() {
    let home = TestHome()
    let settings = TestSettings()
    #expect(!home.equalsDestination(settings))
  }

  @Test("Returns true for value types with no stored properties")
  func noStoredProperties() {
    let a = TestHome()
    let b = TestHome()
    #expect(a.equalsDestination(b))
  }

  @Test("matchesDestination true but equalsDestination false for different data")
  func matchesButNotEquals() {
    let a = TestDetails(id: "first")
    let b = TestDetails(id: "second")
    #expect(a.matchesDestination(b))
    #expect(!a.equalsDestination(b))
  }
}

// MARK: - Replace pattern

@Suite("Replace")
struct ReplaceTests {
  @Test("Re-initializing with array replaces entire path")
  func replaceWithArray() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    assertPathCount(manager, expected: 2)

    manager = NavigationManager([TestSettings()])
    assertPathCount(manager, expected: 1)
    #expect(type(of: manager.path[0]) == TestSettings.self)
  }

  @Test("Re-initializing from CodableRepresentation replaces entire path")
  func replaceWithCodable() throws {
    let source = NavigationManager([CodableHome(), CodableDetails(id: "x")])
    let representation = try #require(source.codable)
    let data = try JSONEncoder().encode(representation)
    let decoded = try JSONDecoder().decode(
      NavigationManager.CodableRepresentation.self, from: data
    )

    var manager = NavigationManager([TestHome(), TestSettings()])
    assertPathCount(manager, expected: 2)

    manager = NavigationManager(decoded)
    assertPathCount(manager, expected: 2)
    #expect(type(of: manager.path[0]) == CodableHome.self)
    #expect(type(of: manager.path[1]) == CodableDetails.self)
  }

  @Test("Replacing with empty array clears path")
  func replaceWithEmpty() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    assertPathCount(manager, expected: 2)

    manager = NavigationManager([])
    assertPathCount(manager, expected: 0)
  }
}

// MARK: - CodableRepresentation (additional)

@Suite("CodableRepresentation additional")
struct CodableRepresentationAdditionalTests {
  @Test("Round-trip with single element")
  func roundTripSingle() throws {
    let original = NavigationManager([CodableDetails(id: "only")])
    let representation = try #require(original.codable)
    let data = try JSONEncoder().encode(representation)
    let decoded = try JSONDecoder().decode(
      NavigationManager.CodableRepresentation.self, from: data
    )
    let restored = NavigationManager(decoded)
    assertPathCount(restored, expected: 1)
    let details = try #require(restored.path[0] as? CodableDetails)
    #expect(details.id == "only")
  }

  @Test("Codable representation after push and pop operations")
  func codableAfterOperations() throws {
    var manager = NavigationManager([
      CodableHome(),
      CodableDetails(id: "a"),
      CodableDetails(id: "b")
    ])
    manager.pop()
    manager.push(CodableDetails(id: "c"))

    let representation = try #require(manager.codable)
    let data = try JSONEncoder().encode(representation)
    let decoded = try JSONDecoder().decode(
      NavigationManager.CodableRepresentation.self, from: data
    )
    let restored = NavigationManager(decoded)
    assertPathCount(restored, expected: 3)
    let last = try #require(restored.path[2] as? CodableDetails)
    #expect(last.id == "c")
  }

  @Test("Codable becomes nil when non-codable destination is pushed")
  func codableBecomesNilAfterNonCodablePush() {
    var manager = NavigationManager([CodableHome()])
    #expect(manager.codable != nil)

    manager.push(NonCodableDestination(callback: {}))
    #expect(manager.codable == nil)
  }
}

// MARK: - _path didSet sync

@Suite("Internal path sync")
struct InternalPathSyncTests {
  @Test("_path and path count stay equal after push")
  func syncAfterPush() {
    var manager = NavigationManager()
    manager.push(TestHome())
    manager.push(TestDetails(id: "a"))
    #expect(manager._path.count == manager.path.count)
  }

  @Test("_path and path count stay equal after pop")
  func syncAfterPop() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    manager.pop()
    #expect(manager._path.count == manager.path.count)
  }

  @Test("_path and path count stay equal after popToRoot")
  func syncAfterPopToRoot() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    manager.popToRoot()
    #expect(manager._path.count == manager.path.count)
    #expect(manager._path.count == 0)
  }

  @Test("_path and path count stay equal after popTo by type")
  func syncAfterPopToType() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    manager.popTo(TestDetails.self)
    #expect(manager._path.count == manager.path.count)
    #expect(manager._path.count == 2)
  }

  @Test("_path and path count stay equal after popTo by predicate")
  func syncAfterPopToPredicate() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    manager.popTo(where: { $0.index == 0 })
    #expect(manager._path.count == manager.path.count)
    #expect(manager._path.count == 1)
  }
}

// MARK: - NavigationScanContext (additional)

@Suite("NavigationScanContext additional")
struct NavigationScanContextAdditionalTests {
  @Test("path property returns the full path")
  func pathProperty() {
    let path: [any NavigationDestination] = [TestHome(), TestDetails(id: "a"), TestSettings()]
    let context = NavigationManager.NavigationScanContext(path: path, index: 1)
    #expect(context.path.count == 3)
  }

  @Test("index property returns the correct index")
  func indexProperty() {
    let path: [any NavigationDestination] = [TestHome(), TestDetails(id: "a")]
    let context = NavigationManager.NavigationScanContext(path: path, index: 1)
    #expect(context.index == 1)
  }
}

// MARK: - Helpers (new utilities)

/// A compact, order-preserving description of the stack, e.g. ["Home", "Details(a)"].
private func describe(_ manager: NavigationManager) -> [String] {
  manager.path.map {
    switch $0 {
    case is TestHome: "Home"
    case let details as TestDetails: "Details(\(details.id))"
    case is TestSettings: "Settings"
    default: "?"
    }
  }
}

// MARK: - Identifier

@Suite("Identifier")
struct IdentifierTests {
  @Test("Default id is generated and unique")
  func defaultID() {
    let a = NavigationManager()
    let b = NavigationManager()
    #expect(!a.id.isEmpty)
    #expect(a.id != b.id)
  }

  @Test("Custom id is preserved by init(id:)")
  func customID() {
    #expect(NavigationManager(id: "main").id == "main")
  }

  @Test("Custom id is preserved by init(_:id:)")
  func customIDWithPath() {
    let manager = NavigationManager([TestHome()], id: "main")
    #expect(manager.id == "main")
    assertPathCount(manager, expected: 1)
  }

  @Test("Custom id is preserved by init(_:id:) from CodableRepresentation")
  func customIDFromCodable() throws {
    let source = NavigationManager([CodableHome(), CodableDetails(id: "a")])
    let representation = try #require(source.codable)
    let data = try JSONEncoder().encode(representation)
    let decoded = try JSONDecoder().decode(
      NavigationManager.CodableRepresentation.self, from: data
    )
    let restored = NavigationManager(decoded, id: "restored")
    #expect(restored.id == "restored")
    assertPathCount(restored, expected: 2)
  }
}

// MARK: - Query

@Suite("Query")
struct QueryTests {
  @Test("isEmpty and count on empty stack")
  func emptyStack() {
    let manager = NavigationManager()
    #expect(manager.isEmpty)
    #expect(manager.count == 0)
    #expect(manager.top == nil)
  }

  @Test("isEmpty and count on populated stack")
  func populatedStack() {
    let manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(!manager.isEmpty)
    #expect(manager.count == 2)
  }

  @Test("top returns the last destination")
  func top() throws {
    let manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    let top = try #require(manager.top as? TestDetails)
    #expect(top.id == "a")
  }

  @Test("contains(destination) compares type and values")
  func containsDestination() {
    let manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.contains(TestHome()))
    #expect(manager.contains(TestDetails(id: "a")))
    #expect(!manager.contains(TestDetails(id: "b")))
    #expect(!manager.contains(TestSettings()))
  }

  @Test("contains(type) ignores values")
  func containsType() {
    let manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.contains(TestHome.self))
    #expect(manager.contains(TestDetails.self))
    #expect(!manager.contains(TestSettings.self))
  }

  @Test("lastIndex(of:) returns the last matching index")
  func lastIndexOf() {
    let manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestHome(), TestDetails(id: "b")
    ])
    #expect(manager.lastIndex(of: TestHome.self) == 2)
    #expect(manager.lastIndex(of: TestDetails.self) == 3)
    #expect(manager.lastIndex(of: TestSettings.self) == nil)
  }

  @Test("last(of:) returns the last matching destination, cast")
  func lastOf() throws {
    let manager = NavigationManager([
      TestDetails(id: "first"), TestHome(), TestDetails(id: "second")
    ])
    let details = try #require(manager.last(of: TestDetails.self))
    #expect(details.id == "second")
    #expect(manager.last(of: TestSettings.self) == nil)
  }

  @Test("Query methods do not modify the stack")
  func queriesAreNonMutating() {
    let manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    _ = manager.contains(TestHome())
    _ = manager.lastIndex(of: TestHome.self)
    _ = manager.last(of: TestDetails.self)
    assertPathCount(manager, expected: 2)
  }
}

// MARK: - Conditional push

@Suite("Conditional push")
struct ConditionalPushTests {
  // pushIfNotPresent (object)

  @Test("pushIfNotPresent pushes when no equal destination exists")
  func notPresentPushes() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.pushIfNotPresent(TestDetails(id: "a")) == true)
    #expect(describe(manager) == ["Home", "Details(a)"])
    assertPathCount(manager, expected: 2)
  }

  @Test("pushIfNotPresent skips an equal destination")
  func notPresentSkipsEqual() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.pushIfNotPresent(TestDetails(id: "a")) == false)
    assertPathCount(manager, expected: 2)
  }

  @Test("pushIfNotPresent pushes same type with different values")
  func notPresentDifferentValues() {
    var manager = NavigationManager([TestDetails(id: "a")])
    #expect(manager.pushIfNotPresent(TestDetails(id: "b")) == true)
    #expect(describe(manager) == ["Details(a)", "Details(b)"])
  }

  @Test("pushIfNotPresent on empty stack pushes")
  func notPresentEmpty() {
    var manager = NavigationManager()
    #expect(manager.pushIfNotPresent(TestHome()) == true)
    assertPathCount(manager, expected: 1)
  }

  // pushIfNotPresent (array)

  @Test("pushIfNotPresent array skips existing and duplicate destinations")
  func notPresentArray() {
    var manager = NavigationManager([TestHome()])
    let pushed = manager.pushIfNotPresent([
      TestHome(),
      TestDetails(id: "a"),
      TestDetails(id: "a"),
      TestSettings()
    ])
    #expect(pushed == true)
    #expect(describe(manager) == ["Home", "Details(a)", "Settings"])
    assertPathCount(manager, expected: 3)
  }

  @Test("pushIfNotPresent array returns false when nothing is pushed")
  func notPresentArrayNothingPushed() {
    var manager = NavigationManager([TestHome(), TestSettings()])
    #expect(manager.pushIfNotPresent([TestHome(), TestSettings()]) == false)
    assertPathCount(manager, expected: 2)
  }

  @Test("pushIfNotPresent with empty array returns false")
  func notPresentEmptyArray() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.pushIfNotPresent([]) == false)
    assertPathCount(manager, expected: 1)
  }

  // pushIfTypeNotPresent

  @Test("pushIfTypeNotPresent pushes when type is absent")
  func typeNotPresentPushes() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.pushIfTypeNotPresent(TestSettings()) == true)
    assertPathCount(manager, expected: 2)
  }

  @Test("pushIfTypeNotPresent skips when type exists, regardless of values")
  func typeNotPresentSkips() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.pushIfTypeNotPresent(TestDetails(id: "b")) == false)
    #expect(describe(manager) == ["Home", "Details(a)"])
    assertPathCount(manager, expected: 2)
  }

  // pushIfNotOnTop

  @Test("pushIfNotOnTop skips when the top is equal")
  func notOnTopSkips() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.pushIfNotOnTop(TestDetails(id: "a")) == false)
    assertPathCount(manager, expected: 2)
  }

  @Test("pushIfNotOnTop pushes when the top has different values")
  func notOnTopDifferentValues() {
    var manager = NavigationManager([TestDetails(id: "a")])
    #expect(manager.pushIfNotOnTop(TestDetails(id: "b")) == true)
    assertPathCount(manager, expected: 2)
  }

  @Test("pushIfNotOnTop pushes an equal destination that is not on top")
  func notOnTopEqualButBuried() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.pushIfNotOnTop(TestHome()) == true)
    assertPathCount(manager, expected: 3)
  }

  @Test("pushIfNotOnTop on empty stack pushes")
  func notOnTopEmpty() {
    var manager = NavigationManager()
    #expect(manager.pushIfNotOnTop(TestHome()) == true)
    assertPathCount(manager, expected: 1)
  }

  // push(_:if:)

  @Test("push(if:) pushes when the condition is true")
  func pushIfTrue() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.push(TestSettings(), if: { $0.count < 5 }) == true)
    assertPathCount(manager, expected: 2)
  }

  @Test("push(if:) does not push when the condition is false")
  func pushIfFalse() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.push(TestSettings(), if: { $0.count > 5 }) == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("push(if:) evaluates the condition on the current state")
  func pushIfReceivesCurrentState() {
    var manager = NavigationManager([TestHome(), TestSettings()])
    var receivedCount: Int?
    manager.push(TestDetails(id: "a"), if: {
      receivedCount = $0.count
      return true
    })
    #expect(receivedCount == 2)
  }
}

// MARK: - Pop (new)

@Suite("Pop additional")
struct PopAdditionalTests {
  // pop(_ count:)

  @Test("pop(count) removes the given number of destinations")
  func popCount() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    #expect(manager.pop(2) == true)
    #expect(describe(manager) == ["Home"])
    assertPathCount(manager, expected: 1)
  }

  @Test("pop(count) larger than the stack empties it")
  func popCountTooLarge() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.pop(10) == true)
    assertPathCount(manager, expected: 0)
  }

  @Test("pop(count) with zero or negative count returns false")
  func popCountNonPositive() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.pop(0) == false)
    #expect(manager.pop(-3) == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("pop(count) on empty stack returns false")
  func popCountEmpty() {
    var manager = NavigationManager()
    #expect(manager.pop(1) == false)
    assertPathCount(manager, expected: 0)
  }

  // pop(while:)

  @Test("pop(while:) pops while the predicate holds")
  func popWhile() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestSettings(), TestSettings()
    ])
    #expect(manager.pop(while: { $0 is TestSettings }) == true)
    #expect(describe(manager) == ["Home", "Details(a)"])
    assertPathCount(manager, expected: 2)
  }

  @Test("pop(while:) stops at the first non-matching destination")
  func popWhileStopsEarly() {
    var manager = NavigationManager([
      TestSettings(), TestHome(), TestSettings()
    ])
    manager.pop(while: { $0 is TestSettings })
    #expect(describe(manager) == ["Settings", "Home"])
  }

  @Test("pop(while:) returns false when the top does not match")
  func popWhileNoMatch() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.pop(while: { $0 is TestSettings }) == false)
    assertPathCount(manager, expected: 2)
  }

  @Test("pop(while:) can empty the stack")
  func popWhileAll() {
    var manager = NavigationManager([TestSettings(), TestSettings()])
    #expect(manager.pop(while: { _ in true }) == true)
    assertPathCount(manager, expected: 0)
  }

  @Test("pop(while:) on empty stack returns false")
  func popWhileEmpty() {
    var manager = NavigationManager()
    #expect(manager.pop(while: { _ in true }) == false)
  }

  // popToLast(where:)

  @Test("popToLast(where:) stops at the last match")
  func popToLastWhere() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestHome(), TestDetails(id: "b")
    ])
    let result = manager.popToLast(where: { $0.destination is TestHome })
    #expect(result == true)
    #expect(describe(manager) == ["Home", "Details(a)", "Home"])
    assertPathCount(manager, expected: 3)
  }

  @Test("popToLast(where:) differs from popTo(where:) on multiple matches")
  func popToLastVersusPopTo() {
    var first = NavigationManager([TestHome(), TestDetails(id: "a"), TestHome()])
    var last = first
    first.popTo(where: { $0.destination is TestHome })
    last.popToLast(where: { $0.destination is TestHome })
    assertPathCount(first, expected: 1)
    assertPathCount(last, expected: 3)
  }

  @Test("popToLast(where:) returns false when nothing matches")
  func popToLastWhereNoMatch() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.popToLast(where: { $0.destination is TestSettings }) == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("popToLast(where:) uses the index correctly")
  func popToLastWhereIndex() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    #expect(manager.popToLast(where: { $0.index <= 1 }) == true)
    assertPathCount(manager, expected: 2)
  }
}

// MARK: - Combined push / pop

@Suite("Combined push and pop")
struct CombinedPushPopTests {
  // pushOrPopTo

  @Test("pushOrPopTo pops back to an equal destination")
  func pushOrPopToExisting() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    #expect(manager.pushOrPopTo(TestDetails(id: "a")) == false)
    #expect(describe(manager) == ["Home", "Details(a)"])
    assertPathCount(manager, expected: 2)
  }

  @Test("pushOrPopTo pushes when no equal destination exists")
  func pushOrPopToNew() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.pushOrPopTo(TestDetails(id: "b")) == true)
    #expect(describe(manager) == ["Home", "Details(a)", "Details(b)"])
    assertPathCount(manager, expected: 3)
  }

  @Test("pushOrPopTo pops to the last equal occurrence")
  func pushOrPopToLastOccurrence() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestHome(), TestSettings()
    ])
    manager.pushOrPopTo(TestHome())
    #expect(describe(manager) == ["Home", "Details(a)", "Home"])
  }

  @Test("pushOrPopTo returns false without changes when already on top")
  func pushOrPopToAlreadyOnTop() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.pushOrPopTo(TestDetails(id: "a")) == false)
    assertPathCount(manager, expected: 2)
  }

  @Test("pushOrPopTo on empty stack pushes")
  func pushOrPopToEmpty() {
    var manager = NavigationManager()
    #expect(manager.pushOrPopTo(TestHome()) == true)
    assertPathCount(manager, expected: 1)
  }

  // pushOrPopToType

  @Test("pushOrPopToType pops to an existing destination of the same type")
  func pushOrPopToTypeExisting() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    #expect(manager.pushOrPopToType(TestDetails(id: "other")) == false)
    // Values are ignored: the existing destination is kept.
    #expect(describe(manager) == ["Home", "Details(a)"])
    assertPathCount(manager, expected: 2)
  }

  @Test("pushOrPopToType pushes when the type is absent")
  func pushOrPopToTypeNew() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.pushOrPopToType(TestSettings()) == true)
    #expect(describe(manager) == ["Home", "Settings"])
    assertPathCount(manager, expected: 2)
  }

  // popToRoot(thenPush:)

  @Test("popToRoot(thenPush:) leaves only the new destination")
  func popToRootThenPush() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    manager.popToRoot(thenPush: TestSettings())
    #expect(describe(manager) == ["Settings"])
    assertPathCount(manager, expected: 1)
  }

  @Test("popToRoot(thenPush:) on empty stack just pushes")
  func popToRootThenPushEmpty() {
    var manager = NavigationManager()
    manager.popToRoot(thenPush: TestHome())
    assertPathCount(manager, expected: 1)
  }
}

// MARK: - Stack modification

@Suite("Stack modification")
struct StackModificationTests {
  // setPath

  @Test("setPath replaces the entire stack")
  func setPath() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    manager.setPath([TestSettings(), TestDetails(id: "b"), TestHome()])
    #expect(describe(manager) == ["Settings", "Details(b)", "Home"])
    assertPathCount(manager, expected: 3)
  }

  @Test("setPath with empty array clears the stack")
  func setPathEmpty() {
    var manager = NavigationManager([TestHome()])
    manager.setPath([])
    assertPathCount(manager, expected: 0)
  }

  @Test("setPath preserves id")
  func setPathPreservesID() {
    var manager = NavigationManager([TestHome()], id: "main")
    manager.setPath([TestSettings()])
    #expect(manager.id == "main")
  }

  @Test("setPath preserves transaction")
  func setPathPreservesTransaction() {
    var manager = NavigationManager([TestHome()])
    manager.transaction = Transaction(animation: .default)
    manager.setPath([TestSettings()])
    #expect(manager.transaction != nil)
  }

  // replace / replaceLast

  @Test("replace swaps the destination and keeps the ones above it")
  func replaceMiddle() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    #expect(manager.replace(TestDetails(id: "b"), at: 1) == true)
    #expect(describe(manager) == ["Home", "Details(b)", "Settings"])
    assertPathCount(manager, expected: 3)
  }

  @Test("replace out of bounds returns false")
  func replaceOutOfBounds() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.replace(TestSettings(), at: 3) == false)
    #expect(manager.replace(TestSettings(), at: -1) == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("replace preserves id and transaction")
  func replacePreservesIDAndTransaction() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")], id: "main")
    manager.transaction = Transaction(animation: .default)
    manager.replace(TestSettings(), at: 1)
    #expect(manager.id == "main")
    #expect(manager.transaction != nil)
  }

  @Test("replaceLast replaces the top destination")
  func replaceLast() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    #expect(manager.replaceLast(with: TestSettings()) == true)
    #expect(describe(manager) == ["Home", "Settings"])
    assertPathCount(manager, expected: 2)
  }

  @Test("replaceLast on empty stack returns false")
  func replaceLastEmpty() {
    var manager = NavigationManager()
    #expect(manager.replaceLast(with: TestHome()) == false)
    assertPathCount(manager, expected: 0)
  }

  // insert

  @Test("insert in the middle shifts following destinations up")
  func insertMiddle() {
    var manager = NavigationManager([TestHome(), TestSettings()])
    #expect(manager.insert(TestDetails(id: "a"), at: 1) == true)
    #expect(describe(manager) == ["Home", "Details(a)", "Settings"])
    assertPathCount(manager, expected: 3)
  }

  @Test("insert at index 0 puts the destination at the bottom")
  func insertAtStart() {
    var manager = NavigationManager([TestHome()])
    manager.insert(TestSettings(), at: 0)
    #expect(describe(manager) == ["Settings", "Home"])
  }

  @Test("insert at count appends")
  func insertAtEnd() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.insert(TestSettings(), at: 1) == true)
    #expect(describe(manager) == ["Home", "Settings"])
  }

  @Test("insert on empty stack at index 0 works")
  func insertEmpty() {
    var manager = NavigationManager()
    #expect(manager.insert(TestHome(), at: 0) == true)
    assertPathCount(manager, expected: 1)
  }

  @Test("insert out of bounds returns false")
  func insertOutOfBounds() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.insert(TestSettings(), at: 2) == false)
    #expect(manager.insert(TestSettings(), at: -1) == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("insert preserves id")
  func insertPreservesID() {
    var manager = NavigationManager([TestHome()], id: "main")
    manager.insert(TestSettings(), at: 0)
    #expect(manager.id == "main")
  }

  // remove(at:)

  @Test("remove(at:) removes the destination and keeps the others")
  func removeAt() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    #expect(manager.remove(at: 1) == true)
    #expect(describe(manager) == ["Home", "Settings"])
    assertPathCount(manager, expected: 2)
  }

  @Test("remove(at:) can remove the top and the bottom")
  func removeAtEdges() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a"), TestSettings()])
    manager.remove(at: 2)
    manager.remove(at: 0)
    #expect(describe(manager) == ["Details(a)"])
  }

  @Test("remove(at:) out of bounds returns false")
  func removeAtOutOfBounds() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.remove(at: 1) == false)
    #expect(manager.remove(at: -1) == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("remove(at:) preserves id")
  func removeAtPreservesID() {
    var manager = NavigationManager([TestHome(), TestSettings()], id: "main")
    manager.remove(at: 0)
    #expect(manager.id == "main")
  }

  // removeAll(of:)

  @Test("removeAll(of:) removes every destination of the type")
  func removeAllOfType() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestSettings(), TestDetails(id: "b")
    ])
    #expect(manager.removeAll(of: TestDetails.self) == true)
    #expect(describe(manager) == ["Home", "Settings"])
    assertPathCount(manager, expected: 2)
  }

  @Test("removeAll(of:) returns false when the type is absent")
  func removeAllOfTypeAbsent() {
    var manager = NavigationManager([TestHome()])
    #expect(manager.removeAll(of: TestSettings.self) == false)
    assertPathCount(manager, expected: 1)
  }

  // removeAll(_:)

  @Test("removeAll(destination) removes only equal destinations")
  func removeAllEqual() {
    var manager = NavigationManager([
      TestHome(), TestDetails(id: "a"), TestDetails(id: "b"), TestDetails(id: "a")
    ])
    #expect(manager.removeAll(TestDetails(id: "a")) == true)
    #expect(describe(manager) == ["Home", "Details(b)"])
    assertPathCount(manager, expected: 2)
  }

  @Test("removeAll(destination) returns false when nothing is equal")
  func removeAllEqualAbsent() {
    var manager = NavigationManager([TestDetails(id: "a")])
    #expect(manager.removeAll(TestDetails(id: "b")) == false)
    assertPathCount(manager, expected: 1)
  }

  @Test("removeAll preserves id")
  func removeAllPreservesID() {
    var manager = NavigationManager([TestHome(), TestSettings()], id: "main")
    manager.removeAll(of: TestSettings.self)
    #expect(manager.id == "main")
  }
}

// MARK: - Sync after new operations

@Suite("Path sync after new operations")
struct NewOperationsSyncTests {
  @Test("path and _path stay in sync after every new operation")
  func syncAfterNewOperations() {
    var manager = NavigationManager()

    manager.pushIfNotPresent(TestHome())
    assertPathCount(manager, expected: 1)

    manager.pushIfTypeNotPresent(TestDetails(id: "a"))
    assertPathCount(manager, expected: 2)

    manager.pushIfNotOnTop(TestSettings())
    assertPathCount(manager, expected: 3)

    manager.insert(TestDetails(id: "b"), at: 1)
    assertPathCount(manager, expected: 4)

    manager.remove(at: 0)
    assertPathCount(manager, expected: 3)

    manager.replaceLast(with: TestHome())
    assertPathCount(manager, expected: 3)

    manager.pop(1)
    assertPathCount(manager, expected: 2)

    manager.pushOrPopTo(TestDetails(id: "b"))
    assertPathCount(manager, expected: 1)

    manager.setPath([TestHome(), TestSettings(), TestHome()])
    assertPathCount(manager, expected: 3)

    manager.removeAll(of: TestHome.self)
    assertPathCount(manager, expected: 1)

    manager.popToRoot(thenPush: TestDetails(id: "z"))
    assertPathCount(manager, expected: 1)
  }

  @Test("Operations that rebuild the stack remain pop-able")
  func popAfterRebuild() {
    var manager = NavigationManager([TestHome(), TestDetails(id: "a")])
    manager.insert(TestSettings(), at: 1)
    #expect(manager.pop() == true)
    #expect(describe(manager) == ["Home", "Settings"])
    assertPathCount(manager, expected: 2)
  }
}
