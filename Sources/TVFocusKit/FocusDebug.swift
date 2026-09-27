import Observation
import SwiftUI
import os
#if canImport(UIKit)
import UIKit
#endif

/// A focus change seen by ``FocusMonitor``.
public struct FocusEvent: Sendable, Identifiable, Equatable {
    public enum Kind: String, Sendable {
        /// Focus moved from one item to another.
        case moved
        /// The user tried to move focus and nothing could take it.
        case failed
    }

    public let id: Int
    public let date: Date
    public let kind: Kind
    /// The direction of the movement, such as `["right"]`, when known.
    public let heading: [String]
    /// A description of the item focus left, or was on when movement failed.
    public let from: String?
    /// A description of the newly focused item.
    public let to: String?

    /// A one-line summary such as `"right: Poster 3 → Poster 4"`.
    public var summary: String {
        let direction = heading.isEmpty ? "" : heading.joined(separator: "+") + ": "
        switch kind {
        case .moved: return "\(direction)\(from ?? "nothing") → \(to ?? "nothing")"
        case .failed: return "\(direction)blocked at \(from ?? "nothing")"
        }
    }
}

/// Watches the system focus engine and records what happens.
///
/// It reports failed movements, which the focus engine otherwise only reveals
/// through the `UIFocusDebugger` LLDB commands. Use it with
/// ``SwiftUICore/View/focusDebugOverlay(_:)`` or read ``events`` directly.
@MainActor
@Observable
public final class FocusMonitor {
    /// The shared monitor, started by the debug overlay.
    public static let shared = FocusMonitor()

    /// Recent events, newest last.
    public private(set) var events: [FocusEvent] = []
    /// The focused item's frame in window coordinates.
    public private(set) var focusedFrame: CGRect?
    /// A description of the focused item.
    public private(set) var focusedDescription: String?
    /// Whether events are also written to the unified log
    /// (subsystem `TVFocusKit`, category `focus`).
    public var logsEvents = false
    /// How many events to keep.
    public var capacity = 20

    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var nextID = 0
    @ObservationIgnored private var clients = 0
    private static let logger = Logger(subsystem: "TVFocusKit", category: "focus")

    public init() {}

    /// Starts observing. Balanced calls to ``stop()`` stop it again.
    public func start() {
        clients += 1
        guard clients == 1 else { return }
        #if canImport(UIKit) && !os(watchOS)
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIFocusSystem.didUpdateNotification, object: nil, queue: .main) { [weak self] note in
                // Delivered on the main queue; the notification never leaves it.
                nonisolated(unsafe) let note = note
                MainActor.assumeIsolated { self?.record(FocusSnapshot(note, failed: false)) }
            },
            center.addObserver(forName: UIFocusSystem.movementDidFailNotification, object: nil, queue: .main) { [weak self] note in
                // Delivered on the main queue; the notification never leaves it.
                nonisolated(unsafe) let note = note
                MainActor.assumeIsolated { self?.record(FocusSnapshot(note, failed: true)) }
            },
        ]
        #endif
    }

    public func stop() {
        guard clients > 0 else { return }
        clients -= 1
        guard clients == 0 else { return }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
    }

    /// Clears recorded events.
    public func reset() {
        events = []
    }

    func record(_ snapshot: FocusSnapshot) {
        nextID += 1
        let event = FocusEvent(
            id: nextID,
            date: Date(),
            kind: snapshot.failed ? .failed : .moved,
            heading: snapshot.heading,
            from: snapshot.from,
            to: snapshot.to
        )
        events.append(event)
        if events.count > capacity { events.removeFirst(events.count - capacity) }
        if !snapshot.failed {
            focusedFrame = snapshot.frame
            focusedDescription = snapshot.to
        }
        if logsEvents {
            if snapshot.failed {
                Self.logger.warning("Focus movement failed: \(event.summary, privacy: .public)")
            } else {
                Self.logger.debug("Focus: \(event.summary, privacy: .public)")
            }
        }
    }
}

/// The parts of a focus notification the monitor keeps.
struct FocusSnapshot: Sendable {
    var failed: Bool
    var heading: [String]
    var from: String?
    var to: String?
    var frame: CGRect?

    init(failed: Bool, heading: [String] = [], from: String? = nil, to: String? = nil, frame: CGRect? = nil) {
        self.failed = failed
        self.heading = heading
        self.from = from
        self.to = to
        self.frame = frame
    }
}

#if canImport(UIKit) && !os(watchOS)
@MainActor
extension FocusSnapshot {
    init(_ notification: Notification, failed: Bool) {
        self.init(failed: failed)
        guard let context = notification.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext else { return }
        heading = Self.names(for: context.focusHeading)
        from = context.previouslyFocusedItem.map(Self.describe)
        if failed {
            // A failed movement has no next item; report where focus is stuck.
            from = from ?? context.nextFocusedItem.map(Self.describe)
        } else {
            to = context.nextFocusedItem.map(Self.describe)
            frame = context.nextFocusedItem.flatMap(Self.windowFrame)
        }
    }

    static func names(for heading: UIFocusHeading) -> [String] {
        var names: [String] = []
        if heading.contains(.up) { names.append("up") }
        if heading.contains(.down) { names.append("down") }
        if heading.contains(.left) { names.append("left") }
        if heading.contains(.right) { names.append("right") }
        if heading.contains(.next) { names.append("next") }
        if heading.contains(.previous) { names.append("previous") }
        return names
    }

    /// Accessibility label, then identifier, then the type name.
    static func describe(_ item: any UIFocusItem) -> String {
        let object = item as? NSObject
        if let label = object?.accessibilityLabel, !label.isEmpty { return label }
        if let identifier = (item as? any UIAccessibilityIdentification)?.accessibilityIdentifier, !identifier.isEmpty { return identifier }
        return String(describing: type(of: item))
    }

    static func windowFrame(of item: any UIFocusItem) -> CGRect? {
        if let view = item as? UIView {
            return view.window == nil ? nil : view.convert(view.bounds, to: nil)
        }
        guard let container = item.parentFocusEnvironment?.focusItemContainer else { return nil }
        let window = sequence(first: item.parentFocusEnvironment, next: { $0?.parentFocusEnvironment })
            .lazy.compactMap { $0 as? UIView }.first?.window
        guard let window else { return nil }
        return container.coordinateSpace.convert(item.frame, to: window.coordinateSpace)
    }
}
#endif

extension View {
    /// Outlines the focused item and lists recent focus events, including
    /// failed movements, over this view.
    ///
    /// Apply it once near the root, typically only in debug builds:
    ///
    /// ```swift
    /// ContentView()
    ///     #if DEBUG
    ///     .focusDebugOverlay()
    ///     #endif
    /// ```
    public func focusDebugOverlay(_ isEnabled: Bool = true) -> some View {
        modifier(FocusDebugOverlay(isEnabled: isEnabled))
    }
}

struct FocusDebugOverlay: ViewModifier {
    var isEnabled: Bool
    @State private var monitor = FocusMonitor.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if isEnabled {
                    GeometryReader { geometry in
                        let origin = geometry.frame(in: .global).origin
                        ZStack(alignment: .bottomLeading) {
                            if let frame = monitor.focusedFrame {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.yellow, style: StrokeStyle(lineWidth: 4, dash: [12, 6]))
                                    .frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX - origin.x, y: frame.midY - origin.y)
                            }
                            FocusEventList(events: monitor.events.suffix(6))
                                .padding(24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .ignoresSafeArea()
                }
            }
            .onAppear { if isEnabled { monitor.start() } }
            .onDisappear { if isEnabled { monitor.stop() } }
            .onChange(of: isEnabled) { _, enabled in
                if enabled { monitor.start() } else { monitor.stop() }
            }
    }
}

struct FocusEventList: View {
    var events: ArraySlice<FocusEvent>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(events) { event in
                Text(event.summary)
                    .foregroundStyle(event.kind == .failed ? .red : .white)
            }
        }
        .font(.system(size: fontSize, design: .monospaced))
        .padding(12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        .opacity(events.isEmpty ? 0 : 1)
    }

    private var fontSize: CGFloat {
        #if os(tvOS)
        22
        #else
        11
        #endif
    }
}
