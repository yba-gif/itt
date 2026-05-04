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
                .tint(Color("BrandPrimary", bundle: nil))
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            RehberTab()
                .tabItem { Label("Rehber", systemImage: "list.bullet.rectangle") }

            AraTab()
                .tabItem { Label("Ara", systemImage: "magnifyingglass") }

            EtkinliklerTab()
                .tabItem { Label("Etkinlikler", systemImage: "calendar") }

            BilgiTab()
                .tabItem { Label("Bilgi", systemImage: "info.circle") }

            ProfilTab()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
    }
}
