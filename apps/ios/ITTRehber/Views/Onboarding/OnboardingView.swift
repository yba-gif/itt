import SwiftUI
import UserNotifications

// MARK: - Onboarding Flow
// First-launch experience. Three pages:
//   1. Welcome — brand + tagline + value proposition
//   2. Kanton picker (optional) — pre-filters Rehber list to user's canton
//   3. Notification permission — explains value, then prompts
//
// State stored in @AppStorage:
//   hasCompletedOnboarding (Bool) — never re-show after completion
//   preferredKanton (String) — empty = "all"; otherwise a 2-letter code
//
// Wired in ITTRehberApp.swift: shown as fullScreenCover when
// hasCompletedOnboarding == false.

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("preferredKanton") private var preferredKanton = ""
    @State private var page = 0
    @State private var requestingPush = false

    var body: some View {
        ZStack {
            // Subtle red-tint background — matches Rehber hero
            LinearGradient(
                colors: [Color.tgsRed.opacity(0.06), Color.tgsCream],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            TabView(selection: $page) {
                welcomePage.tag(0)
                kantonPage.tag(1)
                pushPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // Brand logo (flags)
            Image("ITTHeaderLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .padding(.bottom, TGSSpacing.lg)

            Text("İsviçre Türk Toplumu")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.tgsCharcoal)
                .multilineTextAlignment(.center)

            Text("Rehberi")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.tgsRed)
                .padding(.bottom, TGSSpacing.lg)

            Text("İsviçre'de Türkçe konuşan topluluk için kapsamlı rehber, etkinlikler ve bilgi platformu.")
                .font(.system(size: 16))
                .foregroundStyle(Color.tgsMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, TGSSpacing.xl)

            // Feature highlights
            VStack(alignment: .leading, spacing: 14) {
                featureRow(icon: "cross.case.fill", color: Color(red: 0.18, green: 0.73, blue: 0.47), text: "Sağlık, hukuk, eğitim uzmanları")
                featureRow(icon: "calendar", color: Color(red: 0.05, green: 0.65, blue: 0.91), text: "TGS-ITT etkinlikleri")
                featureRow(icon: "building.columns.fill", color: Color.tgsRed, text: "Konsolosluk ve acil bilgiler")
                featureRow(icon: "sparkles", color: Color(red: 0.49, green: 0.23, blue: 0.93), text: "İTT AI — yapay zeka asistan")
            }
            .padding(.horizontal, 36)

            Spacer()

            primaryButton(title: "Başlayalım") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    page = 1
                }
            }
            .padding(.horizontal, TGSSpacing.xl)
            .padding(.bottom, 60)
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: TGSSpacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.13))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.tgsCharcoal)
            Spacer()
        }
    }

    // MARK: - Page 2: Kanton picker

    private var kantonPage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }
            .padding(.bottom, TGSSpacing.lg)

            Text("Hangi kantonda yaşıyorsunuz?")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tgsCharcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, TGSSpacing.sm)

            Text("Size en yakın hizmetleri öne çıkarmamız için seçin. İstediğiniz zaman değiştirebilirsiniz.")
                .font(.system(size: 14))
                .foregroundStyle(Color.tgsMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, TGSSpacing.lg)

            // Kanton grid — 2 columns, scrollable
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ], spacing: 10) {
                    ForEach(Kanton.all) { kanton in
                        kantonChip(kanton)
                    }
                }
                .padding(.horizontal, TGSSpacing.lg)
                .padding(.bottom, TGSSpacing.md)
            }

            primaryButton(title: preferredKanton.isEmpty ? "Şimdilik atla" : "Devam et") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    page = 2
                }
            }
            .padding(.horizontal, TGSSpacing.xl)
            .padding(.bottom, 60)
        }
    }

    private func kantonChip(_ kanton: Kanton) -> some View {
        let selected = preferredKanton == kanton.code
        return Button {
            preferredKanton = selected ? "" : kanton.code
        } label: {
            HStack(spacing: 6) {
                Text(kanton.code)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(selected ? .white : Color.tgsRed)
                    .frame(minWidth: 26)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(
                        Capsule().fill(selected ? Color.white.opacity(0.25) : Color.tgsRed.opacity(0.10))
                    )
                Text(kanton.nameTR)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? .white : Color.tgsCharcoal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.tgsRed : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.tgsRed : Color.tgsBorder, lineWidth: 1)
            )
        }
        .buttonStyle(TGSSpringButtonStyle())
        .accessibilityLabel("\(kanton.nameTR) kantonu")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Page 3: Push permission

    private var pushPage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }
            .padding(.bottom, TGSSpacing.xl)

            Text("Bildirimleri aç")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tgsCharcoal)
                .padding(.bottom, TGSSpacing.sm)

            Text("Önemli güncellemeleri kaçırmamak için bildirim izni verin.")
                .font(.system(size: 15))
                .foregroundStyle(Color.tgsMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.bottom, TGSSpacing.xl)

            VStack(alignment: .leading, spacing: 14) {
                bulletRow(icon: "calendar.badge.plus", text: "Bölgenizdeki yeni etkinlikler")
                bulletRow(icon: "magnifyingglass.circle.fill", text: "Kayıtlı aramalarınızda yeni sonuçlar")
                bulletRow(icon: "exclamationmark.bubble.fill", text: "Konsolosluk mobil hizmet duyuruları")
            }
            .padding(.horizontal, 36)

            Spacer()

            VStack(spacing: 10) {
                primaryButton(title: requestingPush ? "..." : "Bildirimleri aç") {
                    Task { await askForPush() }
                }
                .disabled(requestingPush)

                Button("Şimdi değil") {
                    finish()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.tgsMuted)
            }
            .padding(.horizontal, TGSSpacing.xl)
            .padding(.bottom, 60)
        }
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: TGSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.tgsRed)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.tgsCharcoal)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func askForPush() async {
        requestingPush = true
        defer { requestingPush = false }
        await PushManager.shared.requestAuthorizationIfNeeded()
        finish()
    }

    private func finish() {
        hasCompletedOnboarding = true
    }

    // MARK: - Shared button

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.tgsRed, Color.tgsHeroGradientEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.tgsRed.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(TGSSpringButtonStyle())
    }
}
