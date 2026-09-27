import SwiftUI
import TVFocusKit

/// A media-style home screen for the README screenshots (`-showcase`).
struct ShowcaseView: View {
    struct Title: Identifiable, Hashable {
        let id: String
        let name: String
        let detail: String
        let symbol: String
        let colors: [Color]
    }

    struct Shelf: Identifiable {
        let id: String
        let titles: [Title]
    }

    static let palettes: [[Color]] = [
        [.indigo, .purple], [.teal, .blue], [.orange, .pink], [.mint, .teal], [.pink, .purple],
        [.blue, .cyan], [.red, .orange], [.green, .mint], [.purple, .blue], [.yellow, .orange],
    ]

    static let shelves: [Shelf] = [
        Shelf(id: "Continue Watching", titles: make([
            ("Northern Lights", "S2 · E4", "sparkles"), ("The Long Drive", "S1 · E7", "car.fill"),
            ("Deep Blue", "S3 · E1", "water.waves"), ("Summit", "Movie · 42 min left", "mountain.2.fill"),
            ("Night Shift", "S1 · E2", "moon.stars.fill"), ("Harvest", "S4 · E9", "leaf.fill"),
        ])),
        Shelf(id: "Recently Added", titles: make([
            ("Lighthouse", "Movie · 2025", "light.beacon.max.fill"), ("Afterglow", "Movie · 2024", "sun.horizon.fill"),
            ("Paper Planes", "Series · 3 seasons", "paperplane.fill"), ("Static", "Movie · 2026", "antenna.radiowaves.left.and.right"),
            ("Tidewater", "Series · 1 season", "drop.fill"), ("Orbit", "Movie · 2023", "globe.americas.fill"),
        ], offset: 3)),
        Shelf(id: "Top Picks for You", titles: make([
            ("Wildfire", "Documentary", "flame.fill"), ("Quiet Streets", "Drama", "building.2.fill"),
            ("Signal", "Thriller", "waveform"), ("Evergreen", "Family", "tree.fill"),
            ("Gravity Well", "Sci-Fi", "circle.hexagongrid.fill"), ("Salt", "Food", "fork.knife"),
        ], offset: 6)),
    ]

    static func make(_ items: [(String, String, String)], offset: Int = 0) -> [Title] {
        items.enumerated().map { index, item in
            Title(id: item.0, name: item.0, detail: item.1, symbol: item.2, colors: palettes[(index + offset) % palettes.count])
        }
    }

    var body: some View {
        ShelfStack(Self.shelves) { shelf in
            FocusShelf(shelf.titles) { title in
                Button {} label: { Card(title: title) }
                    .buttonStyle(.card)
                    .accessibilityIdentifier(title.id)
            } header: {
                Text(shelf.id).font(.title3.bold())
            }
        }
        .padding(.top, 40)
        .focusDebugOverlay(ProcessInfo.processInfo.arguments.contains("-debugOverlay"))
        .background(Color(white: 0.06))
        .preferredColorScheme(.dark)
    }

    struct Card: View {
        let title: Title

        var body: some View {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: title.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: title.symbol)
                    .font(.system(size: 90, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.name).font(.headline).foregroundStyle(.white)
                    Text(title.detail).font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                .padding(24)
            }
            .frame(width: 380, height: 214)
        }
    }
}
