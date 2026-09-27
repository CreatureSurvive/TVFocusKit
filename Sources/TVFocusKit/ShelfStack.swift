import Observation
import SwiftUI

/// A vertical stack of shelves that behaves like the Apple TV app.
///
/// - The shelf that takes focus scrolls to a fixed position (the top by
///   default), instead of the minimal scroll that leaves rows half visible.
/// - The Menu button first returns focus to the start of the first shelf;
///   once there, it performs the system action (going back or to the tab bar).
///
/// Put a ``FocusShelf`` in each row:
///
/// ```swift
/// ShelfStack(sections) { section in
///     FocusShelf(section.title, section.items) { item in
///         Button { open(item) } label: { Poster(item) }
///     }
/// }
/// ```
public struct ShelfStack<Data: RandomAccessCollection, ID: Hashable, Row: View, Header: View>: View {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let row: (Data.Element) -> Row
    private let header: Header
    private let anchor: UnitPoint
    private let spacing: CGFloat

    @State private var coordinator = ShelfCoordinator()
    #if os(tvOS) || os(macOS)
    @Namespace private var focusNamespace
    #endif

    /// - Parameters:
    ///   - anchor: Where the focused shelf is scrolled to. `nil` keeps the
    ///     default minimal scrolling.
    ///   - spacing: Space between shelves.
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        anchor: UnitPoint? = .top,
        spacing: CGFloat? = nil,
        @ViewBuilder row: @escaping (Data.Element) -> Row,
        @ViewBuilder header: () -> Header
    ) {
        self.data = data
        self.id = id
        self.row = row
        self.header = header()
        self.anchor = anchor ?? .center
        self.coordinatorScrolls = anchor != nil
        #if os(tvOS)
        self.spacing = spacing ?? 40
        #else
        self.spacing = spacing ?? 20
        #endif
    }

    private let coordinatorScrolls: Bool

    private var indexedRows: [IndexedRow<Data.Element, ID>] {
        data.enumerated().map { IndexedRow(index: $0.offset, id: $0.element[keyPath: id], element: $0.element) }
    }

    public var body: some View {
        // Read observable state here, in the body, so changes re-render; reads
        // inside ScrollViewReader's closure aren't tracked.
        let focusedShelf = coordinator.focusedShelf
        let isAtStart = coordinator.isAtStart
        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: spacing) {
                    header
                        .id(ShelfStackTop.top)
                    ForEach(indexedRows, id: \.id) { entry in
                        row(entry.element)
                            .environment(\.shelfIndex, entry.index)
                            .id(entry.id)
                    }
                }
            }
            .scrollClipDisabled()
            .environment(coordinator)
            #if os(tvOS) || os(macOS)
            .focusScope(focusNamespace)
            .environment(\.shelfFocusNamespace, focusNamespace)
            #endif
            .onChange(of: focusedShelf) { _, index in
                guard coordinatorScrolls, let index, index < data.count else { return }
                let target = data[data.index(data.startIndex, offsetBy: index)][keyPath: id]
                withAnimation(.easeInOut(duration: 0.3)) {
                    if index == 0 {
                        proxy.scrollTo(ShelfStackTop.top, anchor: .top)
                    } else {
                        proxy.scrollTo(target, anchor: anchor)
                    }
                }
            }
            #if os(tvOS) || os(macOS)
            .onExitCommand(perform: isAtStart ? nil : {
                // Jump (without animation) so the first shelf is loaded; it
                // then takes focus (see FocusShelf).
                proxy.scrollTo(ShelfStackTop.top, anchor: .top)
                coordinator.returnToStart()
            })
            #endif
        }
    }
}

enum ShelfStackTop: Hashable { case top }

struct IndexedRow<Element, ID: Hashable> {
    let index: Int
    let id: ID
    let element: Element
}

extension ShelfStack where Header == EmptyView {
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        anchor: UnitPoint? = .top,
        spacing: CGFloat? = nil,
        @ViewBuilder row: @escaping (Data.Element) -> Row
    ) {
        self.init(data, id: id, anchor: anchor, spacing: spacing, row: row) { EmptyView() }
    }
}

extension ShelfStack where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(
        _ data: Data,
        anchor: UnitPoint? = .top,
        spacing: CGFloat? = nil,
        @ViewBuilder row: @escaping (Data.Element) -> Row,
        @ViewBuilder header: () -> Header
    ) {
        self.init(data, id: \.id, anchor: anchor, spacing: spacing, row: row, header: header)
    }
}

extension ShelfStack where Data.Element: Identifiable, ID == Data.Element.ID, Header == EmptyView {
    public init(
        _ data: Data,
        anchor: UnitPoint? = .top,
        spacing: CGFloat? = nil,
        @ViewBuilder row: @escaping (Data.Element) -> Row
    ) {
        self.init(data, id: \.id, anchor: anchor, spacing: spacing, row: row) { EmptyView() }
    }
}

/// Shared focus state of a ``ShelfStack`` and its shelves.
@MainActor
@Observable
final class ShelfCoordinator {
    /// The index of the shelf containing focus.
    private(set) var focusedShelf: Int?
    /// Whether the focused item is the first item of its shelf.
    private(set) var focusedItemIsFirst = false
    /// Incremented to ask ``resetTarget`` to focus its first item.
    private(set) var resetToken = 0
    private(set) var resetTarget: Int?

    /// Whether focus is at the start of the first shelf, where the Menu
    /// button should perform its system action. Also true before anything
    /// has been focused.
    var isAtStart: Bool {
        guard let focusedShelf else { return true }
        return focusedShelf == 0 && focusedItemIsFirst
    }

    func shelfDidFocus(_ index: Int, isFirstItem: Bool) {
        focusedShelf = index
        focusedItemIsFirst = isFirstItem
        if index == 0 && isFirstItem { prefersStart = false }
    }

    /// Whether the first item of the first shelf should be the preferred
    /// default focus, while returning to the start.
    private(set) var prefersStart = false

    func returnToStart() {
        prefersStart = true
        resetTarget = 0
        resetToken &+= 1
    }
}

extension EnvironmentValues {
    /// The index of the enclosing ``ShelfStack`` row.
    @Entry var shelfIndex: Int? = nil
    /// The focus scope of the enclosing ``ShelfStack``.
    @Entry var shelfFocusNamespace: Namespace.ID? = nil
}
