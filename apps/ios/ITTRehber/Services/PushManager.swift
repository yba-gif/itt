import Foundation
import UIKit
import UserNotifications

/// Wraps UNUserNotificationCenter + APNs registration. PRD §5.9: ask at a
/// contextual moment (after first event view), not at first launch.
@MainActor
final class PushManager: NSObject, ObservableObject {
    static let shared = PushManager()

    @Published private(set) var authorized: Bool = false
    private var lastDeviceToken: Data?

    private override init() {}

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorized = true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                authorized = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                authorized = false
            }
        case .denied:
            authorized = false
        @unknown default:
            authorized = false
        }
    }

    /// Called from AppDelegate when APNs returns a device token.
    func didRegisterForRemoteNotifications(deviceToken: Data) async {
        lastDeviceToken = deviceToken
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        do {
            try await APIClient.shared.registerPush(
                token: token,
                categories: ["events", "editorial", "my_listing"],
                kanton: nil
            )
        } catch {
            // Best-effort; we'll retry on next launch.
        }
    }
}

/// AppDelegate is required to receive APNs device-token callbacks (SwiftUI alone
/// doesn't expose them). Wired via `@UIApplicationDelegateAdaptor`.
final class ITTAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await PushManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Logged silently; user's authorization is still tracked in PushManager.
    }
}
