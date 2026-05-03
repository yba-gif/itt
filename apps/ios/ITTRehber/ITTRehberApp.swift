import SwiftUI

@main
struct ITTRehberApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var cache = OfflineCache.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(session)
                .environmentObject(cache)
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

            EtkinliklerTab()
                .tabItem { Label("Etkinlikler", systemImage: "calendar") }

            BilgiTab()
                .tabItem { Label("Bilgi", systemImage: "info.circle") }

            ProfilTab()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
    }
}
