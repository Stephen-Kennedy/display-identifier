import AppKit
import CoreGraphics

let appVersion = "1.1.0"

struct Options {
    var duration: TimeInterval = 60
    var persistent = false
    var sortByGeometry = false
    var centerOverlay = false
    var listDisplays = false
    var opacity: CGFloat = 0.30

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
            case "--opacity", "--alpha":
                if index + 1 < arguments.count,
                   let opacity = Double(arguments[index + 1]) {
                    options.opacity = CGFloat(min(max(opacity, 0.08), 0.90))
                    index += 1
                }
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
                  -p, --persist              Stay open until quit from the menu bar
                      --persistent           Alias for --persist
                      --opacity <0.08-0.90>  Badge background opacity. Default: 0.30
                      --alpha <0.08-0.90>    Alias for --opacity
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
    var opacity: CGFloat {
        didSet {
            needsDisplay = true
        }
    }
    var closeHandler: (() -> Void)?

    init(frame: NSRect, number: Int, title: String, details: String, position: String, accentColor: NSColor, isBadge: Bool, opacity: CGFloat) {
        self.number = number
        self.title = title
        self.details = details
        self.position = position
        self.accentColor = accentColor
        self.isBadge = isBadge
        self.opacity = opacity
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
        NSColor.black.withAlphaComponent(opacity).setFill()
        panelPath.fill()

        accentColor.withAlphaComponent(min(opacity + 0.22, 0.90)).setStroke()
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
        NSColor.black.withAlphaComponent(max(opacity, 0.18)).setFill()
        panelPath.fill()

        accentColor.withAlphaComponent(min(opacity + 0.40, 0.95)).setStroke()
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
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSPanel?
    private weak var menuOpacitySlider: NSSlider?
    private weak var settingsOpacitySlider: NSSlider?
    private var opacity: CGFloat

    init(options: Options) {
        self.options = options
        self.opacity = options.opacity
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
        installStatusMenu()
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
                isBadge: !options.centerOverlay,
                opacity: opacity
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

    private func installStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Displays"

        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "Display Identifier \(appVersion)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let showItem = NSMenuItem(title: "Show Badges", action: #selector(showBadges), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let hideItem = NSMenuItem(title: "Hide Badges", action: #selector(hideBadges), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        let refreshItem = NSMenuItem(title: "Refresh Displays", action: #selector(refreshDisplays), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())

        let slider = NSSlider(value: Double(opacity), minValue: 0.08, maxValue: 0.90, target: self, action: #selector(opacityChanged(_:)))
        slider.frame = NSRect(x: 0, y: 0, width: 180, height: 28)
        menuOpacitySlider = slider

        let sliderContainer = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 42))
        let label = NSTextField(labelWithString: "Opacity")
        label.frame = NSRect(x: 14, y: 22, width: 80, height: 16)
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        slider.frame = NSRect(x: 14, y: 2, width: 192, height: 24)
        sliderContainer.addSubview(label)
        sliderContainer.addSubview(slider)

        let sliderItem = NSMenuItem()
        sliderItem.view = sliderContainer
        menu.addItem(sliderItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        opacity = CGFloat(sender.doubleValue)
        menuOpacitySlider?.doubleValue = Double(opacity)
        settingsOpacitySlider?.doubleValue = Double(opacity)

        for window in windows {
            if let overlayView = window.contentView as? OverlayView {
                overlayView.opacity = opacity
            }
        }
    }

    @objc private func showSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func showBadges() {
        if windows.isEmpty {
            showOverlays()
        } else {
            for window in windows {
                window.orderFrontRegardless()
            }
        }
    }

    @objc private func hideBadges() {
        for window in windows {
            window.orderOut(nil)
        }
    }

    @objc private func refreshDisplays() {
        for window in windows {
            window.close()
        }
        windows.removeAll()
        showOverlays()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func makeSettingsWindow() -> NSPanel {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 170),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Display Identifier"
        window.level = .floating
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 170))

        let title = NSTextField(labelWithString: "Display Identifier")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.frame = NSRect(x: 20, y: 126, width: 240, height: 24)
        contentView.addSubview(title)

        let opacityLabel = NSTextField(labelWithString: "Badge opacity")
        opacityLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        opacityLabel.frame = NSRect(x: 20, y: 92, width: 120, height: 18)
        contentView.addSubview(opacityLabel)

        let slider = NSSlider(value: Double(opacity), minValue: 0.08, maxValue: 0.90, target: self, action: #selector(opacityChanged(_:)))
        slider.frame = NSRect(x: 116, y: 88, width: 184, height: 24)
        settingsOpacitySlider = slider
        contentView.addSubview(slider)

        let showButton = NSButton(title: "Show", target: self, action: #selector(showBadges))
        showButton.frame = NSRect(x: 20, y: 34, width: 70, height: 32)
        contentView.addSubview(showButton)

        let hideButton = NSButton(title: "Hide", target: self, action: #selector(hideBadges))
        hideButton.frame = NSRect(x: 98, y: 34, width: 70, height: 32)
        contentView.addSubview(hideButton)

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshDisplays))
        refreshButton.frame = NSRect(x: 176, y: 34, width: 80, height: 32)
        contentView.addSubview(refreshButton)

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitFromMenu))
        quitButton.frame = NSRect(x: 260, y: 34, width: 46, height: 32)
        contentView.addSubview(quitButton)

        window.contentView = contentView
        return window
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
