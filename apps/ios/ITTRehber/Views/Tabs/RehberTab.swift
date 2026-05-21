import SwiftUI

struct RehberTab: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showAI = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    DirectoryGridView()
                        .padding(.horizontal, TGSSpacing.lg)
                        .padding(.top, TGSSpacing.xl)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.tgsCream)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationDestination(for: Directory.self) { directory in
                DirectoryListView(directory: directory)
            }
            .fullScreenCover(isPresented: $showAI) {
                ITTAIView()
            }
        }
    }

    // MARK: Hero — gradient + wave + glassmorphic card (Sprint 6)

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.tgsRed, Color(tgsHex: 0x6B1020)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(GrainOverlay())

            VStack(alignment: .leading, spacing: TGSSpacing.lg) {
                TGSEyebrow(icon: "globe.europe.africa.fill", label: "İSVİÇRE'DE TÜRK TOPLULUĞU")
                    .colorInvert()
                    .opacity(0.9)

                VStack(alignment: .leading, spacing: 4) {
                    Text("TGS-ITT")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                    Text("Rehber")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white.opacity(0.82))
                }

                glassCard
                aiEntryButton
            }
            .padding(.horizontal, TGSSpacing.xl)
            .padding(.top, 60)
            .padding(.bottom, 50)
        }
        .clipShape(WaveClipShape(waveDepth: 30))
    }

    // MARK: - İTT AI Entry Button

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
                    Text("Yapay zeka asistanı")
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

    private var glassCard: some View {
        Group {
            if !hasSeenWelcome {
                WelcomeBanner { hasSeenWelcome = true }
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: TGSRadius.inner, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: TGSRadius.inner, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )
            } else {
                HStack(spacing: TGSSpacing.md) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Uzman, hizmet ve etkinlik rehberi")
                        .font(TGSFont.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer(minLength: 0)
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
        }
    }
}

// MARK: - Welcome Banner (dark-hero variant)

struct WelcomeBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Hoş geldiniz!")
                    .font(TGSFont.caption)
                    .foregroundStyle(.white)
                Text("Bir kategori seçerek İsviçre'deki Türk uzman ve hizmetlere ulaşın.")
                    .font(TGSFont.micro)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeOut(duration: 0.2)) { onDismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hoş geldiniz mesajını kapat")
        }
        .padding(TGSSpacing.md)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Directory Grid

struct DirectoryGridView: View {
    private let columns = [GridItem(.flexible(), spacing: TGSSpacing.md),
                           GridItem(.flexible(), spacing: TGSSpacing.md)]
    @State private var appeared = false

    var body: some View {
        LazyVGrid(columns: columns, spacing: TGSSpacing.md) {
            ForEach(Array(Directory.allCases.enumerated()), id: \.element) { idx, directory in
                NavigationLink(value: directory) {
                    DirectoryTile(directory: directory)
                }
                // Sprint 6: spring press via TGSSpringButtonStyle
                .buttonStyle(TGSSpringButtonStyle())
                .accessibilityLabel(directory.titleTR)
                .accessibilityHint(directory.cta)
                // Sprint 6: staggered spring entrance
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

// MARK: - Directory Tile

struct DirectoryTile: View {
    let directory: Directory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 46, height: 46)
                Image(systemName: directory.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }
            Spacer(minLength: TGSSpacing.md)
            Text(directory.titleTR)
                .font(TGSFont.rowTitle)
                .foregroundStyle(Color.tgsCharcoal)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: TGSSpacing.md)
            HStack(spacing: 3) {
                Text(directory.cta).font(TGSFont.micro)
                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Color.tgsRed)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .padding(TGSSpacing.lg)
        .tgsCard()
    }
}

// MARK: - Coming Soon

struct ComingSoonView: View {
    let directory: Directory

    var body: some View {
        VStack(spacing: TGSSpacing.xl) {
            ZStack {
                Circle().fill(Color.tgsRed.opacity(0.10)).frame(width: 90, height: 90)
                Image(systemName: directory.systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.tgsRed)
            }
            VStack(spacing: TGSSpacing.sm) {
                Text(directory.titleTR).font(TGSFont.title).foregroundStyle(Color.tgsCharcoal)
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
