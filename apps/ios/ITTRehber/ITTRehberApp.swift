import SwiftUI

@main
struct ITTRehberApp: App {
    @UIApplicationDelegateAdaptor(ITTAppDelegate.self) var appDelegate
    @StateObject private var session = SessionStore()
    @StateObject private var cache = OfflineCache.shared
    @StateObject private var push = PushManager.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(session)
                .environmentObject(cache)
                .environmentObject(push)
                .preferredColorScheme(nil) // respect system
                .tint(Color(red: 0.10, green: 0.39, blue: 0.78)) // #1A64C7 brand blue
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            RehberTab()
                .tabItem { Label("Rehber", systemImage: "square.grid.2x2.fill") }

            AraTab()
                .tabItem { Label("Ara", systemImage: "magnifyingglass") }

            EtkinliklerTab()
                .tabItem { Label("Etkinlikler", systemImage: "calendar") }

            BilgiTab()
                .tabItem { Label("Bilgi", systemImage: "info.circle.fill") }

            ProfilTab()
                .tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }
        }
    }
}
