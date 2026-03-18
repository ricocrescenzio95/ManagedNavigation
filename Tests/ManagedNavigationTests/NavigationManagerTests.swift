import Foundation
import Testing
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
    #expect(homeContext.destinationID == "TestHome")
    #expect(detailsContext.destinationID == "TestDetails")
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
  @Test("navigationID returns type name by default")
  func defaultNavigationID() {
    #expect(TestHome.navigationID == "TestHome")
    #expect(TestDetails.navigationID == "TestDetails")
    #expect(TestSettings.navigationID == "TestSettings")
  }

  @Test("Instance navigationID matches static navigationID")
  func instanceNavigationID() {
    let destination = TestDetails(id: "abc")
    #expect(destination.navigationID == TestDetails.navigationID)
  }

  @Test("type property returns Self.self")
  func typeProperty() {
    let destination = TestDetails(id: "abc")
    #expect(destination.type == TestDetails.self)
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

  @Test("destinationID matches type's navigationID")
  func destinationIDMatchesType() {
    let path: [any NavigationDestination] = [TestDetails(id: "abc")]
    let context = NavigationManager.NavigationScanContext(path: path, index: 0)
    #expect(context.destinationID == TestDetails.navigationID)
  }
}
