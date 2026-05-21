import SwiftUI

struct RehberTab: View {
    /// Incremented by parent when the user re-taps the Rehber tab — pops to root.
    @Binding var popToRoot: Int
    @State private var navPath: [Directory] = []
    @State private var showAI = false
    @State private var showSearch = false
    @Namespace private var tileNS

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Invisible anchor at the very top for scroll-to-top
                        Color.clear.frame(height: 0).id("rehber-top")
                        heroSection
                        categoriesSection
                            .padding(.bottom, 32)
                    }
                }
                .background(Color.tgsCream)
                // Pop to root OR scroll to top on tab re-tap
                .tgsOnChange(of: popToRoot) {
                    if navPath.isEmpty {
                        // Already at root — scroll to top
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                            proxy.scrollTo("rehber-top", anchor: .top)
                        }
                    } else {
                        // On a subpage — pop to root
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            navPath = []
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                // Centered, no Liquid Glass capsule (unlike leading/trailing placements)
                ToolbarItem(placement: .principal) { navLogo }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.tgsRed)
                    }
                    .accessibilityLabel("Ara")
                }
            }
            .navigationDestination(for: Directory.self) { directory in
                DirectoryListView(directory: directory)
                    .zoomNavTransition(sourceID: directory, in: tileNS)
            }
            .fullScreenCover(isPresented: $showAI) {
                ITTAIView()
            }
            .sheet(isPresented: $showSearch) {
                AraTab()
            }
        }
    }

    // MARK: – Nav logo (combined brand image)

    private var navLogo: some View {
        Image("ITTHeaderLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 22)
            .accessibilityLabel("İsviçre Türk Toplumu — TGS · ATS")
    }

    // MARK: – Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.tgsRed, Color.tgsHeroGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(GrainOverlay())

            VStack(spacing: TGSSpacing.md) {
                heroCard
                aiEntryButton
            }
            .padding(.horizontal, TGSSpacing.xl)
            .padding(.top, 28)
            .padding(.bottom, 50)
        }
        .clipShape(WaveClipShape(waveDepth: 30))
    }

    // MARK: – Glass info card (always visible — no dismiss)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Top row: greeting + flag
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("İsviçre Türk Rehberi")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(todayString)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.60))
                }
                Spacer()
                Text("🇨🇭")
                    .font(.system(size: 32))
            }

            // Divider
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(height: 1)

            // Search pill — tappable placeholder leading to AI
            Button {
                showAI = true
            } label: {
                HStack(spacing: TGSSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Uzman, hizmet, etkinlik ara…")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.50))
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, TGSSpacing.md)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.13))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(TGSSpacing.lg)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: TGSRadius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TGSRadius.card, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: – AI Entry Button

    private var aiEntryButton: some View {
        Button {
            showAI = true
        } label: {
            HStack(spacing: TGSSpacing.md) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("İTT AI'ya sor")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("İsviçre'deki sorularınız için")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(TGSSpacing.md)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: TGSRadius.inner, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TGSRadius.inner, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(TGSSpringButtonStyle())
        .accessibilityLabel("İTT AI — Yapay zeka asistanını aç")
    }

    // MARK: – Categories section

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: TGSSpacing.lg) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KATEGORİLER")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.tgsMuted)
                        .tracking(1.2)
                    Text("Uzman ve hizmetlere göz atın")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.tgsCharcoal)
                }
                Spacer()
            }
            .padding(.horizontal, TGSSpacing.lg)

            DirectoryGridView(namespace: tileNS)
                .padding(.horizontal, TGSSpacing.lg)
        }
        .padding(.top, TGSSpacing.xl)
    }

    // MARK: – Helpers

    private var todayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM yyyy, EEEE"
        return f.string(from: Date())
    }
}

// MARK: - Directory Grid

struct DirectoryGridView: View {
    var namespace: Namespace.ID
    private let columns = [GridItem(.flexible(), spacing: TGSSpacing.md),
                           GridItem(.flexible(), spacing: TGSSpacing.md)]
    @State private var appeared = false

    var body: some View {
        LazyVGrid(columns: columns, spacing: TGSSpacing.md) {
            ForEach(Array(Directory.allCases.enumerated()), id: \.element) { idx, directory in
                NavigationLink(value: directory) {
                    DirectoryTile(directory: directory)
                }
                // Zoom transition source (iOS 18+); no-op on earlier
                .zoomSource(id: directory, in: namespace)
                .buttonStyle(TGSSpringButtonStyle())
                .accessibilityLabel(directory.titleTR)
                .accessibilityHint(directory.cta)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 22)
                .animation(
                    .spring(response: 0.44, dampingFraction: 0.74)
                        .delay(Double(idx) * 0.055),
                    value: appeared
                )
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Directory Tile  (uses directory.color for accent)

struct DirectoryTile: View {
    let directory: Directory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Icon with per-category color
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(directory.color.opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: directory.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(directory.color)
                    .frame(width: 50, height: 50)

                if directory.isNew {
                    Text("Yeni")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(directory.color))
                        .offset(x: 6, y: 4)
                }
            }

            Spacer(minLength: TGSSpacing.md)

            Text(directory.titleTR)
                .font(TGSFont.rowTitle)
                .foregroundStyle(Color.tgsCharcoal)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: TGSSpacing.sm)

            HStack(spacing: 3) {
                Text(directory.cta)
                    .font(TGSFont.micro)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(directory.color)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .padding(TGSSpacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: TGSRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.055), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: TGSRadius.card, style: .continuous)
                .stroke(Color.tgsBorder.opacity(0.6), lineWidth: 0.5)
        )
    }
}

// MARK: - Coming Soon

struct ComingSoonView: View {
    let directory: Directory

    var body: some View {
        VStack(spacing: TGSSpacing.xl) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(directory.color.opacity(0.10))
                    .frame(width: 90, height: 90)
                Image(systemName: directory.systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(directory.color)
            }
            VStack(spacing: TGSSpacing.sm) {
                Text(directory.titleTR)
                    .font(TGSFont.title)
                    .foregroundStyle(Color.tgsCharcoal)
                Text("Bu rehber yakında hizmete girecek.")
                    .font(TGSFont.subheadline)
                    .foregroundStyle(Color.tgsMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tgsCream)
        .navigationTitle(directory.titleTR)
        .navigationBarTitleDisplayMode(.inline)
    }
}
