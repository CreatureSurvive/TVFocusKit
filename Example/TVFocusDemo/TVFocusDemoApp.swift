import SwiftUI
import TVFocusKit

@main
struct TVFocusDemoApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-plain") {
                PlainRows()
            } else {
                ShelfDemo()
            }
        }
    }
}

struct Item: Identifiable, Hashable {
    let row: Int
    let index: Int
    var id: String { "r\(row)i\(index)" }
}

struct Row: Identifiable {
    let id: Int
    let items: [Item]
}

let rows = (0..<5).map { row in Row(id: row, items: (0..<12).map { Item(row: row, index: $0) }) }

struct Tile: View {
    let item: Item
    var body: some View {
        Button {} label: {
            Text(item.id)
                .font(.headline)
                .frame(width: 260, height: 150)
        }
        .accessibilityIdentifier(item.id)
    }
}

/// Rows built with TVFocusKit.
struct ShelfDemo: View {
    @State private var lateItems: [Item] = []
    @FocusState private var lateFocus: Item.ID?
    @State private var monitor = FocusMonitor.shared

    var body: some View {
        ShelfStack(rows) { row in
            FocusShelf("Row \(row.id)", row.items) { item in
                Tile(item: item)
            }
        } header: {
            HStack(spacing: 40) {
                Button("Load Late Row") {
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        lateItems = (0..<6).map { Item(row: 9, index: $0) }
                    }
                }
                .accessibilityIdentifier("loadLate")
                Text(monitor.events.last?.summary ?? "")
                    .accessibilityIdentifier("focusLog")
                    .font(.caption)

            }
            .padding(.horizontal, 80)
            if !lateItems.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 40) {
                        ForEach(lateItems) { item in
                            Tile(item: item).focused($lateFocus, equals: item.id)
                        }
                    }
                    .padding(40)
                }
                .requestFocus($lateFocus, to: lateItems.dropFirst(3).first?.id, trigger: lateItems.count)
            }
        }
        .focusDebugOverlay(ProcessInfo.processInfo.arguments.contains("-debugOverlay"))
        .onAppear { monitor.start() }
    }
}

/// The same rows with plain SwiftUI, for comparison.
struct PlainRows: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                ForEach(rows) { row in
                    VStack(alignment: .leading) {
                        Text("Row \(row.id)").font(.headline).padding(.horizontal, 80)
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 48) {
                                ForEach(row.items) { Tile(item: $0) }
                            }
                            .padding(.horizontal, 80)
                            .padding(.vertical, 40)
                        }
                    }
                }
            }
        }
    }
}
