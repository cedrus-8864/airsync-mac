//
//  AppState.swift
//  airsync-mac
//
//  Created by Sameera Sandakelum on 2025-07-29.
//
import SwiftUI
import Foundation
import Cocoa
internal import Combine
import UserNotifications

class AppState: ObservableObject {
    static let shared = AppState()

    private var clipboardCancellable: AnyCancellable?
    private var lastClipboardValue: String? = nil
    private var shouldSkipSave = false
    private let licenseDetailsKey = "licenseDetails"

    @Published var isOS26: Bool = true

    init() {
        self.isPlus = UserDefaults.standard.bool(forKey: "isPlus")

        // Load from UserDefaults
        let name = UserDefaults.standard.string(forKey: "deviceName") ?? (Host.current().localizedName ?? "My Mac")
        let portString = UserDefaults.standard.string(forKey: "devicePort") ?? String(Defaults.serverPort)
        let port = Int(portString) ?? Int(Defaults.serverPort)
        let adbPortValue = UserDefaults.standard.integer(forKey: "adbPort")
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"

        self.adbPort = adbPortValue == 0 ? 5555 : UInt16(adbPortValue)
        self.mirroringPlus = UserDefaults.standard.bool(forKey: "mirroringPlus")
        self.adbEnabled = UserDefaults.standard.bool(forKey: "adbEnabled")
        self.showMenubarText = UserDefaults.standard.bool(forKey: "showMenubarText")

        // Default to true if not previously set
        let showNameObj = UserDefaults.standard.object(forKey: "showMenubarDeviceName")
        self.showMenubarDeviceName = showNameObj == nil
            ? true
            : UserDefaults.standard.bool(forKey: "showMenubarDeviceName")

        let savedMaxLength = UserDefaults.standard.integer(forKey: "menubarTextMaxLength")
        self.menubarTextMaxLength = savedMaxLength > 0 ? savedMaxLength : 30

        self.isClipboardSyncEnabled = UserDefaults.standard.bool(forKey: "isClipboardSyncEnabled")
        self.windowOpacity = UserDefaults.standard
            .double(forKey: "windowOpacity")
        self.toolbarContrast = UserDefaults.standard
            .bool(forKey: "toolbarContrast")
        self.hideDockIcon = UserDefaults.standard
            .bool(forKey: "hideDockIcon")
        self.dismissNotif = UserDefaults.standard
            .bool(forKey: "dismissNotif")
        
        // Default to true for backward compatibility - existing behavior should continue
        let savedNowPlayingStatus = UserDefaults.standard.object(forKey: "sendNowPlayingStatus")
        self.sendNowPlayingStatus = savedNowPlayingStatus == nil ? true : UserDefaults.standard.bool(forKey: "sendNowPlayingStatus")
        
        if isClipboardSyncEnabled {
            startClipboardMonitoring()
        }

        Task {
            await Gumroad().checkLicenseIfNeeded()
        }

        self.scrcpyBitrate = UserDefaults.standard.integer(forKey: "scrcpyBitrate")
        if self.scrcpyBitrate == 0 { self.scrcpyBitrate = 4 }

        self.scrcpyResolution = UserDefaults.standard.integer(forKey: "scrcpyResolution")
        if self.scrcpyResolution == 0 { self.scrcpyResolution = 1200 }

    // Initialize persisted UI toggles
    self.isMusicCardHidden = UserDefaults.standard.bool(forKey: "isMusicCardHidden")

        self.myDevice = Device(
            name: name,
            ipAddress: WebSocketServer.shared
                .getLocalIPAddress(
                    adapterName: selectedNetworkAdapterName
                ) ?? "N/A",
            port: port,
            version:appVersion
        )
        self.licenseDetails = loadLicenseDetailsFromUserDefaults()

        loadAppsFromDisk()

        postNativeNotification(id: "test_notification", appName: "AirSync Beta", title: "Hi there! (っ◕‿◕)っ", body: "Welcome to and thanks for testing out the app. Please don't forget to report issues to sameerasw.com@gmail.com or any other community you prefer. <3", appIcon: nil)
    }

    @Published var minAndroidVersion = Bundle.main.infoDictionary?["AndroidVersion"] as? String ?? "2.0.0"

    @Published var device: Device? = nil
    @Published var notifications: [Notification] = []
    @Published var status: DeviceStatus? = nil
    @Published var myDevice: Device? = nil
    @Published var port: UInt16 = Defaults.serverPort

    @Published var androidApps: [String: AndroidApp] = [:]

    @Published var deviceWallpapers: [String: String] = [:] // key = deviceName-ip, value = file path
    @Published var isClipboardSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isClipboardSyncEnabled, forKey: "isClipboardSyncEnabled")
            if isClipboardSyncEnabled {
                startClipboardMonitoring()
            } else {
                stopClipboardMonitoring()
            }
        }
    }
    @Published var shouldRefreshQR: Bool = false
    @Published var webSocketStatus: WebSocketStatus = .stopped
    @Published var selectedTab: TabIdentifier = .qr

    @Published var adbConnected: Bool = false
    @Published var adbConnecting: Bool = false
    @Published var currentDeviceWallpaperBase64: String? = nil
    @Published var selectedNetworkAdapterName: String? // e.g., "en0"
    @Published var showMenubarText: Bool {
        didSet {
            UserDefaults.standard.set(showMenubarText, forKey: "showMenubarText")
        }
    }

    @Published var showMenubarDeviceName: Bool {
        didSet {
            UserDefaults.standard.set(showMenubarDeviceName, forKey: "showMenubarDeviceName")
        }
    }

    @Published var menubarTextMaxLength: Int {
        didSet {
            UserDefaults.standard.set(menubarTextMaxLength, forKey: "menubarTextMaxLength")
        }
    }

    @Published var scrcpyBitrate: Int = 4 {
        didSet {
            UserDefaults.standard.set(scrcpyBitrate, forKey: "scrcpyBitrate")
        }
    }

    @Published var scrcpyResolution: Int = 1200 {
        didSet {
            UserDefaults.standard.set(scrcpyResolution, forKey: "scrcpyResolution")
        }
    }

    @Published var licenseDetails: LicenseDetails? {
        didSet {
            saveLicenseDetailsToUserDefaults()
        }
    }

    @Published var adbPort: UInt16 {
        didSet {
            UserDefaults.standard.set(adbPort, forKey: "adbPort")
        }
    }
    @Published var adbConnectionResult: String? = nil

    @Published var mirroringPlus: Bool {
        didSet {
            UserDefaults.standard.set(mirroringPlus, forKey: "mirroringPlus")
        }
    }

    @Published var adbEnabled: Bool {
        didSet {
            UserDefaults.standard.set(adbEnabled, forKey: "adbEnabled")
        }
    }

    @Published var windowOpacity: Double {
        didSet {
            UserDefaults.standard.set(windowOpacity, forKey: "windowOpacity")
        }
    }

    @Published var toolbarContrast: Bool {
        didSet {
            UserDefaults.standard.set(toolbarContrast, forKey: "toolbarContrast")
        }
    }

    @Published var hideDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(hideDockIcon, forKey: "hideDockIcon")
            updateDockIconVisibility()
        }
    }

    @Published var dismissNotif: Bool {
        didSet {
            UserDefaults.standard.set(dismissNotif, forKey: "dismissNotif")
        }
    }

    @Published var sendNowPlayingStatus: Bool {
        didSet {
            UserDefaults.standard.set(sendNowPlayingStatus, forKey: "sendNowPlayingStatus")
        }
    }

    // Whether the media player card is hidden on the PhoneView
    @Published var isMusicCardHidden: Bool = false {
        didSet {
            UserDefaults.standard.set(isMusicCardHidden, forKey: "isMusicCardHidden")
        }
    }

    @Published var isOnboardingActive: Bool = false {
        didSet {
            NotificationCenter.default.post(
                name: NSNotification.Name("OnboardingStateChanged"),
                object: nil,
                userInfo: ["isActive": isOnboardingActive]
            )
        }
    }

    // File transfer tracking state
    @Published var transfers: [String: FileTransferSession] = [:]

    // Toggle licensing
    let licenseCheck: Bool = true

    @Published var isPlus: Bool {
        didSet {
            if !shouldSkipSave {
                UserDefaults.standard.set(isPlus, forKey: "isPlus")
            }
        }
    }

    func setPlusTemporarily(_ value: Bool) {
        shouldSkipSave = true
        isPlus = value
        shouldSkipSave = false
    }

    // Remove notification by model instance and system notif center
    func removeNotification(_ notif: Notification) {
        DispatchQueue.main.async {
            withAnimation {
                self.notifications.removeAll { $0.id == notif.id }
            }
            if self.dismissNotif {
                WebSocketServer.shared.dismissNotification(id: notif.nid)
            }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notif.nid])
        }
    }

    func removeNotificationById(_ nid: String) {
        DispatchQueue.main.async {
            withAnimation {
                self.notifications.removeAll { $0.nid == nid }
            }
            if self.dismissNotif {
                WebSocketServer.shared.dismissNotification(id: nid)
            }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [nid])
        }
    }

    func hideNotification(_ notif: Notification) {
        DispatchQueue.main.async {
            withAnimation {
                self.notifications.removeAll { $0.id == notif.id }
            }
            self.removeNotification(notif)
        }
    }

    func clearNotifications() {
        DispatchQueue.main.async {
            if !self.notifications.isEmpty {
                withAnimation {
                    self.notifications.removeAll()
                }
            }
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
    }

    func disconnectDevice() {
        DispatchQueue.main.async {
            // Send request to remote device to disconnect
            WebSocketServer.shared.sendDisconnectRequest()

            // Then locally reset state
            self.device = nil
            self.notifications.removeAll()
            self.status = nil
            self.currentDeviceWallpaperBase64 = nil
            self.transfers = [:]

            ADBConnector.disconnectADB()
        }
    }

    func addNotification(_ notif: Notification) {
        DispatchQueue.main.async {
            withAnimation {
                self.notifications.insert(notif, at: 0)
            }
            // Trigger native macOS notification
            var appIcon: NSImage? = nil
            if let iconPath = self.androidApps[notif.package]?.iconUrl {
                appIcon = NSImage(contentsOfFile: iconPath)
            }
            self.postNativeNotification(
                id: notif.nid,
                appName: notif.app,
                title: notif.title,
                body: notif.body,
                appIcon: appIcon,
                package: notif.package,
                actions: notif.actions
            )
        }
    }

    func postNativeNotification(
        id: String,
        appName: String,
        title: String,
        body: String,
        appIcon: NSImage? = nil,
        package: String? = nil,
        actions: [NotificationAction] = [],
        extraActions: [UNNotificationAction] = [],
        extraUserInfo: [String: Any] = [:]
    ) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "\(appName) - \(title)"
        content.body = body
        content.sound = .default

        content.userInfo["nid"] = id
        if let pkg = package { content.userInfo["package"] = pkg }
        // Merge any extra payload the caller wants to pass
        for (k, v) in extraUserInfo { content.userInfo[k] = v }

        // Build action list (Android actions + optional View action if mirroring conditions)
        let actionDefinitions: [NotificationAction] = actions
        var includeView = false
        if let pkg = package, pkg != "com.sameerasw.airsync", adbConnected, mirroringPlus {
            includeView = true
        }

        // Construct UNNotificationActions
        var unActions: [UNNotificationAction] = []
        for a in actionDefinitions.prefix(8) { // safety cap
            switch a.type {
            case .button:
                unActions.append(UNNotificationAction(identifier: "ACT_\(a.name)", title: a.name, options: []))
            case .reply:
                if #available(macOS 13.0, *) {
                    unActions.append(UNTextInputNotificationAction(identifier: "ACT_\(a.name)", title: a.name, options: [], textInputButtonTitle: "Send", textInputPlaceholder: a.name))
                } else {
                    unActions.append(UNNotificationAction(identifier: "ACT_\(a.name)", title: a.name, options: []))
                }
            }
        }
        if includeView {
            unActions.append(UNNotificationAction(identifier: "VIEW_ACTION", title: "View", options: []))
        }
        // Append caller-provided extra actions (e.g., OPEN_LINK)
        unActions.append(contentsOf: extraActions)

        // Choose category: DEFAULT_CATEGORY when no custom actions besides optional view; otherwise derive
        if unActions.isEmpty {
            content.categoryIdentifier = "DEFAULT_CATEGORY"
            content.userInfo["actions"] = []
            finalizeAndSchedule(center: center, content: content, id: id, appIcon: appIcon)
        } else {
            let actionNamesKey = unActions.map { $0.identifier }.joined(separator: "_")
            let catId = "DYN_\(actionNamesKey)"
            content.categoryIdentifier = catId
            content.userInfo["actions"] = actions.map { ["name": $0.name, "type": $0.type.rawValue] }

            center.getNotificationCategories { existing in
                if existing.first(where: { $0.identifier == catId }) == nil {
                    let newCat = UNNotificationCategory(identifier: catId, actions: unActions, intentIdentifiers: [], options: [])
                    center.setNotificationCategories(existing.union([newCat]))
                }
                self.finalizeAndSchedule(center: center, content: content, id: id, appIcon: appIcon)
            }
        }
    }

    private func finalizeAndSchedule(center: UNUserNotificationCenter, content: UNMutableNotificationContent, id: String, appIcon: NSImage?) {
        // Attach icon
        if let icon = appIcon, let iconFileURL = saveIconToTemporaryFile(icon: icon) {
            if let attachment = try? UNNotificationAttachment(identifier: "appIcon", url: iconFileURL, options: nil) {
                content.attachments = [attachment]
            }
        }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request) { error in
            if let error = error { print("Failed to post native notification: \(error)") }
        }
    }

    private func saveIconToTemporaryFile(icon: NSImage) -> URL? {
        // Save NSImage as a temporary PNG file to attach in notification
        guard let tiffData = icon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFile = tempDir.appendingPathComponent("notification_icon_\(UUID().uuidString).png")

        do {
            try pngData.write(to: tempFile)
            return tempFile
        } catch {
            print("Error saving icon to temp file: \(error)")
            return nil
        }
    }

    func syncWithSystemNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { systemNotifs in
            let systemNIDs = Set(systemNotifs.map { $0.request.identifier })

            DispatchQueue.main.async {
                let currentNIDs = Set(self.notifications.map { $0.nid })
                let removedNIDs = currentNIDs.subtracting(systemNIDs)

                for nid in removedNIDs {
                    print("System notification \(nid) was dismissed manually.")
                    self.removeNotificationById(nid)
                }
            }
        }
    }

    private func startClipboardMonitoring() {
        guard isClipboardSyncEnabled else { return }
        clipboardCancellable = Timer
            .publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let pasteboard = NSPasteboard.general
                if let copiedString = pasteboard.string(forType: .string),
                   copiedString != self.lastClipboardValue {
                    self.lastClipboardValue = copiedString
                    self.sendClipboardToAndroid(text: copiedString)
                    print("Clipboard updated :" + copiedString)
                }
            }
    }

    func sendClipboardToAndroid(text: String) {
        let message = """
    {
        "type": "clipboardUpdate",
        "data": {
            "text": "\(text.replacingOccurrences(of: "\"", with: "\\\""))"
        }
    }
    """
        WebSocketServer.shared.sendClipboardUpdate(message)
    }

    func updateClipboardFromAndroid(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        self.lastClipboardValue = text

        // Only show "Continue browsing" if the whole text is a valid http/https URL
        // AND the user has AirSync+ (isPlus). Otherwise show a regular clipboard update.
        if let url = exactURL(from: text), self.isPlus {
            let open = UNNotificationAction(identifier: "OPEN_LINK", title: "Open", options: [])
            self.postNativeNotification(
                id: "clipboard",
                appName: "Clipboard",
                title: "Continue browsing",
                body: text,
                extraActions: [open],
                extraUserInfo: ["url": url.absoluteString]
            )
        } else {
            // Non-plus users or non-URL clipboard content: simple clipboard update notification
            self.postNativeNotification(id: "clipboard", appName: "Clipboard", title: "Updated", body: text)
        }
    }

    private func stopClipboardMonitoring() {
        clipboardCancellable?.cancel()
        clipboardCancellable = nil
    }

    // MARK: - Continue browsing helper (exact URL detection)
    private func exactURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else { return nil }
        // Ensure no extra text beyond a URL
        if trimmed != text { /* allow surrounding whitespace */ }
        return url
    }

    func wallpaperCacheDirectory() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wallpapers", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    var currentWallpaperPath: String? {
        guard let device = myDevice else { return nil }
        let key = "\(device.name)-\(device.ipAddress)"
        return deviceWallpapers[key]
    }

    private func saveLicenseDetailsToUserDefaults() {
        guard let details = licenseDetails else {
            UserDefaults.standard.removeObject(forKey: licenseDetailsKey)
            return
        }

        do {
            let data = try JSONEncoder().encode(details)
            UserDefaults.standard.set(data, forKey: licenseDetailsKey)
        } catch {
            print("Failed to encode license details: \(error)")
        }
    }

    private func loadLicenseDetailsFromUserDefaults() -> LicenseDetails? {
        guard let data = UserDefaults.standard.data(forKey: licenseDetailsKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(LicenseDetails.self, from: data)
        } catch {
            print("Failed to decode license details: \(error)")
            return nil
        }
    }

    func saveAppsToDisk() {
        let url = appIconsDirectory().appendingPathComponent("apps.json")
        do {
            let data = try JSONEncoder().encode(Array(AppState.shared.androidApps.values))
            try data.write(to: url)
        } catch {
            print("Error saving apps: \(error)")
        }
    }

    func loadAppsFromDisk() {
        let url = appIconsDirectory().appendingPathComponent("apps.json")
        do {
            let data = try Data(contentsOf: url)
            let apps = try JSONDecoder().decode([AndroidApp].self, from: data)
            DispatchQueue.main.async {
                for app in apps {
                    AppState.shared.androidApps[app.packageName] = app
                    if let iconPath = app.iconUrl {
                        AppState.shared
                            .androidApps[app.packageName]?.iconUrl = iconPath
                    }
                }
            }
        } catch {
            print("Error loading apps: \(error)")
        }
    }

    func updateDockIconVisibility() {
        DispatchQueue.main.async {
            if self.hideDockIcon {
                NSApp.setActivationPolicy(.accessory)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
}
