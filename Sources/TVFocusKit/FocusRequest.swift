import SwiftUI

extension View {
    /// Moves focus to `value` whenever `trigger` changes, retrying until the
    /// target view can actually take focus.
    ///
    /// Assigning a `@FocusState` in `onAppear` or right after data loads often
    /// does nothing, because the target isn't in the focus hierarchy yet. This
    /// keeps assigning on successive frames until focus lands or `timeout`
    /// passes.
    ///
    /// ```swift
    /// .requestFocus($focusedItem, to: items.first?.id, trigger: items.count)
    /// ```
    ///
    /// - Parameters:
    ///   - focus: The focus state to set.
    ///   - value: The target. `nil` does nothing.
    ///   - trigger: Requests focus on appear and whenever this changes.
    ///   - timeout: How long to keep trying.
    public func requestFocus<Value: Hashable, Trigger: Equatable>(
        _ focus: FocusState<Value?>.Binding,
        to value: Value?,
        trigger: Trigger,
        timeout: Duration = .seconds(1)
    ) -> some View {
        task(id: trigger) {
            guard let value else { return }
            await FocusRequester.request(value, timeout: timeout, current: { focus.wrappedValue }, assign: { focus.wrappedValue = $0 })
        }
    }

    /// Moves focus to `value` when the view appears, retrying until it lands.
    public func requestFocus<Value: Hashable>(_ focus: FocusState<Value?>.Binding, to value: Value?, timeout: Duration = .seconds(1)) -> some View {
        requestFocus(focus, to: value, trigger: 0, timeout: timeout)
    }
}

@MainActor
enum FocusRequester {
    /// Assigns `value` until `current()` reports it, or the timeout passes.
    /// Returns whether focus landed.
    @discardableResult
    static func request<Value: Equatable>(
        _ value: Value,
        timeout: Duration,
        interval: Duration = .milliseconds(16),
        current: () -> Value?,
        assign: (Value) -> Void
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while true {
            if current() == value { return true }
            assign(value)
            // Focus updates land on a later run loop turn.
            await Task.yield()
            if current() == value { return true }
            guard ContinuousClock.now < deadline, !Task.isCancelled else { return current() == value }
            try? await Task.sleep(for: interval)
        }
    }
}
