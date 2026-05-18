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
                return #"do shell script "/usr/bin/pmset -a disablesleep 1" with prompt "LidGuard запрашивает права администратора для отключения сна при закрытой крышке." with administrator privileges"#
            case .disableNoSleep:
                return #"do shell script "/usr/bin/pmset -a disablesleep 0" with prompt "LidGuard запрашивает права администратора для отключения сна при закрытой крышке." with administrator privileges"#
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

enum Palette {
    static let bgTop = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.93, green: 0.96, blue: 1.00, alpha: 1.0)
    }

    static let bgBottom = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.24, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.83, green: 0.90, blue: 0.99, alpha: 1.0)
    }

    static let cardBackground = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedWhite: 0.16, alpha: 0.92)
        }
        return NSColor(calibratedWhite: 1.0, alpha: 0.85)
    }

    static let cardBorder = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedWhite: 1.0, alpha: 0.20)
        }
        return NSColor(calibratedWhite: 1.0, alpha: 0.95)
    }

    static let textMain = NSColor.labelColor
    static let textSubtle = NSColor.secondaryLabelColor

    static let buttonOn = NSColor.systemBlue
    static let buttonOff = NSColor.systemGray
    static let statusOK = NSColor.systemGreen
    static let statusWarn = NSColor.systemOrange
}

final class CompactBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let gradient = NSGradient(colorsAndLocations: (Palette.bgTop, 0.0), (Palette.bgBottom, 1.0)) {
            gradient.draw(in: bounds, angle: -90)
        }

        let bubbleTopRight = NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 170, y: bounds.maxY - 130, width: 120, height: 120))
        NSColor.systemBlue.withAlphaComponent(0.15).setFill()
        bubbleTopRight.fill()

        let bubbleBottomLeft = NSBezierPath(ovalIn: NSRect(x: bounds.minX - 40, y: bounds.minY - 45, width: 120, height: 120))
        NSColor.systemTeal.withAlphaComponent(0.14).setFill()
        bubbleBottomLeft.fill()
    }
}

@MainActor
final class MainWindowController: NSWindowController {
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let enableButton = NSButton(title: "Включить режим", target: nil, action: nil)
    private let disableButton = NSButton(title: "Выключить", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 290),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LidGuard"
        window.center()
        window.contentView = CompactBackgroundView(frame: window.frame)

        super.init(window: window)
        configureUI()
        setStatus("Нажмите кнопку для изменения режима.", color: Palette.textSubtle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }

        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 18
        card.layer?.borderWidth = 1
        let appearance = contentView.effectiveAppearance
        var resolvedBackground = Palette.cardBackground
        var resolvedBorder = Palette.cardBorder
        appearance.performAsCurrentDrawingAppearance {
            resolvedBackground = Palette.cardBackground
            resolvedBorder = Palette.cardBorder
        }
        card.layer?.backgroundColor = resolvedBackground.cgColor
        card.layer?.borderColor = resolvedBorder.cgColor

        let titleLabel = NSTextField(labelWithString: "Сон при закрытой крышке")
        titleLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 24) ?? NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = Palette.textMain

        let subtitleLabel = NSTextField(wrappingLabelWithString: "Включайте или отключайте режим через pmset в один клик.")
        subtitleLabel.font = NSFont(name: "Avenir Next Regular", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = Palette.textSubtle
        subtitleLabel.maximumNumberOfLines = 2

        statusLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .semibold)
        statusLabel.maximumNumberOfLines = 2

        configureButton(enableButton, color: Palette.buttonOn, action: #selector(enablePressed))
        configureButton(disableButton, color: Palette.buttonOff, action: #selector(disablePressed))

        let buttonsRow = NSStackView(views: [enableButton, disableButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.spacing = 10
        buttonsRow.distribution = .fillEqually

        let stack = NSStackView(views: [titleLabel, subtitleLabel, statusLabel, buttonsRow])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            buttonsRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            enableButton.heightAnchor.constraint(equalToConstant: 36),
            disableButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func configureButton(_ button: NSButton, color: NSColor, action: Selector) {
        button.font = NSFont(name: "Avenir Next Demi Bold", size: 14) ?? NSFont.systemFont(ofSize: 14, weight: .semibold)
        button.setButtonType(.momentaryLight)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.layer?.backgroundColor = color.cgColor
        button.contentTintColor = .white
        button.target = self
        button.action = action
    }

    @objc private func enablePressed() {
        do {
            try PMSetService.enableNoSleep()
            let value = try PMSetService.readSleepDisabled()
            if value == 1 {
                setStatus("Режим включен (SleepDisabled=1).", color: Palette.statusOK)
            } else {
                setStatus("Система не подтвердила включение.", color: Palette.statusWarn)
                showInfo("Проверьте в терминале: pmset -g | awk '/SleepDisabled/ {print $2}'")
            }
        } catch {
            showError(error)
        }
    }

    @objc private func disablePressed() {
        do {
            try PMSetService.disableNoSleep()
            let value = try PMSetService.readSleepDisabled()
            if value == 0 {
                setStatus("Режим выключен (SleepDisabled=0).", color: Palette.statusOK)
            } else {
                setStatus("Система не подтвердила отключение.", color: Palette.statusWarn)
                showInfo("Проверьте в терминале: pmset -g | awk '/SleepDisabled/ {print $2}'")
            }
        } catch {
            showError(error)
        }
    }

    private func setStatus(_ text: String, color: NSColor) {
        statusLabel.stringValue = text
        statusLabel.textColor = color
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Не удалось выполнить команду"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private func showInfo(_ text: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "LidGuard"
        alert.informativeText = text
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
