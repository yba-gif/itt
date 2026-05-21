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
                .preferredColorScheme(.light) // TGS design is light-only
                .tint(Color.tgsRed) // TGS brand red #B82030
        }
    }
}

// Sprint 6: custom floating tab bar replaces system TabView
struct RootTabView: View {
    @State private var selectedTab: AppTab = .rehber

    var body: some View {
        ZStack(alignment: .bottom) {
            // All tab views pre-loaded; only active one accepts hit-testing.
            // This preserves per-tab NavigationStack state when switching tabs.
            Group {
                RehberTab()
                    .opacity(selectedTab == .rehber ? 1 : 0)
                    .allowsHitTesting(selectedTab == .rehber)
                AraTab()
                    .opacity(selectedTab == .ara ? 1 : 0)
                    .allowsHitTesting(selectedTab == .ara)
                EtkinliklerTab()
                    .opacity(selectedTab == .etkinlikler ? 1 : 0)
                    .allowsHitTesting(selectedTab == .etkinlikler)
                BilgiTab()
                    .opacity(selectedTab == .bilgi ? 1 : 0)
                    .allowsHitTesting(selectedTab == .bilgi)
                ProfilTab()
                    .opacity(selectedTab == .profil ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profil)
            }
            // Reserve space so scroll content clears the floating bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 82)
            }

            // Floating pill — sits above safe area
            FloatingTabBar(selected: $selectedTab)
                .padding(.bottom, 20)
                .padding(.horizontal, 32)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
