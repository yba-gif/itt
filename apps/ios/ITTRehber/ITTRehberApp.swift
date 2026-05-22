import SwiftUI

@main
struct ITTRehberApp: App {
    @UIApplicationDelegateAdaptor(ITTAppDelegate.self) var appDelegate
    @StateObject private var session = SessionStore()
    @StateObject private var cache = OfflineCache.shared
    @StateObject private var push = PushManager.shared
    /// Shared navigation state — lets ITT AI redirect to Rehber directories.
    @StateObject private var nav = Nav()

    /// Persists across launches. False until OnboardingView's `finish()` runs.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        // Larger URLCache so listing/event thumbnails persist across launches
        // and scrolling back never re-fetches. Pairs with CachedAsyncImage.
        URLCacheBoost.install()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(session)
                .environmentObject(cache)
                .environmentObject(push)
                .environmentObject(nav)
                .preferredColorScheme(.light) // TGS design is light-only
                .tint(Color.tgsRed) // TGS brand red #B82030
                // First launch: cover everything with the onboarding flow
                .fullScreenCover(isPresented: .init(
                    get: { !hasCompletedOnboarding },
                    set: { _ in }  // OnboardingView owns the dismiss via @AppStorage
                )) {
                    OnboardingView()
                }
        }
    }
}

// Sprint 6: custom floating tab bar replaces system TabView
struct RootTabView: View {
    @EnvironmentObject var nav: Nav

    var body: some View {
        ZStack(alignment: .bottom) {
            // All tab views pre-loaded; only active one accepts hit-testing.
            // This preserves per-tab NavigationStack state when switching tabs.
            Group {
                RehberTab()
                    .opacity(nav.selectedTab == .rehber ? 1 : 0)
                    .allowsHitTesting(nav.selectedTab == .rehber)
                ITTAIView(isModal: false)
                    .opacity(nav.selectedTab == .ittai ? 1 : 0)
                    .allowsHitTesting(nav.selectedTab == .ittai)
                EtkinliklerTab()
                    .opacity(nav.selectedTab == .etkinlikler ? 1 : 0)
                    .allowsHitTesting(nav.selectedTab == .etkinlikler)
                BilgiTab()
                    .opacity(nav.selectedTab == .bilgi ? 1 : 0)
                    .allowsHitTesting(nav.selectedTab == .bilgi)
                ProfilTab()
                    .opacity(nav.selectedTab == .profil ? 1 : 0)
                    .allowsHitTesting(nav.selectedTab == .profil)
            }
            // Reserve space so scroll content clears the floating bar.
            // Bar height ~56pt + padding-bottom 20pt = 76pt visible; add ~30pt
            // breathing room so text doesn't visually touch the bar's top edge.
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 108)
            }

            // Floating pill — sits above safe area
            FloatingTabBar(selected: $nav.selectedTab, onReselect: { tab in
                // Tapping the already-active tab pops its NavigationStack to
                // root (or scrolls to top, depending on the tab's behaviour).
                nav.signalReselect(tab)
            })
            .padding(.bottom, 20)
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
