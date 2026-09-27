# Changelog

## 1.0.1

- `FocusMonitor` and the debug overlay name SwiftUI items by their accessibility label or
  identifier. They used to show SwiftUI's internal type, `UIKitFocusableViewResponderItem`.
  An item focused at launch, before SwiftUI builds its accessibility elements, is named once
  they exist.
- Focus updates with no item on either side are no longer recorded.
- The example app has a `-showcase` mode and UI tests that capture the README screenshots.

## 1.0.0

- Initial release: `FocusShelf` (remembered focus, focus section, clip-free lift),
  `ShelfStack` (anchored row scrolling, Menu returns to start), `remembersFocus(_:initial:)`,
  `requestFocus(_:to:trigger:)`, and focus debugging with `FocusMonitor` and
  `focusDebugOverlay()`.
