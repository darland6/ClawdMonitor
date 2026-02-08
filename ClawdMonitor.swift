import Cocoa
import UserNotifications
import ServiceManagement

// MARK: - Debug Logging
#if DEBUG
func debugLog(_ message: String) {
    print("[ClawdMonitor] \(message)")
}
#else
func debugLog(_ message: String) {}
#endif

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var lastStatus: Bool = false
    var isFirstCheck = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            debugLog("Notifications \(granted ? "enabled" : "denied")")
        }

        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusIcon(running: false)
        setupMenu()

        // Check status every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
        checkStatus()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "OpenClaw Monitor", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let statusItem = NSMenuItem(title: "Status: Checking...", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Start Gateway", action: #selector(startGateway), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Stop Gateway", action: #selector(stopGateway), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Restart Gateway", action: #selector(restartGateway), keyEquivalent: "r"))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "Open Gateway (no auth)", action: #selector(openGateway), keyEquivalent: "g"))
        menu.addItem(NSMenuItem(title: "View Logs", action: #selector(viewLogs), keyEquivalent: "l"))

        menu.addItem(NSMenuItem.separator())

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.tag = 200
        launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem.menu = menu
    }

    func updateStatusIcon(running: Bool) {
        DispatchQueue.main.async {
            if running {
                self.statusItem.button?.title = "🦞"
            } else {
                self.statusItem.button?.title = "💀"
            }

            // Update status menu item
            if let menu = self.statusItem.menu,
               let item = menu.item(withTag: 100) {
                item.title = running ? "Status: Running ✅" : "Status: Stopped ❌"
            }
        }
    }

    func checkStatus() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let running = self?.isOpenClawRunning() ?? false

            DispatchQueue.main.async {
                self?.updateStatusIcon(running: running)

                // Send notification on status change (skip first check)
                if let self = self, !self.isFirstCheck && running != self.lastStatus {
                    self.sendNotification(running: running)
                }
                self?.lastStatus = running
                self?.isFirstCheck = false
            }
        }
    }

    // MARK: - Process Management (Safe: no shell interpretation needed)

    func isOpenClawRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "openclaw gateway"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            debugLog("Error checking status: \(error.localizedDescription)")
            return false
        }
    }

    func sendNotification(running: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "OpenClaw"
        content.body = running ? "Gateway is now running 🦞" : "Gateway has stopped 💀"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    @objc func startGateway() {
        // Using shell here is necessary for nohup and background execution
        // All arguments are hardcoded - no user input
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", "nohup /opt/homebrew/bin/openclaw gateway > /tmp/openclaw-gateway.log 2>&1 &"]

        do {
            try task.run()
            debugLog("Gateway start command executed")
        } catch {
            debugLog("Error starting gateway: \(error.localizedDescription)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkStatus()
        }
    }

    @objc func stopGateway() {
        // Direct process execution - no shell needed
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "openclaw gateway"]

        do {
            try task.run()
            task.waitUntilExit()
            debugLog("Gateway stop command executed")
        } catch {
            debugLog("Error stopping gateway: \(error.localizedDescription)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkStatus()
        }
    }

    @objc func restartGateway() {
        stopGateway()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.startGateway()
        }
    }

    @objc func openDashboard() {
        guard let token = getGatewayToken(), !token.isEmpty else {
            sendErrorNotification("Could not read gateway token")
            return
        }

        // Using URL fragment (#) instead of query string (?) for security
        // Fragments are not sent in HTTP requests or logged in server logs
        let urlString = "http://127.0.0.1:18789/#token=\(token)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openGateway() {
        if let url = URL(string: "http://127.0.0.1:18789") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func viewLogs() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Console", "/tmp/openclaw-gateway.log"]

        do {
            try task.run()
        } catch {
            debugLog("Error opening logs: \(error.localizedDescription)")
        }
    }

    @objc func toggleLaunchAtLogin() {
        let enabled = !isLaunchAtLoginEnabled()
        setLaunchAtLogin(enabled: enabled)

        if let menu = statusItem.menu,
           let item = menu.item(withTag: 200) {
            item.state = enabled ? .on : .off
        }
    }

    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                debugLog("Failed to set launch at login: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Configuration Reading

    func getGatewayToken() -> String? {
        let configPath = NSString(string: "~/.openclaw/openclaw.json").expandingTildeInPath
        let fileManager = FileManager.default

        // Security: Check file exists and is not a symlink pointing outside home
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: configPath, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            debugLog("Config file not found")
            return nil
        }

        // Resolve symlinks and verify path is within home directory
        let resolvedPath = (configPath as NSString).resolvingSymlinksInPath
        guard resolvedPath.hasPrefix(NSHomeDirectory()) else {
            debugLog("Security: Config path resolves outside home directory")
            return nil
        }

        // Check file permissions (warn if world-readable)
        do {
            let attributes = try fileManager.attributesOfItem(atPath: configPath)
            if let permissions = attributes[.posixPermissions] as? Int {
                let otherPerms = permissions & 0o077
                if otherPerms != 0 {
                    debugLog("Warning: Config file has loose permissions: \(String(permissions, radix: 8))")
                }
            }
        } catch {
            debugLog("Could not check file permissions: \(error.localizedDescription)")
        }

        // Read and parse config
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let gateway = json["gateway"] as? [String: Any],
               let auth = gateway["auth"] as? [String: Any],
               let token = auth["token"] as? String {

                // Basic token validation
                guard token.count >= 10, token.count <= 1024 else {
                    debugLog("Token has invalid length")
                    return nil
                }

                return token
            }
        } catch {
            debugLog("Error reading config: \(error.localizedDescription)")
        }
        return nil
    }

    func sendErrorNotification(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "OpenClaw Monitor"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
