import AppKit
import CoreGraphics

struct Options {
    var duration: TimeInterval = 60
    var persistent = false
    var sortByGeometry = false
    var centerOverlay = false
    var listDisplays = false

    static func parse(_ arguments: [String]) -> Options {
        var options = Options()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--persist", "--persistent", "-p":
                options.persistent = true
            case "--list":
                options.listDisplays = true
            case "--sort-geometry":
                options.sortByGeometry = true
            case "--center":
                options.centerOverlay = true
            case "--duration", "-d":
                if index + 1 < arguments.count,
                   let seconds = TimeInterval(arguments[index + 1]),
                   seconds > 0 {
                    options.duration = seconds
                    index += 1
                }
            case "--help", "-h":
                print("""
                display-identify

                Shows a numbered position badge on every connected macOS display.

                Options:
                  -d, --duration <seconds>   Auto-close after this many seconds. Default: 60
                  -p, --persist              Stay open until Esc or q
                      --persistent           Alias for --persist
                      --list                 Print detected displays and exit
                      --sort-geometry        Number screens left-to-right, then top-to-bottom
                      --center               Use the original large centered overlay
                  -h, --help                 Show this help
                """)
                exit(0)
            default:
                break
            }

            index += 1
        }

        return options
    }
}

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class OverlayView: NSView {
    private let number: Int
    private let title: String
    private let details: String
    private let position: String
    private let accentColor: NSColor
    private let isBadge: Bool
    var closeHandler: (() -> Void)?

    init(frame: NSRect, number: Int, title: String, details: String, position: String, accentColor: NSColor, isBadge: Bool) {
        self.number = number
        self.title = title
        self.details = details
        self.position = position
        self.accentColor = accentColor
        self.isBadge = isBadge
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        closeHandler?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 || event.charactersIgnoringModifiers?.lowercased() == "q" {
            closeHandler?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        if isBadge {
            drawBadge()
        } else {
            drawCenteredOverlay()
        }
    }

    private func drawBadge() {
        let panelRect = bounds.insetBy(dx: 4, dy: 4)
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.30).setFill()
        panelPath.fill()

        accentColor.withAlphaComponent(0.52).setStroke()
        panelPath.lineWidth = 3
        panelPath.stroke()

        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 46, weight: .black),
            .foregroundColor: NSColor.white
        ]
        let numberString = "\(number)" as NSString
        let numberSize = numberString.size(withAttributes: numberAttributes)
        numberString.draw(
            at: NSPoint(x: 18, y: bounds.midY - numberSize.height * 0.32),
            withAttributes: numberAttributes
        )

        let positionAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.86)
        ]
        let positionString = position as NSString
        positionString.draw(
            at: NSPoint(x: 68, y: bounds.midY + 8),
            withAttributes: positionAttributes
        )

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.72)
        ]
        let titleString = compactTitle(title, maxLength: 19) as NSString
        titleString.draw(
            at: NSPoint(x: 68, y: bounds.midY - 14),
            withAttributes: titleAttributes
        )

        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.58)
        ]
        let detailString = compactTitle(details, maxLength: 28) as NSString
        let detailSize = detailString.size(withAttributes: detailAttributes)
        detailString.draw(
            at: NSPoint(x: panelRect.midX - detailSize.width / 2, y: 13),
            withAttributes: detailAttributes
        )
    }

    private func drawCenteredOverlay() {
        let panelWidth = min(bounds.width * 0.72, 720)
        let panelHeight = min(bounds.height * 0.52, 460)
        let panelRect = NSRect(
            x: bounds.midX - panelWidth / 2,
            y: bounds.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )

        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 28, yRadius: 28)
        NSColor.black.withAlphaComponent(0.58).setFill()
        panelPath.fill()

        accentColor.withAlphaComponent(0.78).setStroke()
        panelPath.lineWidth = 8
        panelPath.stroke()

        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 44, weight: .black),
            .foregroundColor: NSColor.white
        ]
        let headingString = "\(number) \(position)" as NSString
        let headingSize = headingString.size(withAttributes: headingAttributes)
        headingString.draw(
            at: NSPoint(x: bounds.midX - headingSize.width / 2, y: panelRect.midY + 34),
            withAttributes: headingAttributes
        )

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        let titleString = title as NSString
        let titleSize = titleString.size(withAttributes: titleAttributes)
        titleString.draw(
            at: NSPoint(x: bounds.midX - titleSize.width / 2, y: panelRect.minY + 72),
            withAttributes: titleAttributes
        )

        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.72)
        ]
        let detailString = details as NSString
        let detailSize = detailString.size(withAttributes: detailAttributes)
        detailString.draw(
            at: NSPoint(x: bounds.midX - detailSize.width / 2, y: panelRect.minY + 38),
            withAttributes: detailAttributes
        )
    }

    private func compactTitle(_ value: String, maxLength: Int = 15) -> String {
        if value.count <= maxLength {
            return value
        }

        let prefix = value.prefix(max(1, maxLength - 3))
        return "\(prefix)..."
    }
}

@MainActor
final class DisplayIdentifierApp: NSObject, NSApplicationDelegate {
    private let options: Options
    private var windows: [NSWindow] = []
    private var globalMonitor: Any?

    init(options: Options) {
        self.options = options
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if options.listDisplays {
            printDisplayList()
            NSApp.terminate(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        showOverlays()
        installKeyMonitor()

        if !options.persistent {
            Timer.scheduledTimer(withTimeInterval: options.duration, repeats: false) { _ in
                Task { @MainActor in
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
    }

    private func showOverlays() {
        let screens = orderedScreens()
        let mainScreen = NSScreen.main ?? screens.first

        for (index, screen) in screens.enumerated() {
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            let name = screen.localizedName
            let position = positionLabel(for: screen, relativeTo: mainScreen)
            let details = [
                "id \(displayID.map(String.init) ?? "unknown")",
                "\(Int(screen.frame.width))x\(Int(screen.frame.height))",
                screen == NSScreen.main ? "main" : nil
            ].compactMap { $0 }.joined(separator: " | ")

            let contentRect = options.centerOverlay ? screen.frame : badgeRect(for: screen)
            let window = OverlayPanel(
                contentRect: contentRect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .ignoresCycle,
                .stationary
            ]
            window.ignoresMouseEvents = !options.centerOverlay
            window.isReleasedWhenClosed = false

            let view = OverlayView(
                frame: NSRect(origin: .zero, size: contentRect.size),
                number: index + 1,
                title: name,
                details: details,
                position: position,
                accentColor: accentColor(for: index),
                isBadge: !options.centerOverlay
            )
            view.closeHandler = { NSApp.terminate(nil) }
            window.contentView = view
            window.setFrame(contentRect, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func badgeRect(for screen: NSScreen) -> NSRect {
        let badgeSize = NSSize(width: 188, height: 104)
        let margin: CGFloat = 24
        let frame = screen.visibleFrame

        return NSRect(
            x: frame.minX + margin,
            y: frame.maxY - badgeSize.height - margin,
            width: badgeSize.width,
            height: badgeSize.height
        )
    }

    private func orderedScreens() -> [NSScreen] {
        if !options.sortByGeometry {
            return NSScreen.screens
        }

        return NSScreen.screens.sorted { lhs, rhs in
            if abs(lhs.frame.minY - rhs.frame.minY) > 1 {
                return lhs.frame.minY > rhs.frame.minY
            }
            return lhs.frame.minX < rhs.frame.minX
        }
    }

    private func positionLabel(for screen: NSScreen, relativeTo mainScreen: NSScreen?) -> String {
        guard let mainScreen else {
            return "UNKNOWN"
        }

        if screen == mainScreen {
            return "CENTER"
        }

        let dx = screen.frame.midX - mainScreen.frame.midX
        let dy = screen.frame.midY - mainScreen.frame.midY
        let horizontal = abs(dx) >= abs(dy)

        if horizontal {
            return dx < 0 ? "LEFT" : "RIGHT"
        }

        return dy < 0 ? "BELOW" : "ABOVE"
    }

    private func printDisplayList() {
        let screens = orderedScreens()
        let mainScreen = NSScreen.main ?? screens.first
        print("Detected \(screens.count) display\(screens.count == 1 ? "" : "s")")

        for (index, screen) in screens.enumerated() {
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let mainMarker = screen == NSScreen.main ? " main" : ""
            let position = positionLabel(for: screen, relativeTo: mainScreen)

            print("""
            \(index + 1). \(position) - \(screen.localizedName)\(mainMarker)
               id: \(displayID.map(String.init) ?? "unknown")
               frame: x=\(Int(frame.minX)) y=\(Int(frame.minY)) w=\(Int(frame.width)) h=\(Int(frame.height))
               visible: x=\(Int(visibleFrame.minX)) y=\(Int(visibleFrame.minY)) w=\(Int(visibleFrame.width)) h=\(Int(visibleFrame.height))
            """)
        }
    }

    private func installKeyMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 || event.charactersIgnoringModifiers?.lowercased() == "q" {
                Task { @MainActor in
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func accentColor(for index: Int) -> NSColor {
        let colors: [NSColor] = [
            .systemBlue,
            .systemGreen,
            .systemOrange,
            .systemPink,
            .systemTeal,
            .systemRed
        ]
        return colors[index % colors.count]
    }
}

let options = Options.parse(Array(CommandLine.arguments.dropFirst()))
let app = NSApplication.shared
let delegate = DisplayIdentifierApp(options: options)
app.delegate = delegate
app.run()
