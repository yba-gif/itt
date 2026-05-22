import Foundation
import SwiftUI

// MARK: - Nav coordinator
//
// Shared navigation state so views in one tab (e.g. ITT AI) can trigger
// navigation in another tab (e.g. open Rehber → Sağlık). Without this,
// ITTAIView has no way to push onto RehberTab's NavigationStack.
//
// Wired in ITTRehberApp.swift as an @StateObject + .environmentObject.
// RootTabView reads `selectedTab` (replaces the previous @State).
// RehberTab reads `rehberPath` as the NavigationStack(path:).
// ITTAIView calls `openDirectory(_:)` from its AI deep-link handler.

@MainActor
final class Nav: ObservableObject {
    /// Which tab the FloatingTabBar shows. Two-way bound so user taps still work.
    @Published var selectedTab: AppTab = .rehber

    /// NavigationStack path for the Rehber tab.
    @Published var rehberPath: [Directory] = []

    /// Bumped each time the user re-taps the Rehber tab in the floating bar
    /// (so the existing scroll-to-top / pop-to-root flow keeps working).
    @Published var rehberPopToken: Int = 0

    // MARK: - High-level intents

    /// Switch to Rehber and push the given directory.
    /// Used by ITT AI when the user asks for something a directory satisfies.
    func openDirectory(_ directory: Directory) {
        selectedTab = .rehber
        rehberPath = [directory]
    }

    /// Switch to a top-level tab.
    func openTab(_ tab: AppTab) {
        selectedTab = tab
    }

    /// Tab-bar re-tap behaviour: if user is on Rehber root, scroll to top;
    /// otherwise pop to root. Driven by the existing rehberPopToken signal.
    func signalRehberReselect() {
        rehberPopToken += 1
    }

    // MARK: - URL routing
    //
    // The AI replies are run through AttributedString(markdown:) which renders
    // [text](url) as links. We intercept `itt://...` schemes in the chat
    // bubble's openURL action and route them here. Returns true if the URL
    // was handled (caller should NOT pass it on to UIApplication.open).

    /// Supported URL forms:
    ///   itt://directory/saglik   → openDirectory(.saglik)
    ///   itt://directory/hukuk
    ///   itt://directory/okullar
    ///   itt://directory/finans
    ///   itt://directory/isletme
    ///   itt://directory/tercume
    ///   itt://directory/meslek
    ///   itt://directory/camiler
    ///   itt://directory/mezunlar
    ///   itt://directory/destek_dersi
    ///   itt://tab/etkinlikler    → openTab(.etkinlikler)
    ///   itt://tab/bilgi          → openTab(.bilgi)
    ///   itt://tab/profil         → openTab(.profil)
    @discardableResult
    func route(_ url: URL) -> Bool {
        guard url.scheme == "itt" else { return false }
        guard let host = url.host else { return false }
        let segments = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "directory":
            guard let code = segments.first, let dir = Directory(rawValue: code) else { return false }
            openDirectory(dir)
            return true
        case "tab":
            guard let name = segments.first else { return false }
            switch name {
            case "rehber":      openTab(.rehber)
            case "ittai":       openTab(.ittai)
            case "etkinlikler": openTab(.etkinlikler)
            case "bilgi":       openTab(.bilgi)
            case "profil":      openTab(.profil)
            default:            return false
            }
            return true
        default:
            return false
        }
    }
}
