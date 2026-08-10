import AppKit
import CoreGraphics

let appVersion = "1.5.0"

struct Shortcut: Equatable {
    let key: String?
    let keyCode: UInt16?
    let modifiers: NSEvent.ModifierFlags

    static let none = Shortcut(key: nil, keyCode: nil, modifiers: [])
    static let escape = Shortcut(key: nil, keyCode: 53, modifiers: [])
    static let q = Shortcut(key: "q", keyCode: nil, modifiers: [])
    static let commandShiftD = Shortcut(key: "d", keyCode: nil, modifiers: [.command, .shift])

    init(key: String?, keyCode: UInt16?, modifiers: NSEvent.ModifierFlags) {
        self.key = key?.lowercased()
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(.deviceIndependentFlagsMask)
    }

    init?(storedValue: String) {
        if storedValue == "none" {
            self = .none
            return
        }

        if let legacy = Shortcut.legacyShortcut(for: storedValue) {
            self = legacy
            return
        }

        let parts = storedValue.split(separator: ":").map(String.init)
        guard parts.count == 3,
              let rawModifiers = UInt(parts[2]) else {
            return nil
        }

        let modifiers = NSEvent.ModifierFlags(rawValue: rawModifiers)
        switch parts[0] {
        case "key":
            guard !parts[1].isEmpty else {
                return nil
            }
            self.init(key: parts[1], keyCode: nil, modifiers: modifiers)
        case "keycode":
            guard let keyCode = UInt16(parts[1]) else {
                return nil
            }
            self.init(key: nil, keyCode: keyCode, modifiers: modifiers)
        default:
            return nil
        }
    }

    var storedValue: String {
        if self == .none {
            return "none"
        }
        if let key {
            return "key:\(key):\(modifiers.rawValue)"
        }
        if let keyCode {
            return "keycode:\(keyCode):\(modifiers.rawValue)"
        }
        return "none"
    }

    var displayName: String {
        if self == .none {
            return "Off"
        }

        let modifierNames: [(NSEvent.ModifierFlags, String)] = [
            (.control, "Control"),
            (.option, "Option"),
            (.shift, "Shift"),
            (.command, "Command")
        ]
        let prefix = modifierNames
            .filter { modifiers.contains($0.0) }
            .map(\.1)

        let keyName: String
        if keyCode == 53 {
            keyName = "Escape"
        } else if let key {
            keyName = key.uppercased()
        } else {
            keyName = "Unknown"
        }

        return (prefix + [keyName]).joined(separator: "-")
    }

    func matches(_ event: NSEvent) -> Bool {
        guard self != .none else {
            return false
        }

        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)

        guard flags == modifiers else {
            return false
        }

        if let keyCode {
            return event.keyCode == keyCode
        }

        return event.charactersIgnoringModifiers?.lowercased() == key
    }

    static func parse(_ value: String) -> Shortcut? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Shortcut.none
        }

        if trimmed.lowercased() == "off" || trimmed.lowercased() == "none" {
            return Shortcut.none
        }

        let normalized = trimmed
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let tokens = normalized
            .split(separator: "-")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        var modifiers: NSEvent.ModifierFlags = []
        var parsedKey: String?
        var parsedKeyCode: UInt16?

        for token in tokens {
            switch token {
            case "command", "cmd", "⌘":
                modifiers.insert(.command)
            case "control", "ctrl", "ctl", "^":
                modifiers.insert(.control)
            case "option", "opt", "alt", "⌥":
                modifiers.insert(.option)
            case "shift", "⇧":
                modifiers.insert(.shift)
            case "escape", "esc":
                parsedKeyCode = 53
            default:
                guard token.count == 1,
                      token.rangeOfCharacter(from: .alphanumerics) != nil else {
                    return nil
                }
                parsedKey = token
            }
        }

        guard parsedKey != nil || parsedKeyCode != nil else {
            return nil
        }

        return Shortcut(key: parsedKey, keyCode: parsedKeyCode, modifiers: modifiers)
    }

    private static func legacyShortcut(for rawValue: String) -> Shortcut? {
        switch rawValue {
        case "none":
            return Shortcut.none
        case "escape":
            return .escape
        case "q":
            return .q
        case "commandShiftD":
            return .commandShiftD
        default:
            return nil
        }
    }
}

enum ShortcutAction: String, CaseIterable {
    case toggleBadges
    case hideBadges
    case quit

    var displayName: String {
        switch self {
        case .toggleBadges:
            return "Toggle Badges"
        case .hideBadges:
            return "Hide Badges"
        case .quit:
            return "Quit App"
        }
    }
}

enum BadgePlacement: String, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    init?(argument: String) {
        switch argument.lowercased() {
        case "top-left", "topleft":
            self = .topLeft
        case "top-right", "topright":
            self = .topRight
        case "bottom-left", "bottomleft":
            self = .bottomLeft
        case "bottom-right", "bottomright":
            self = .bottomRight
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .topLeft:
            return "Top Left"
        case .topRight:
            return "Top Right"
        case .bottomLeft:
            return "Bottom Left"
        case .bottomRight:
            return "Bottom Right"
        }
    }
}

struct Options {
    var duration: TimeInterval = 60
    var persistent = false
    var sortByGeometry = true
    var centerOverlay = false
    var listDisplays = false
    var opacity: CGFloat = 0.30
    var badgePlacementOverride: BadgePlacement?

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
            case "--macos-order", "--system-order":
                options.sortByGeometry = false
            case "--center":
                options.centerOverlay = true
            case "--position", "--badge-position", "--location":
                if index + 1 < arguments.count,
                   let placement = BadgePlacement(argument: arguments[index + 1]) {
                    options.badgePlacementOverride = placement
                    index += 1
                }
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
            case "--version":
                print(appVersion)
                exit(0)
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
                      --sort-geometry        Number screens by physical position. Default behavior
                      --macos-order          Number screens in the order macOS reports them
                      --system-order         Alias for --macos-order
                      --position <location>  Badge position: top-left, top-right, bottom-left, bottom-right
                      --center               Use the original large centered overlay
                      --version              Print version and exit
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
    private static let badgePlacementDefaultsKey = "BadgePlacement"
    private static let shortcutKeyDefaultsKey = "ShortcutKey"
    private static let shortcutActionDefaultsKey = "ShortcutAction"
    private static let autoRefreshDefaultsKey = "AutoRefreshOnDisplayChange"
    private static let defaults = UserDefaults(suiteName: "local.accord.display-identifier") ?? .standard

    private let options: Options
    private var windows: [NSWindow] = []
    private var globalMonitor: Any?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSPanel?
    private weak var menuOpacitySlider: NSSlider?
    private weak var settingsOpacitySlider: NSSlider?
    private weak var settingsPlacementPopUp: NSPopUpButton?
    private weak var settingsShortcutField: NSTextField?
    private weak var settingsShortcutStatusLabel: NSTextField?
    private weak var settingsShortcutActionPopUp: NSPopUpButton?
    private weak var settingsAutoRefreshButton: NSButton?
    private var opacity: CGFloat
    private var badgePlacement: BadgePlacement
    private var shortcut: Shortcut
    private var shortcutAction: ShortcutAction
    private var autoRefreshOnDisplayChange: Bool
    private var overlaysVisible = false
    private var pendingDisplayRefresh: DispatchWorkItem?

    init(options: Options) {
        self.options = options
        self.opacity = options.opacity
        if let placement = options.badgePlacementOverride {
            self.badgePlacement = placement
        } else if let savedValue = Self.defaults.string(forKey: Self.badgePlacementDefaultsKey),
                  let savedPlacement = BadgePlacement(rawValue: savedValue) {
            self.badgePlacement = savedPlacement
        } else {
            self.badgePlacement = .bottomRight
        }
        if let savedValue = Self.defaults.string(forKey: Self.shortcutKeyDefaultsKey),
           let savedShortcut = Shortcut(storedValue: savedValue) {
            self.shortcut = savedShortcut
        } else {
            self.shortcut = .none
        }
        if let savedValue = Self.defaults.string(forKey: Self.shortcutActionDefaultsKey),
           let savedShortcutAction = ShortcutAction(rawValue: savedValue) {
            self.shortcutAction = savedShortcutAction
        } else {
            self.shortcutAction = .toggleBadges
        }
        if Self.defaults.object(forKey: Self.autoRefreshDefaultsKey) == nil {
            self.autoRefreshOnDisplayChange = true
        } else {
            self.autoRefreshOnDisplayChange = Self.defaults.bool(forKey: Self.autoRefreshDefaultsKey)
        }
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
        installScreenChangeObserver()

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
        pendingDisplayRefresh?.cancel()
        NotificationCenter.default.removeObserver(self)
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
        overlaysVisible = true
    }

    private func badgeRect(for screen: NSScreen) -> NSRect {
        let badgeSize = NSSize(width: 188, height: 104)
        let margin: CGFloat = 24
        let frame = screen.visibleFrame

        let origin: NSPoint
        switch badgePlacement {
        case .topLeft:
            origin = NSPoint(x: frame.minX + margin, y: frame.maxY - badgeSize.height - margin)
        case .topRight:
            origin = NSPoint(x: frame.maxX - badgeSize.width - margin, y: frame.maxY - badgeSize.height - margin)
        case .bottomLeft:
            origin = NSPoint(x: frame.minX + margin, y: frame.minY + margin)
        case .bottomRight:
            origin = NSPoint(x: frame.maxX - badgeSize.width - margin, y: frame.minY + margin)
        }

        return NSRect(origin: origin, size: badgeSize)
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

    @objc private func badgePlacementChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let placement = BadgePlacement(rawValue: rawValue) else {
            return
        }

        badgePlacement = placement
        Self.defaults.set(rawValue, forKey: Self.badgePlacementDefaultsKey)
        settingsPlacementPopUp?.selectItem(withTitle: placement.displayName)
        refreshDisplays()
    }

    @objc private func shortcutChanged(_ sender: NSTextField) {
        saveShortcut(from: sender.stringValue)
    }

    @objc private func applyShortcutFromSettings() {
        saveShortcut(from: settingsShortcutField?.stringValue ?? "")
    }

    @objc private func clearShortcutFromSettings() {
        shortcut = .none
        Self.defaults.set(shortcut.storedValue, forKey: Self.shortcutKeyDefaultsKey)
        settingsShortcutField?.stringValue = shortcut.displayName
        settingsShortcutStatusLabel?.stringValue = "Hot key is off"
    }

    private func saveShortcut(from input: String) {
        guard let parsedShortcut = Shortcut.parse(input) else {
            settingsShortcutStatusLabel?.stringValue = "Use one key, or modifiers like Control-Q"
            settingsShortcutField?.stringValue = shortcut.displayName
            return
        }

        shortcut = parsedShortcut
        Self.defaults.set(shortcut.storedValue, forKey: Self.shortcutKeyDefaultsKey)
        settingsShortcutField?.stringValue = shortcut.displayName
        settingsShortcutStatusLabel?.stringValue = shortcut == .none ? "Hot key is off" : "Saved \(shortcut.displayName)"
    }

    @objc private func shortcutActionChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let action = ShortcutAction(rawValue: rawValue) else {
            return
        }

        shortcutAction = action
        Self.defaults.set(rawValue, forKey: Self.shortcutActionDefaultsKey)
        settingsShortcutActionPopUp?.selectItem(withTitle: action.displayName)
    }

    @objc private func autoRefreshChanged(_ sender: NSButton) {
        autoRefreshOnDisplayChange = sender.state == .on
        Self.defaults.set(autoRefreshOnDisplayChange, forKey: Self.autoRefreshDefaultsKey)
        settingsAutoRefreshButton?.state = autoRefreshOnDisplayChange ? .on : .off
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
            overlaysVisible = true
        }
    }

    @objc private func hideBadges() {
        orderOutOverlayWindows()
        overlaysVisible = false
    }

    @objc private func refreshDisplays() {
        let shouldRemainVisible = overlaysVisible
        closeOverlayWindows()
        if shouldRemainVisible {
            showOverlays()
        }
    }

    private func closeOverlayWindows() {
        for window in windows {
            window.close()
        }
        windows.removeAll()
        overlaysVisible = false
    }

    private func orderOutOverlayWindows() {
        for window in windows {
            window.orderOut(nil)
        }
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func installScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged(_ notification: Notification) {
        guard autoRefreshOnDisplayChange else {
            return
        }

        let shouldRemainVisible = overlaysVisible
        closeOverlayWindows()
        overlaysVisible = shouldRemainVisible

        pendingDisplayRefresh?.cancel()
        let refresh = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            if self.overlaysVisible {
                self.closeOverlayWindows()
                self.showOverlays()
            }
        }
        pendingDisplayRefresh = refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: refresh)
    }

    private func makeSettingsWindow() -> NSPanel {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 364),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Display Identifier"
        window.level = .floating
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 364))

        let title = NSTextField(labelWithString: "Display Identifier")
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.frame = NSRect(x: 20, y: 320, width: 260, height: 24)
        contentView.addSubview(title)

        let opacityLabel = NSTextField(labelWithString: "Badge opacity")
        opacityLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        opacityLabel.frame = NSRect(x: 20, y: 282, width: 120, height: 18)
        contentView.addSubview(opacityLabel)

        let slider = NSSlider(value: Double(opacity), minValue: 0.08, maxValue: 0.90, target: self, action: #selector(opacityChanged(_:)))
        slider.frame = NSRect(x: 146, y: 278, width: 234, height: 24)
        settingsOpacitySlider = slider
        contentView.addSubview(slider)

        let placementLabel = NSTextField(labelWithString: "Badge position")
        placementLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        placementLabel.frame = NSRect(x: 20, y: 242, width: 120, height: 18)
        contentView.addSubview(placementLabel)

        let placementPopUp = NSPopUpButton(frame: NSRect(x: 146, y: 236, width: 234, height: 28), pullsDown: false)
        for placement in BadgePlacement.allCases {
            placementPopUp.addItem(withTitle: placement.displayName)
            placementPopUp.lastItem?.representedObject = placement.rawValue
        }
        placementPopUp.selectItem(withTitle: badgePlacement.displayName)
        placementPopUp.target = self
        placementPopUp.action = #selector(badgePlacementChanged(_:))
        settingsPlacementPopUp = placementPopUp
        contentView.addSubview(placementPopUp)

        let shortcutKeyLabel = NSTextField(labelWithString: "Hot key")
        shortcutKeyLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        shortcutKeyLabel.frame = NSRect(x: 20, y: 202, width: 120, height: 18)
        contentView.addSubview(shortcutKeyLabel)

        let shortcutField = NSTextField(string: shortcut.displayName)
        shortcutField.frame = NSRect(x: 146, y: 198, width: 138, height: 24)
        shortcutField.placeholderString = "Control-Q"
        shortcutField.target = self
        shortcutField.action = #selector(shortcutChanged(_:))
        settingsShortcutField = shortcutField
        contentView.addSubview(shortcutField)

        let shortcutApplyButton = NSButton(title: "Set", target: self, action: #selector(applyShortcutFromSettings))
        shortcutApplyButton.frame = NSRect(x: 292, y: 194, width: 44, height: 32)
        contentView.addSubview(shortcutApplyButton)

        let shortcutClearButton = NSButton(title: "Off", target: self, action: #selector(clearShortcutFromSettings))
        shortcutClearButton.frame = NSRect(x: 342, y: 194, width: 38, height: 32)
        contentView.addSubview(shortcutClearButton)

        let shortcutStatusLabel = NSTextField(labelWithString: shortcut == .none ? "Hot key is off" : "Saved \(shortcut.displayName)")
        shortcutStatusLabel.font = NSFont.systemFont(ofSize: 10)
        shortcutStatusLabel.textColor = .secondaryLabelColor
        shortcutStatusLabel.frame = NSRect(x: 146, y: 178, width: 234, height: 14)
        settingsShortcutStatusLabel = shortcutStatusLabel
        contentView.addSubview(shortcutStatusLabel)

        let shortcutActionLabel = NSTextField(labelWithString: "Hot key action")
        shortcutActionLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        shortcutActionLabel.frame = NSRect(x: 20, y: 146, width: 120, height: 18)
        contentView.addSubview(shortcutActionLabel)

        let shortcutActionPopUp = NSPopUpButton(frame: NSRect(x: 146, y: 140, width: 234, height: 28), pullsDown: false)
        for action in ShortcutAction.allCases {
            shortcutActionPopUp.addItem(withTitle: action.displayName)
            shortcutActionPopUp.lastItem?.representedObject = action.rawValue
        }
        shortcutActionPopUp.selectItem(withTitle: shortcutAction.displayName)
        shortcutActionPopUp.target = self
        shortcutActionPopUp.action = #selector(shortcutActionChanged(_:))
        settingsShortcutActionPopUp = shortcutActionPopUp
        contentView.addSubview(shortcutActionPopUp)

        let autoRefreshButton = NSButton(checkboxWithTitle: "Auto-refresh when displays change", target: self, action: #selector(autoRefreshChanged(_:)))
        autoRefreshButton.frame = NSRect(x: 20, y: 96, width: 340, height: 22)
        autoRefreshButton.state = autoRefreshOnDisplayChange ? .on : .off
        settingsAutoRefreshButton = autoRefreshButton
        contentView.addSubview(autoRefreshButton)

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
        quitButton.frame = NSRect(x: 264, y: 34, width: 56, height: 32)
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
            guard self.shortcut.matches(event) else {
                return
            }

            Task { @MainActor in
                switch self.shortcutAction {
                case .toggleBadges:
                    if self.overlaysVisible {
                        self.hideBadges()
                    } else {
                        self.showBadges()
                    }
                case .hideBadges:
                    self.hideBadges()
                case .quit:
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
