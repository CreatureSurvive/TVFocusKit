# TVFocusKit

[![CI](https://github.com/CreatureSurvive/TVFocusKit/actions/workflows/ci.yml/badge.svg)](https://github.com/CreatureSurvive/TVFocusKit/actions/workflows/ci.yml)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20visionOS-blue)](#requirements)
[![Swift Package Manager](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](#installation)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

Focus tools for tvOS SwiftUI that fix what the focus engine gets wrong in real apps: rows that
forget where you were, focus requests that silently do nothing, Menu buttons that jump straight
out of the screen, clipped focus effects, and focus bugs you can't see.

```swift
import TVFocusKit

ShelfStack(sections) { section in
    FocusShelf(section.title, section.items) { item in
        Button { open(item) } label: { Poster(item) }
            .buttonStyle(.borderless)
    }
}
```

## The problems

| Problem in plain SwiftUI | TVFocusKit |
| --- | --- |
| Moving up to a row you scrolled lands on the geometrically nearest item, not the one you left. | `FocusShelf` and `.remembersFocus(_:)` return to the remembered item. A shelf's first entry still uses the nearest item, as users expect. |
| Setting a `@FocusState` in `onAppear` or after data loads often does nothing, because the target isn't focusable yet. | `.requestFocus(_:to:trigger:)` retries each frame until focus lands or it times out. |
| The Menu button leaves the screen from deep in a list. The Apple TV app first returns to the top. | `ShelfStack` returns focus to the start of the first shelf, then lets Menu perform its normal action. |
| Focus moves scroll the list minimally, leaving the focused row half visible. | `ShelfStack` scrolls the focused shelf to a fixed anchor (the top by default). |
| Focused items scale up and get clipped by the scroll view. | Shelves disable clipping and reserve room for the lift and its shadow. |
| "Why can't I move right?" can only be answered with LLDB. | `FocusMonitor` records every focus change and every blocked move. `.focusDebugOverlay()` outlines the focused item and lists recent events on screen. |

## Verified on the tvOS simulator

`Example/` is a tvOS app with UI tests that drive it with the Siri Remote (`XCUIRemote`):

- **Remembered focus:** in a shelf the test goes to item 2, moves down and right to item 5 of
  row 1, then back up, and lands on `r0i2`. The same moves with plain SwiftUI rows land on
  `r0i4`. The test records the plain result so the comparison stays honest.
- **Menu:** from row 3, Menu returns to `r0i0`, and a second press leaves the app. It also
  works from a visible row and from partway along the first row.
- **Late content:** focus requested for a row that loads 300 ms later lands on the requested
  item.
- **Monitor:** pressing left at the first item is logged as `left: blocked at r0i0`.

```sh
cd Example && xcodegen generate
xcodebuild test -project TVFocusDemo.xcodeproj -scheme TVFocusDemo \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)"
```

`swift test` covers the pure logic: focus memory, the focus request retry loop, the Menu state
machine, and the monitor's event window.

## API

### `FocusShelf`

A horizontal row of focusable items. The content closure must return a focusable view, such as
a `Button` or `NavigationLink`, because each item is bound with `.focused(_:equals:)`.

```swift
FocusShelf(episodes) { episode in
    Button { play(episode) } label: { EpisodeCard(episode) }
} header: {
    Label("Up Next", systemImage: "play.circle").font(.headline)
}
.focusShelfStyle({
    var style = FocusShelfStyle()
    style.spacing = 40
    return style
}())
```

A shelf works on its own, too. Inside a `ShelfStack` it also reports focus to the stack.

### `ShelfStack`

```swift
ShelfStack(rows, anchor: .top) { row in
    FocusShelf(row.title, row.items) { item in ItemButton(item) }
} header: {
    HeroBanner()
}
```

Pass `anchor: nil` to keep the system's minimal scrolling.

### Remembered focus for any container

```swift
@FocusState private var focusedEpisode: Episode.ID?

LazyVGrid(columns: columns) {
    ForEach(episodes) { episode in
        EpisodeCard(episode).focused($focusedEpisode, equals: episode.id)
    }
}
.focusSection()
.remembersFocus($focusedEpisode)
```

### Reliable programmatic focus

```swift
.requestFocus($focusedItem, to: results.first?.id, trigger: results.count)
```

### Debugging

```swift
ContentView()
    #if DEBUG
    .focusDebugOverlay()
    #endif

FocusMonitor.shared.logsEvents = true   // also log to Console (subsystem TVFocusKit)
```

## Installation

Add TVFocusKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CreatureSurvive/TVFocusKit.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["TVFocusKit"]),
]
```

Or in Xcode, choose **File › Add Package Dependencies…** and enter
`https://github.com/CreatureSurvive/TVFocusKit`.

### Requirements

| Platform | Minimum |
| --- | --- |
| iOS | 17.0 |
| macOS | 14.0 |
| tvOS | 17.0 |
| visionOS | 1.0 |

Swift 6.0 (Xcode 16) or later, in Swift 6 language mode. No third-party dependencies.

TVFocusKit is built for tvOS. It also compiles on the other platforms so shared code builds, but
focus sections and the Menu behavior only take effect on tvOS and macOS.

## Notes

- Returning to the start uses `focusScope`, `prefersDefaultFocus` and `resetFocus`. Assigning a
  `@FocusState` can't pull focus back across shelves the focus engine keeps scrolled into view.
- A shelf's first item marks the start. A header view above the shelves (a hero banner, for
  example) isn't part of it.

## Changelog

See [CHANGELOG.md](CHANGELOG.md). Releases follow [Semantic Versioning](https://semver.org).

## Contributing

Issues and pull requests are welcome. Please run `swift test` before opening a pull request, and
add tests for new behavior.

## License

Available under the MIT license. See [LICENSE](LICENSE) for details.
