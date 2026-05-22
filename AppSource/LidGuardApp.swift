import AppKit
import Foundation

enum LidGuardError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text):
            return text
        }
    }
}

enum PMSetService {
    private enum PrivilegedCommand {
        case enableNoSleep
        case disableNoSleep

        var appleScriptSource: String {
            switch self {
            case .enableNoSleep:
                return #"do shell script "/usr/bin/pmset -a disablesleep 1" with prompt "LidGuard запрашивает права администратора, чтобы отключить сон при закрытой крышке." with administrator privileges"#
            case .disableNoSleep:
                return #"do shell script "/usr/bin/pmset -a disablesleep 0" with prompt "LidGuard запрашивает права администратора, чтобы вернуть стандартный режим сна." with administrator privileges"#
            }
        }
    }

    static func enableNoSleep() throws {
        try runPrivileged(command: .enableNoSleep)
    }

    static func disableNoSleep() throws {
        try runPrivileged(command: .disableNoSleep)
    }

    static func readSleepDisabled() throws -> Int? {
        let output = try run(arguments: ["-g"])

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard tokens.count >= 2 else { continue }

            if tokens[0].lowercased() == "sleepdisabled", let value = Int(tokens[1]) {
                return value
            }
        }

        return nil
    }

    private static func run(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)

        if process.terminationStatus != 0 {
            let details = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw LidGuardError.message(details.isEmpty ? "Не удалось прочитать состояние pmset." : details)
        }

        return output
    }

    private static func runPrivileged(command: PrivilegedCommand) throws {
        guard let script = NSAppleScript(source: command.appleScriptSource) else {
            throw LidGuardError.message("Не удалось подготовить запрос прав администратора.")
        }

        var errorInfo: NSDictionary?
        _ = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Неизвестная ошибка авторизации."
            throw LidGuardError.message(message)
        }
    }
}

enum ThemePalette {
    static let windowTop = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.20, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.00, alpha: 1.0)
    }

    static let windowBottom = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.17, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.90, green: 0.94, blue: 0.99, alpha: 1.0)
    }

    static let windowFrame = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedWhite: 1.0, alpha: 0.13)
        }
        return NSColor(calibratedRed: 0.70, green: 0.78, blue: 0.88, alpha: 0.55)
    }

    static let cardBackground = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.25, alpha: 0.93)
        }
        return NSColor(calibratedWhite: 1.0, alpha: 0.88)
    }

    static let cardBorder = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedWhite: 1.0, alpha: 0.18)
        }
        return NSColor(calibratedRed: 0.68, green: 0.77, blue: 0.88, alpha: 0.62)
    }

    static let textPrimary = NSColor.labelColor
    static let textSecondary = NSColor.secondaryLabelColor
    static let textMuted = NSColor.tertiaryLabelColor

    static let actionPrimary = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.20, green: 0.63, blue: 0.40, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.09, green: 0.56, blue: 0.31, alpha: 1.0)
    }

    static let actionSecondary = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.23, green: 0.30, blue: 0.40, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.86, green: 0.91, blue: 0.97, alpha: 1.0)
    }

    static let actionSecondaryBorder = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedWhite: 1.0, alpha: 0.22)
        }
        return NSColor(calibratedRed: 0.64, green: 0.73, blue: 0.85, alpha: 0.65)
    }

    static func resolved(_ color: NSColor, in appearance: NSAppearance) -> NSColor {
        var resolvedColor = color
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor = color
        }
        return resolvedColor
    }

    static func cgColor(_ color: NSColor, in appearance: NSAppearance) -> CGColor {
        resolved(color, in: appearance).cgColor
    }
}

final class GradientBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let gradient = NSGradient(colorsAndLocations: (ThemePalette.windowTop, 0.0), (ThemePalette.windowBottom, 1.0)) {
            gradient.draw(in: bounds, angle: -90)
        }

        let framePath = NSBezierPath(roundedRect: bounds.insetBy(dx: 12, dy: 12), xRadius: 22, yRadius: 22)
        ThemePalette.windowFrame.setStroke()
        framePath.lineWidth = 1
        framePath.stroke()

        let guideLine = NSBezierPath()
        guideLine.move(to: NSPoint(x: 42, y: bounds.midY + 32))
        guideLine.line(to: NSPoint(x: bounds.maxX - 42, y: bounds.midY + 32))
        ThemePalette.windowFrame.withAlphaComponent(0.65).setStroke()
        guideLine.lineWidth = 1
        guideLine.stroke()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

@MainActor
final class MainWindowController: NSWindowController {
    private enum StatusStyle {
        case neutral
        case enabled
        case disabled
        case warning

        var background: NSColor {
            switch self {
            case .neutral:
                return NSColor(name: nil) { appearance in
                    if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                        return NSColor(calibratedWhite: 1.0, alpha: 0.09)
                    }
                    return NSColor(calibratedRed: 0.88, green: 0.92, blue: 0.97, alpha: 0.9)
                }
            case .enabled:
                return NSColor(name: nil) { appearance in
                    if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                        return NSColor(calibratedRed: 0.16, green: 0.35, blue: 0.24, alpha: 0.9)
                    }
                    return NSColor(calibratedRed: 0.84, green: 0.95, blue: 0.88, alpha: 1.0)
                }
            case .disabled:
                return NSColor(name: nil) { appearance in
                    if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                        return NSColor(calibratedRed: 0.17, green: 0.27, blue: 0.38, alpha: 0.9)
                    }
                    return NSColor(calibratedRed: 0.85, green: 0.91, blue: 0.98, alpha: 1.0)
                }
            case .warning:
                return NSColor(name: nil) { appearance in
                    if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                        return NSColor(calibratedRed: 0.37, green: 0.27, blue: 0.14, alpha: 0.9)
                    }
                    return NSColor(calibratedRed: 0.98, green: 0.92, blue: 0.79, alpha: 1.0)
                }
            }
        }

        var dot: NSColor {
            switch self {
            case .neutral:
                return .secondaryLabelColor
            case .enabled:
                return NSColor.systemGreen
            case .disabled:
                return NSColor.systemBlue
            case .warning:
                return NSColor.systemOrange
            }
        }

        var text: NSColor {
            switch self {
            case .warning:
                return NSColor(name: nil) { appearance in
                    if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                        return NSColor(calibratedRed: 1.0, green: 0.91, blue: 0.67, alpha: 1.0)
                    }
                    return NSColor(calibratedRed: 0.47, green: 0.31, blue: 0.04, alpha: 1.0)
                }
            case .neutral, .enabled, .disabled:
                return ThemePalette.textPrimary
            }
        }
    }

    private let cardView = NSView()
    private let titleLabel = NSTextField(labelWithString: "Управление режимом сна")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "LidGuard меняет параметр SleepDisabled и применяет команды через стандартный запрос администратора.")
    private let stateCaptionLabel = NSTextField(labelWithString: "Текущее состояние")
    private let statusContainer = NSView()
    private let statusDot = NSView()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let hintLabel = NSTextField(wrappingLabelWithString: "Изменения применяются для всей системы macOS.")
    private let enableButton = NSButton(title: "Не усыплять при закрытии", target: nil, action: nil)
    private let disableButton = NSButton(title: "Включить стандартный сон", target: nil, action: nil)
    private let refreshButton = NSButton(title: "Обновить статус", target: nil, action: nil)

    private var statusStyle: StatusStyle = .neutral
    private var appearanceObserver: NSKeyValueObservation?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LidGuard"
        window.center()
        window.minSize = NSSize(width: 560, height: 360)
        window.contentView = GradientBackgroundView(frame: window.frame)

        super.init(window: window)
        configureUI()
        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.applyTheme()
            }
        }
        applyTheme()
        setStatus("Проверяем текущее значение SleepDisabled…", style: .neutral)
        refreshStatus(showErrorAlert: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 22
        cardView.layer?.borderWidth = 1
        cardView.layer?.shadowOpacity = 0.16
        cardView.layer?.shadowRadius = 14
        cardView.layer?.shadowOffset = CGSize(width: 0, height: 7)

        titleLabel.font = NSFont.systemFont(ofSize: 25, weight: .bold)
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.maximumNumberOfLines = 3
        stateCaptionLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        hintLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        hintLabel.maximumNumberOfLines = 2

        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.wantsLayer = true
        statusContainer.layer?.cornerRadius = 12
        statusContainer.layer?.borderWidth = 1

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 5

        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        statusLabel.maximumNumberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let statusRow = NSStackView(views: [statusDot, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .centerY
        statusRow.translatesAutoresizingMaskIntoConstraints = false

        statusContainer.addSubview(statusRow)

        configurePrimaryButton(enableButton, action: #selector(enablePressed))
        configureSecondaryButton(disableButton, action: #selector(disablePressed))

        refreshButton.bezelStyle = .rounded
        refreshButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        refreshButton.target = self
        refreshButton.action = #selector(refreshPressed)
        refreshButton.keyEquivalent = "r"
        refreshButton.keyEquivalentModifierMask = [.command]

        let actionsRow = NSStackView(views: [enableButton, disableButton])
        actionsRow.orientation = .horizontal
        actionsRow.spacing = 10
        actionsRow.distribution = .fillEqually

        let stack = NSStackView(views: [titleLabel, subtitleLabel, stateCaptionLabel, statusContainer, hintLabel, actionsRow, refreshButton])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(8, after: stateCaptionLabel)
        stack.setCustomSpacing(10, after: statusContainer)
        stack.setCustomSpacing(16, after: hintLabel)

        contentView.addSubview(cardView)
        cardView.addSubview(stack)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            statusRow.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 12),
            statusRow.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -12),
            statusRow.topAnchor.constraint(equalTo: statusContainer.topAnchor, constant: 10),
            statusRow.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor, constant: -10),

            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            actionsRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            enableButton.heightAnchor.constraint(equalToConstant: 40),
            disableButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func configurePrimaryButton(_ button: NSButton, action: Selector) {
        button.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        button.setButtonType(.momentaryLight)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 11
        button.target = self
        button.action = action
    }

    private func configureSecondaryButton(_ button: NSButton, action: Selector) {
        configurePrimaryButton(button, action: action)
        button.layer?.borderWidth = 1
    }

    private func applyTheme() {
        guard let appearance = window?.contentView?.effectiveAppearance else { return }

        cardView.layer?.backgroundColor = ThemePalette.cgColor(ThemePalette.cardBackground, in: appearance)
        cardView.layer?.borderColor = ThemePalette.cgColor(ThemePalette.cardBorder, in: appearance)
        cardView.layer?.shadowColor = ThemePalette.cgColor(NSColor.black.withAlphaComponent(0.35), in: appearance)

        titleLabel.textColor = ThemePalette.textPrimary
        subtitleLabel.textColor = ThemePalette.textSecondary
        stateCaptionLabel.textColor = ThemePalette.textMuted
        hintLabel.textColor = ThemePalette.textSecondary

        enableButton.layer?.backgroundColor = ThemePalette.cgColor(ThemePalette.actionPrimary, in: appearance)
        enableButton.contentTintColor = .white

        disableButton.layer?.backgroundColor = ThemePalette.cgColor(ThemePalette.actionSecondary, in: appearance)
        disableButton.layer?.borderColor = ThemePalette.cgColor(ThemePalette.actionSecondaryBorder, in: appearance)
        disableButton.contentTintColor = ThemePalette.resolved(ThemePalette.textPrimary, in: appearance)

        refreshButton.contentTintColor = ThemePalette.resolved(ThemePalette.textSecondary, in: appearance)
        refreshButton.bezelColor = ThemePalette.resolved(ThemePalette.actionSecondary, in: appearance)

        statusContainer.layer?.backgroundColor = ThemePalette.cgColor(statusStyle.background, in: appearance)
        statusContainer.layer?.borderColor = ThemePalette.cgColor(ThemePalette.cardBorder.withAlphaComponent(0.7), in: appearance)
        statusDot.layer?.backgroundColor = ThemePalette.cgColor(statusStyle.dot, in: appearance)
        statusLabel.textColor = ThemePalette.resolved(statusStyle.text, in: appearance)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        applyTheme()
    }

    @objc private func enablePressed() {
        do {
            try PMSetService.enableNoSleep()
            refreshStatus(showErrorAlert: true)
        } catch {
            showError(error)
        }
    }

    @objc private func disablePressed() {
        do {
            try PMSetService.disableNoSleep()
            refreshStatus(showErrorAlert: true)
        } catch {
            showError(error)
        }
    }

    @objc private func refreshPressed() {
        refreshStatus(showErrorAlert: true)
    }

    private func refreshStatus(showErrorAlert: Bool) {
        do {
            let value = try PMSetService.readSleepDisabled()
            switch value {
            case 1:
                setStatus("Сон отключен: Mac остается активным при закрытой крышке.", style: .enabled)
            case 0:
                setStatus("Стандартный режим: Mac засыпает при закрытой крышке.", style: .disabled)
            default:
                setStatus("Не удалось определить состояние SleepDisabled.", style: .warning)
            }
        } catch {
            setStatus("Не удалось прочитать состояние SleepDisabled.", style: .warning)
            if showErrorAlert {
                showError(error)
            }
        }
    }

    private func setStatus(_ text: String, style: StatusStyle) {
        statusStyle = style
        statusLabel.stringValue = text
        applyTheme()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Не удалось выполнить команду"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MainWindowController()
        self.windowController = controller
        controller.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)

        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
@MainActor
struct LidGuardGUIBootstrap {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
