import XCTest

final class PresentationUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launch()

    // Navigate to the Presentation tab
    app.tabBars.buttons["Presentation"].tap()
  }

  // MARK: - Single push/dismiss

  func testSinglePushAndDismiss() {
    let settingsButton = app.buttons["push-settings"]
    XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
    settingsButton.tap()

    // Verify the Settings sheet appeared
    let settingsTitle = app.navigationBars["Settings"]
    XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5))

    // Swipe down to dismiss
    app.swipeDown(velocity: .fast)

    // Verify we're back to the root
    XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
  }

  // MARK: - Rapid sequential pushes (same destination)

  /// Push Settings, dismiss, then push Settings again quickly.
  /// This verifies that a second push arriving while the first dismiss
  /// is still animating doesn't break the presentation system.
  func testRapidPushDismissPush() {
    let settingsButton = app.buttons["push-settings"]
    XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

    // First push
    settingsButton.tap()
    let settingsTitle = app.navigationBars["Settings"]
    XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5))

    // Swipe down to dismiss
    app.swipeDown(velocity: .fast)

    // Immediately push again (may overlap with dismiss animation)
    sleep(UInt32(0)) // yield to let dismiss start
    if settingsButton.waitForExistence(timeout: 3) {
      settingsButton.tap()
      XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5),
                     "Settings sheet should re-appear after rapid dismiss+push")
    }
  }

  // MARK: - Rapid sequential pushes (different destinations)

  /// Push Settings, then while it's presented, go back and push Profile.
  /// This simulates rapid path changes that exercise the snapshot queue.
  func testPushDismissPushDifferentDestination() {
    let settingsButton = app.buttons["push-settings"]
    let profileButton = app.buttons["push-profile"]
    XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

    // Push Settings
    settingsButton.tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

    // Dismiss
    app.swipeDown(velocity: .fast)

    // Wait briefly then push Profile
    if profileButton.waitForExistence(timeout: 3) {
      profileButton.tap()
      XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5),
                     "Profile sheet should appear after dismissing Settings")
    }
  }

  // MARK: - Batch push (multiple destinations at once)

  /// Uses the Batch Push section to push multiple destinations simultaneously.
  /// This is the core test for the snapshot queue: pushing [Settings, Profile]
  /// means Settings must present first, then Profile on top of it.
  func testBatchPushMultipleDestinations() {
    // Scroll to Batch Push section
    let pushAllButton = app.buttons["Push All"]
    app.swipeUp(velocity: .slow)

    guard pushAllButton.waitForExistence(timeout: 5) else {
      XCTFail("Could not find Push All button")
      return
    }

    // Select Settings, then Profile
    let settingsChip = app.buttons["Settings"]
    let profileChip = app.buttons["Profile"]

    if settingsChip.waitForExistence(timeout: 3) {
      settingsChip.tap()
    }
    if profileChip.waitForExistence(timeout: 3) {
      profileChip.tap()
    }

    // Push all at once
    pushAllButton.tap()

    // The first sheet (Settings) should appear
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5),
                   "First sheet (Settings) should appear from batch push")

    // The second sheet (Profile) should appear on top
    XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10),
                   "Second sheet (Profile) should appear on top of Settings")
  }

  // MARK: - App stability after multiple operations

  /// Performs several push/dismiss cycles rapidly and checks the app
  /// hasn't crashed by verifying the root view is still reachable.
  func testStabilityAfterMultipleRapidOperations() {
    let settingsButton = app.buttons["push-settings"]
    XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

    for _ in 0..<3 {
      settingsButton.tap()

      if app.navigationBars["Settings"].waitForExistence(timeout: 5) {
        app.swipeDown(velocity: .fast)
        // Small delay to let animation start but not finish
        usleep(150_000) // 300ms
      }
    }

    // After all cycles, verify the root is still accessible
    XCTAssertTrue(settingsButton.waitForExistence(timeout: 10),
                   "Root view should be accessible after rapid push/dismiss cycles")
  }

  // MARK: - Programmatic stress tests (snapshot queue)

  /// Scrolls to the Stress Tests section and returns the status label.
  private func scrollToStressTests() {
    let status = app.staticTexts["stress-status"]
    // Scroll until visible
    for _ in 0..<5 {
      if status.waitForExistence(timeout: 1) { break }
      app.swipeUp(velocity: .slow)
    }
    XCTAssertTrue(status.exists, "Stress test section should be visible")
  }

  /// Waits for the status label to show the expected value.
  private func waitForStatus(_ expected: String, timeout: TimeInterval = 30) -> Bool {
    let status = app.staticTexts["stress-status"]
    let predicate = NSPredicate(format: "label == %@", expected)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: status)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }

  /// Sequence 1: push([Settings, Profile, Account]) → replace([Settings, Account]) → pop()
  /// Expected final: [Settings] — the Settings sheet should be the topmost.
  func testStressSequence1_PushReplacePop() {
    scrollToStressTests()

    app.buttons["stress-sequence-1"].tap()

    // Wait for the sequence to finish dispatching
    XCTAssertTrue(waitForStatus("done-1"),
                   "Sequence 1 should complete")

    // The final state is [Settings]. Wait for all animations to settle.
    // Settings should be the visible sheet.
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15),
                   "Settings sheet should be visible as final state of sequence 1")
  }

  /// Sequence 2: push([Settings, Profile]) → popToRoot() → push(Account)
  /// Expected final: [Account] — only Account sheet visible.
  func testStressSequence2_PushPopToRootPush() {
    scrollToStressTests()

    app.buttons["stress-sequence-2"].tap()

    XCTAssertTrue(waitForStatus("done-2"),
                   "Sequence 2 should complete")

    // Final state is [Account]
    XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 15),
                   "Account sheet should be visible as final state of sequence 2")
  }

  /// Sequence 3: push(Settings) → push(Profile) → push(Account)
  /// Each with 200ms delay. Expected final: [Settings, Profile, Account].
  /// Account should be the topmost sheet.
  func testStressSequence3_RapidSinglePushes() {
    scrollToStressTests()

    app.buttons["stress-sequence-3"].tap()

    XCTAssertTrue(waitForStatus("done-3"),
                   "Sequence 3 should complete")

    // The topmost sheet should be Account
    XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 20),
                   "Account sheet should be visible as topmost of sequence 3")
  }

  /// Sequence 4: push([Settings, Profile]) → replace(Account, at: 0) → push(Settings)
  /// Expected final: [Account, Profile, Settings].
  /// Settings should be the topmost sheet.
  func testStressSequence4_PushReplaceAtPush() {
    scrollToStressTests()

    app.buttons["stress-sequence-4"].tap()

    XCTAssertTrue(waitForStatus("done-4"),
                   "Sequence 4 should complete")

    // The topmost sheet should be Settings
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20),
                   "Settings sheet should be visible as topmost of sequence 4")
  }

  /// Sequence 5: push(Account fullscreen) → push(Settings sheet) → popToRoot → push(Profile)
  /// Exercises fullScreenCover + sheet layering, then full teardown and rebuild.
  /// Expected final: [Profile]
  func testStressSequence5_FullScreenCoverAndSheet() {
    scrollToStressTests()

    app.buttons["stress-sequence-5"].tap()

    XCTAssertTrue(waitForStatus("done-5"),
                   "Sequence 5 should complete")

    XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 20),
                   "Profile sheet should be visible as final state of sequence 5")
  }

  /// Sequence 6: push 3 destinations → rapid triple pop (no sleeps)
  /// Expected final: [] — root view should be accessible.
  func testStressSequence6_RapidPops() {
    scrollToStressTests()

    app.buttons["stress-sequence-6"].tap()

    XCTAssertTrue(waitForStatus("done-6"),
                   "Sequence 6 should complete")

    // After all pops, root should be reachable — check navigation bar title
    // (push-settings button may be scrolled off screen)
    XCTAssertTrue(app.navigationBars["Presentation"].waitForExistence(timeout: 20),
                   "Root view should be accessible after rapid pops")
  }

  /// Sequence 7: push(Settings) → wait → replace(Settings, at: 0) — same navigationID
  /// Data-only update: the sheet should stay visible without dismiss/present cycle.
  /// Expected final: [Settings]
  func testStressSequence7_DataOnlyReplace() {
    scrollToStressTests()

    app.buttons["stress-sequence-7"].tap()

    XCTAssertTrue(waitForStatus("done-7"),
                   "Sequence 7 should complete")

    // Settings should still be visible (never dismissed)
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10),
                   "Settings sheet should remain visible after data-only replace")
  }

  /// Sequence 8: push → popToRoot → push different → popToRoot → push final
  /// Multiple full-stack replacement cycles in rapid succession.
  /// Expected final: [Profile]
  func testStressSequence8_FullCycleReplacements() {
    scrollToStressTests()

    app.buttons["stress-sequence-8"].tap()

    XCTAssertTrue(waitForStatus("done-8"),
                   "Sequence 8 should complete")

    XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 20),
                   "Profile sheet should be visible as final state of sequence 8")
  }

  /// Sequence 9: push([Settings, Profile]) → wait → popToRoot + immediate push(Account)
  /// popToRoot and push in the same runloop tick — the queue must handle dismiss-then-present atomically.
  /// Expected final: [Account]
  func testStressSequence9_PopToRootImmediatePush() {
    scrollToStressTests()

    app.buttons["stress-sequence-9"].tap()

    XCTAssertTrue(waitForStatus("done-9"),
                   "Sequence 9 should complete")

    XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 20),
                   "Account should be visible as final state of sequence 9")
  }

  /// Sequence 10: push([Settings, Profile, Account]) → wait → popTo(at: 0)
  /// Partial pop: dismiss top 2 levels, keep the bottom one.
  /// Expected final: [Settings]
  func testStressSequence10_PartialPop() {
    scrollToStressTests()

    app.buttons["stress-sequence-10"].tap()

    XCTAssertTrue(waitForStatus("done-10"),
                   "Sequence 10 should complete")

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20),
                   "Settings should be visible as final state of sequence 10 (partial pop)")
  }

  /// Sequence 11: push(Settings) → immediate replace(Profile, at: 0)
  /// Same-tick replace with different navigationID. The coalesced onChange
  /// should see only [Profile], presenting Profile directly.
  /// Expected final: [Profile]
  func testStressSequence11_ImmediateReplace() {
    scrollToStressTests()

    app.buttons["stress-sequence-11"].tap()

    XCTAssertTrue(waitForStatus("done-11"),
                   "Sequence 11 should complete")

    XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 20),
                   "Profile should be visible as final state of sequence 11 (immediate replace)")
  }

  /// Sequence 12: push([Settings, Profile, Account]) → wait → pop → wait → push(Account)
  /// Pop one level then push a new one back. The stack goes [S,P,A]→[S,P]→[S,P,A].
  /// Expected final: [Settings, Profile, Account] — Account on top.
  func testStressSequence12_PopThenPush() {
    scrollToStressTests()

    app.buttons["stress-sequence-12"].tap()

    XCTAssertTrue(waitForStatus("done-12"),
                   "Sequence 12 should complete")

    XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 20),
                   "Account should be visible as topmost of sequence 12 (pop then push)")
  }

  /// Sequence 13: popToRoot (already empty) → popToRoot again → wait → push(Settings)
  /// Double popToRoot on empty path must not crash or corrupt state.
  /// Expected final: [Settings]
  func testStressSequence13_DoublePopToRootEmpty() {
    scrollToStressTests()

    app.buttons["stress-sequence-13"].tap()

    XCTAssertTrue(waitForStatus("done-13"),
                   "Sequence 13 should complete")

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20),
                   "Settings should be visible as final state of sequence 13 (double popToRoot on empty)")
  }

  /// Sequence 14: push(S) → pop → push(P) → pop → push(A)
  /// Interleaved push-pop cycles with different destinations each time.
  /// Expected final: [Account]
  func testStressSequence14_InterleavedPushPop() {
    scrollToStressTests()

    app.buttons["stress-sequence-14"].tap()

    XCTAssertTrue(waitForStatus("done-14"),
                   "Sequence 14 should complete")

    XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 20),
                   "Account should be visible as final state of sequence 14 (interleaved push-pop)")
  }

  /// Sequence 15: push([Settings, Profile, Account]) → popTo(SettingsDestination.self)
  /// Type-based popTo: dismiss everything above the last Settings occurrence.
  /// Expected final: [Settings]
  func testStressSequence15_PopToByType() {
    scrollToStressTests()

    app.buttons["stress-sequence-15"].tap()

    XCTAssertTrue(waitForStatus("done-15"),
                   "Sequence 15 should complete")

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20),
                   "Settings should be visible as final state of sequence 15 (popTo by type)")
  }

  /// Sequence 16: push([Settings, Profile]) → replace([Account, Settings])
  /// Full path replacement. The entire stack is swapped.
  /// Expected final: [Account, Settings] — Settings is the topmost sheet.
  func testStressSequence16_ReplaceFullPath() {
    scrollToStressTests()

    app.buttons["stress-sequence-16"].tap()

    XCTAssertTrue(waitForStatus("done-16"),
                   "Sequence 16 should complete")

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20),
                   "Settings should be visible as topmost of sequence 16 (replace full path)")
  }

  /// Sequence 17: push(Settings) → push(Settings) → pop()
  /// Duplicate navigationID: two sheets of the same type stacked, then pop one.
  /// Expected final: [Settings] — one Settings remains.
  func testStressSequence17_DuplicateNavigationID() {
    scrollToStressTests()

    app.buttons["stress-sequence-17"].tap()

    XCTAssertTrue(waitForStatus("done-17"),
                   "Sequence 17 should complete")

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20),
                   "Settings should be visible as final state of sequence 17 (duplicate navigationID)")
  }

  /// Sequence 18: push([Settings, Profile, Account]) → immediate pop()
  /// Pop while present animations haven't started yet.
  /// Expected final: [Settings, Profile] — Profile is topmost.
  func testStressSequence18_PopDuringPresent() {
    scrollToStressTests()

    app.buttons["stress-sequence-18"].tap()

    XCTAssertTrue(waitForStatus("done-18"),
                   "Sequence 18 should complete")

    XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 20),
                   "Profile should be visible as topmost of sequence 18 (pop during present)")
  }

  /// Sequence 19: push([Settings, Profile, Account]) → popToRoot → push(Profile)
  /// Verifies that presentation levels are reusable after a full stack teardown.
  /// Expected final: [Profile]
  func testStressSequence19_RecycledLevels() {
    scrollToStressTests()

    app.buttons["stress-sequence-19"].tap()

    XCTAssertTrue(waitForStatus("done-19"),
                   "Sequence 19 should complete")

    XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 20),
                   "Profile should be visible as final state of sequence 19 (recycled levels)")
  }

  /// Sequence 20: push([Settings, PushNotifications(id:"aaa")]) → replace PushNotifications(id:"bbb") at index 1
  /// Deep registration: PushNotificationsSettingsDestination is registered inside SettingsView, not at root.
  /// Same navigationID, different data → data-only update, no dismiss/present cycle.
  /// Expected final: [Settings, Notifications] with id "bbb" visible.
  func testStressSequence20_DeepRegistrationDataUpdate() {
    scrollToStressTests()

    app.buttons["stress-sequence-20"].tap()

    XCTAssertTrue(waitForStatus("done-20"),
                   "Sequence 20 should complete")

    // The PushNotificationsSettingsView has navigationTitle "Notifications"
    XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 20),
                   "Notifications should be visible as topmost of sequence 20 (deep registration)")

    // Verify the id was updated to "bbb" — PushNotificationsSettingsView shows the id in a Text view.
    // Use a predicate to find the text since it might need a moment to update.
    let idText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "bbb")).firstMatch
    XCTAssertTrue(idText.waitForExistence(timeout: 10),
                   "The destination id should have been updated to 'bbb' via data-only replace")
  }
}
