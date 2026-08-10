import AppKit
import CoreGraphics

struct Options {
    var duration: TimeInterval = 10
    var persistent = false
    var sortByGeometry = false

    static func parse(_ arguments: [String]) -> Options {
        var options = Options()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--persistent", "-p":
                options.persistent = true
            case "--sort-geometry":
                options.sortByGeometry = true
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

                Shows a large number on every connected macOS display.

                Options:
                  -d, --duration <seconds>   Auto-close after this many seconds. Default: 10
                  -p, --persistent           Stay open until Esc, q, or click
                      --sort-geometry        Number screens left-to-right, then top-to-bottom
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

final class OverlayView: NSView {
    private let number: Int
    private let title: String
    private let details: String
    private let accentColor: NSColor
    var closeHandler: (() -> Void)?

    init(frame: NSRect, number: Int, title: String, details: String, accentColor: NSColor) {
        self.number = number
        self.title = title
        self.details = details
        self.accentColor = accentColor
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

        let panelWidth = min(bounds.width * 0.72, 720)
        let panelHeight = min(bounds.height * 0.52, 460)
        let panelRect = NSRect(
            x: bounds.midX - panelWidth / 2,
            y: bounds.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )

        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 28, yRadius: 28)
        NSColor.black.withAlphaComponent(0.72).setFill()
        panelPath.fill()

        accentColor.withAlphaComponent(0.95).setStroke()
        panelPath.lineWidth = 8
        panelPath.stroke()

        let numberFontSize = max(96, min(panelHeight * 0.55, panelWidth * 0.38))
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: numberFontSize, weight: .black),
            .foregroundColor: NSColor.white
        ]
        let numberString = "\(number)" as NSString
        let numberSize = numberString.size(withAttributes: numberAttributes)
        numberString.draw(
            at: NSPoint(x: bounds.midX - numberSize.width / 2, y: panelRect.midY - numberSize.height * 0.42),
            withAttributes: numberAttributes
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

        for (index, screen) in screens.enumerated() {
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            let name = screen.localizedName
            let details = [
                "id \(displayID.map(String.init) ?? "unknown")",
                "\(Int(screen.frame.width))x\(Int(screen.frame.height))",
                screen == NSScreen.main ? "main" : nil
            ].compactMap { $0 }.joined(separator: " | ")

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false

            let view = OverlayView(
                frame: NSRect(origin: .zero, size: screen.frame.size),
                number: index + 1,
                title: name,
                details: details,
                accentColor: accentColor(for: index)
            )
            view.closeHandler = { NSApp.terminate(nil) }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
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
