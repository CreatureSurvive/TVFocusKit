import Foundation
import Testing
@testable import TVFocusKit

@Suite("FocusMemory")
struct FocusMemoryTests {
    @Test func remembersTheLastNonNilValue() {
        var memory = FocusMemory<Int>()
        #expect(memory.remembered == nil)
        memory.record(3)
        memory.record(nil) // focus left the container
        #expect(memory.remembered == 3)
        memory.record(5)
        #expect(memory.remembered == 5)
    }

    @Test func forgetsRemovedItems() {
        var memory = FocusMemory<String>()
        memory.record("b")
        memory.prune(keeping: ["a", "b", "c"])
        #expect(memory.remembered == "b")
        memory.prune(keeping: ["a", "c"])
        #expect(memory.remembered == nil)
    }
}

@MainActor
@Suite("FocusRequester")
struct FocusRequesterTests {
    final class FakeFocus {
        var value: Int?
        var assignments = 0
        /// Assignments are ignored until this many have been attempted,
        /// like a view that isn't in the focus hierarchy yet.
        var ignoreFirst: Int

        init(ignoreFirst: Int) { self.ignoreFirst = ignoreFirst }

        func assign(_ newValue: Int) {
            assignments += 1
            if assignments > ignoreFirst { value = newValue }
        }
    }

    @Test func retriesUntilFocusLands() async {
        let focus = FakeFocus(ignoreFirst: 3)
        let landed = await FocusRequester.request(7, timeout: .seconds(2), interval: .milliseconds(1), current: { focus.value }, assign: { focus.assign($0) })
        #expect(landed)
        #expect(focus.value == 7)
        #expect(focus.assignments == 4)
    }

    @Test func doesNothingWhenAlreadyFocused() async {
        let focus = FakeFocus(ignoreFirst: 0)
        focus.value = 7
        #expect(await FocusRequester.request(7, timeout: .seconds(1), current: { focus.value }, assign: { focus.assign($0) }))
        #expect(focus.assignments == 0)
    }

    @Test func givesUpAfterTheTimeout() async {
        let focus = FakeFocus(ignoreFirst: .max)
        let start = ContinuousClock.now
        let landed = await FocusRequester.request(1, timeout: .milliseconds(100), interval: .milliseconds(5), current: { focus.value }, assign: { focus.assign($0) })
        #expect(!landed)
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    @Test func stopsWhenCancelled() async {
        let focus = FakeFocus(ignoreFirst: .max)
        let task = Task { @MainActor in
            await FocusRequester.request(1, timeout: .seconds(30), interval: .milliseconds(5), current: { focus.value }, assign: { focus.assign($0) })
        }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        #expect(await task.value == false)
    }
}

@MainActor
@Suite("ShelfCoordinator")
struct ShelfCoordinatorTests {
    @Test func menuPassesThroughOnlyAtTheStart() {
        let coordinator = ShelfCoordinator()
        #expect(coordinator.isAtStart, "nothing focused yet: let the system handle Menu")
        coordinator.shelfDidFocus(0, isFirstItem: true)
        #expect(coordinator.isAtStart)
        coordinator.shelfDidFocus(0, isFirstItem: false)
        #expect(!coordinator.isAtStart, "partway along the first shelf")
        coordinator.shelfDidFocus(2, isFirstItem: true)
        #expect(!coordinator.isAtStart, "first item of a later shelf")
    }

    @Test func returningToStartTargetsTheFirstShelfUntilItHasFocus() {
        let coordinator = ShelfCoordinator()
        coordinator.shelfDidFocus(3, isFirstItem: false)
        coordinator.returnToStart()
        #expect(coordinator.resetTarget == 0)
        #expect(coordinator.resetToken == 1)
        #expect(coordinator.prefersStart)
        coordinator.shelfDidFocus(1, isFirstItem: true)
        #expect(coordinator.prefersStart, "still returning")
        coordinator.shelfDidFocus(0, isFirstItem: true)
        #expect(!coordinator.prefersStart)
        coordinator.returnToStart()
        #expect(coordinator.resetToken == 2)
    }
}

@Suite("FocusEvent")
struct FocusEventTests {
    @Test func summaries() {
        let moved = FocusEvent(id: 1, date: Date(), kind: .moved, heading: ["right"], from: "Poster 3", to: "Poster 4")
        #expect(moved.summary == "right: Poster 3 → Poster 4")
        let blocked = FocusEvent(id: 2, date: Date(), kind: .failed, heading: ["left"], from: "Poster 1", to: nil)
        #expect(blocked.summary == "left: blocked at Poster 1")
        let programmatic = FocusEvent(id: 3, date: Date(), kind: .moved, heading: [], from: nil, to: "Play")
        #expect(programmatic.summary == "nothing → Play")
    }

    @MainActor
    @Test func monitorKeepsARollingWindow() {
        let monitor = FocusMonitor()
        monitor.capacity = 3
        for index in 0..<5 {
            monitor.record(FocusSnapshot(failed: index == 4, heading: ["down"], from: "\(index)", to: "\(index + 1)", frame: CGRect(x: index, y: 0, width: 10, height: 10)))
        }
        #expect(monitor.events.map(\.from) == ["2", "3", "4"])
        #expect(monitor.events.last?.kind == .failed)
        #expect(monitor.focusedDescription == "4", "failed moves don't change the focused item")
        #expect(monitor.focusedFrame?.minX == 3)
        monitor.reset()
        #expect(monitor.events.isEmpty)
    }

    @MainActor
    @Test func startAndStopAreBalanced() {
        let monitor = FocusMonitor()
        monitor.start()
        monitor.start()
        monitor.stop()
        monitor.stop()
        monitor.stop() // extra stops are harmless
    }
}

@Suite("FocusShelfStyle")
struct StyleTests {
    @Test func platformDefaults() {
        let style = FocusShelfStyle.platformDefault
        #if os(tvOS)
        #expect(style.spacing == 48)
        #else
        #expect(style.spacing == 12)
        #endif
        #expect(style.focusOverflow > 0)
    }
}
