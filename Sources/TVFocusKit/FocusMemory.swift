import SwiftUI

extension View {
    /// Returns focus to the last focused item when focus re-enters this view.
    ///
    /// On tvOS, moving focus into a row or grid picks the item geometrically
    /// closest to the previous one, so returning to a row you scrolled lands
    /// on a different item. Apply this to the container (usually along with
    /// `focusSection()`) and bind each item with `.focused(binding, equals:)`:
    ///
    /// ```swift
    /// @FocusState private var focusedEpisode: Episode.ID?
    ///
    /// ScrollView(.horizontal) {
    ///     LazyHStack {
    ///         ForEach(episodes) { episode in
    ///             EpisodeCard(episode).focused($focusedEpisode, equals: episode.id)
    ///         }
    ///     }
    /// }
    /// .focusSection()
    /// .remembersFocus($focusedEpisode, initial: episodes.first?.id)
    /// ```
    ///
    /// - Parameters:
    ///   - focus: The focus state the container's items are bound to.
    ///   - initial: The item to focus the first time focus enters, before
    ///     anything has been focused.
    public func remembersFocus<Value: Hashable>(_ focus: FocusState<Value?>.Binding, initial: Value? = nil) -> some View {
        modifier(FocusMemoryModifier(focus: focus, initial: initial))
    }
}

struct FocusMemoryModifier<Value: Hashable>: ViewModifier {
    var focus: FocusState<Value?>.Binding
    var initial: Value?

    @State private var memory = FocusMemory<Value>()

    func body(content: Content) -> some View {
        content
            .defaultFocus(focus, memory.remembered ?? initial, priority: .userInitiated)
            .onChange(of: focus.wrappedValue) { _, newValue in
                memory.record(newValue)
            }
    }
}

/// The last focused value of a container, ignoring losses of focus.
struct FocusMemory<Value: Hashable> {
    private(set) var remembered: Value?

    mutating func record(_ value: Value?) {
        if let value { remembered = value }
    }

    /// Forgets the remembered value if it's no longer one of `valid`, for
    /// example after the item was deleted.
    mutating func prune(keeping valid: some Sequence<Value>) {
        guard let remembered else { return }
        if !valid.contains(remembered) { self.remembered = nil }
    }
}
