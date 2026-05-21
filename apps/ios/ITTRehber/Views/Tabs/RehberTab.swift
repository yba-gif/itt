import SwiftUI

struct RehberTab: View {
    // P1-2: first-run welcome banner
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                        .padding(.horizontal, TGSSpacing.xl)
                        .padding(.top, TGSSpacing.xl)
                        .padding(.bottom, TGSSpacing.xxl)

                    // P1-2: welcome banner — dismissible, shown once on first launch
                    if !hasSeenWelcome {
                        WelcomeBanner { hasSeenWelcome = true }
                            .padding(.horizontal, TGSSpacing.lg)
                            .padding(.bottom, TGSSpacing.lg)
                    }

                    DirectoryGridView()
                        .padding(.horizontal, TGSSpacing.lg)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.tgsCream)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .navigationDestination(for: Directory.self) { directory in
                DirectoryListView(directory: directory)
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TGSEyebrow(icon: "globe.europe.africa.fill", label: "İSVİÇRE'DE TÜRK TOPLULUĞU")
            Text("TGS-ITT Rehber")
                .font(TGSFont.display)
                .foregroundStyle(Color.tgsCharcoal)
            Text("Uzman, hizmet ve etkinlik rehberi")
                .font(TGSFont.subheadline)
                .foregroundStyle(Color.tgsMuted)
        }
    }
}

// MARK: - Welcome Banner (P1-2)

struct WelcomeBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.tgsRed)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Hoş geldiniz!")
                    .font(TGSFont.caption)
                    .foregroundStyle(Color.tgsCharcoal)
                Text("Bir kategori seçerek İsviçre'deki Türk uzman ve hizmetlere ulaşın.")
                    .font(TGSFont.micro)
                    .foregroundStyle(Color.tgsMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeOut(duration: 0.2)) { onDismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.tgsMuted)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.tgsSurface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hoş geldiniz mesajını kapat")
        }
        .padding(TGSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TGSRadius.inner, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: TGSRadius.inner, style: .continuous)
                        .stroke(Color.tgsBorder, lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Directory Grid

struct DirectoryGridView: View {
    private let columns = [GridItem(.flexible(), spacing: TGSSpacing.md),
                           GridItem(.flexible(), spacing: TGSSpacing.md)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: TGSSpacing.md) {
            ForEach(Directory.allCases) { directory in
                NavigationLink(value: directory) {
                    DirectoryTile(directory: directory)
                }
                .buttonStyle(.plain)
                // P1-4 a11y: label and hint for VoiceOver
                .accessibilityLabel(directory.titleTR)
                .accessibilityHint(directory.cta)
            }
        }
    }
}

/// P1-3: editorial white card tile — category-specific CTA.
/// Mirrors website's Programs.tsx card pattern.
struct DirectoryTile: View {
    let directory: Directory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon badge
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

            // P1-3: per-category CTA instead of generic "İncele →"
            HStack(spacing: 3) {
                Text(directory.cta)
                    .font(TGSFont.micro)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Color.tgsRed)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .padding(TGSSpacing.lg)
        .tgsCard()
    }
}

struct ComingSoonView: View {
    let directory: Directory

    var body: some View {
        VStack(spacing: TGSSpacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 90, height: 90)
                Image(systemName: directory.systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.tgsRed)
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
