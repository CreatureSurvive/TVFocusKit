import SwiftUI

/// Layout of a ``FocusShelf``.
public struct FocusShelfStyle: Sendable {
    /// Space between items.
    public var spacing: CGFloat = 48
    /// Leading and trailing inset of the first and last item.
    public var horizontalMargin: CGFloat = 80
    /// Extra room above and below items, so focus lift and shadows aren't clipped.
    public var focusOverflow: CGFloat = 40
    /// Space between the header and the items.
    public var headerSpacing: CGFloat = 12

    public init() {}

    /// Compact values for iOS, macOS and visionOS.
    public static var platformDefault: FocusShelfStyle {
        var style = FocusShelfStyle()
        #if !os(tvOS)
        style.spacing = 12
        style.horizontalMargin = 16
        style.focusOverflow = 8
        style.headerSpacing = 8
        #endif
        return style
    }
}

extension EnvironmentValues {
    @Entry public var focusShelfStyle = FocusShelfStyle.platformDefault
}

extension View {
    /// Sets the layout of ``FocusShelf`` views in this hierarchy.
    public func focusShelfStyle(_ style: FocusShelfStyle) -> some View {
        environment(\.focusShelfStyle, style)
    }
}

/// A horizontally scrolling row of focusable items: the "shelf" of every
/// media app.
///
/// Compared with a plain `ScrollView` + `LazyHStack`, a shelf:
///
/// - remembers its focused item, so moving up to a row returns to where you
///   were instead of the geometrically nearest item;
/// - is a focus section, so moving down from a short row still reaches the
///   next row;
/// - doesn't clip focused items as they scale up;
/// - reports focus to an enclosing ``ShelfStack``, which scrolls the row into
///   place and handles the Menu button.
///
/// The content closure must return a focusable view, such as a `Button` or
/// `NavigationLink`.
///
/// ```swift
/// FocusShelf(movies) { movie in
///     Button { play(movie) } label: { Poster(movie) }
///         .buttonStyle(.borderless)
/// } header: {
///     Text("Continue Watching").font(.headline)
/// }
/// ```
public struct FocusShelf<Data: RandomAccessCollection, ID: Hashable, Content: View, Header: View>: View {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let content: (Data.Element) -> Content
    private let header: Header

    @FocusState private var focused: ID?
    @State private var memory = FocusMemory<ID>()
    @Environment(\.focusShelfStyle) private var style
    @Environment(ShelfCoordinator.self) private var coordinator: ShelfCoordinator?
    @Environment(\.shelfIndex) private var shelfIndex
    @Environment(\.shelfFocusNamespace) private var focusNamespace
    #if os(tvOS) || os(macOS)
    @Environment(\.resetFocus) private var resetFocus
    #endif

    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping (Data.Element) -> Content,
        @ViewBuilder header: () -> Header
    ) {
        self.data = data
        self.id = id
        self.content = content
        self.header = header()
    }

    private var prefersStart: Bool {
        shelfIndex == 0 && coordinator?.prefersStart == true
    }

    public var body: some View {
        let resetToken = coordinator?.resetToken
        return VStack(alignment: .leading, spacing: style.headerSpacing) {
            header
                .padding(.horizontal, style.horizontalMargin)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: style.spacing) {
                        ForEach(data, id: id) { element in
                            content(element)
                                .focused($focused, equals: element[keyPath: id])
                                .modifier(StartPreference(
                                    isPreferred: prefersStart && element[keyPath: id] == data.first?[keyPath: id],
                                    namespace: focusNamespace
                                ))
                                .id(element[keyPath: id])
                        }
                    }
                    .padding(.vertical, style.focusOverflow)
                }
                .scrollClipDisabled()
                .contentMargins(.horizontal, style.horizontalMargin, for: .scrollContent)
                .task(id: resetToken) {
                    guard let coordinator, coordinator.resetToken > 0, coordinator.resetTarget == shelfIndex,
                          let first = data.first?[keyPath: id] else { return }
                    // By now the first item is marked as the scope's preferred
                    // focus. Re-evaluating the scope moves focus there even
                    // from shelves out of view, which assigning the focus
                    // state alone can't do.
                    #if os(tvOS) || os(macOS)
                    if let focusNamespace { resetFocus(in: focusNamespace) }
                    #endif
                    await FocusRequester.request(first, timeout: .seconds(1), current: { focused }, assign: { focused = $0 })
                }
            }
            .padding(.vertical, -style.focusOverflow)
        }
        #if os(tvOS) || os(macOS)
        .focusSection()
        #endif
        // Before anything is remembered, nil lets the focus engine pick the
        // geometrically nearest item as usual.
        .defaultFocus($focused, memory.remembered, priority: .userInitiated)
        .onChange(of: focused) { _, newValue in
            memory.record(newValue)
            if let newValue, let shelfIndex {
                coordinator?.shelfDidFocus(shelfIndex, isFirstItem: newValue == data.first?[keyPath: id])
            }
        }
        .onChange(of: data.map { $0[keyPath: id] }) { _, ids in
            memory.prune(keeping: ids)
        }
    }
}

extension FocusShelf where Header == EmptyView {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data, id: id, content: content) { EmptyView() }
    }
}

extension FocusShelf where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content, @ViewBuilder header: () -> Header) {
        self.init(data, id: \.id, content: content, header: header)
    }
}

extension FocusShelf where Data.Element: Identifiable, ID == Data.Element.ID, Header == EmptyView {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data, id: \.id, content: content) { EmptyView() }
    }
}

extension FocusShelf where Header == Text {
    public init(_ title: LocalizedStringKey, _ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data, id: id, content: content) { Text(title).font(.headline) }
    }
}

extension FocusShelf where Header == Text, Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ title: LocalizedStringKey, _ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data, id: \.id, content: content) { Text(title).font(.headline) }
    }
}

/// Marks the first item of the first shelf as the preferred default focus
/// in the stack's focus scope while returning to the start.
struct StartPreference: ViewModifier {
    var isPreferred: Bool
    var namespace: Namespace.ID?

    func body(content: Content) -> some View {
        #if os(tvOS) || os(macOS)
        if let namespace {
            content.prefersDefaultFocus(isPreferred, in: namespace)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
