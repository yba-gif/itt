import SwiftUI

struct BilgiTab: View {
    @State private var pages: [ContentPage] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                // Featured hotline card — full-bleed, prominent, sits at the top
                Section {
                    SocialAidHotlineCard()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                Section {
                    // QW-7: sorted by urgency — medical first
                    EmergencyRow(label: "Tıbbi Acil",     number: "144", icon: "heart.fill",    color: .red)
                    EmergencyRow(label: "Polis",          number: "117", icon: "shield.fill",   color: .blue)
                    EmergencyRow(label: "İtfaiye",        number: "118", icon: "flame.fill",    color: .orange)
                    EmergencyRow(label: "Zehir Danışma",  number: "145", icon: "pills.fill",    color: .purple)
                    EmergencyRow(label: "Yol Yardım",     number: "140", icon: "car.fill",      color: Color.tgsMuted)
                } header: {
                    Label("Acil Durumlar", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.tgsError)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }

                Section {
                    ForEach(Consulate.all) { c in
                        NavigationLink {
                            ConsulateDetailView(consulate: c)
                        } label: {
                            ConsulateTileRow(consulate: c)
                        }
                    }
                } header: {
                    Label("Konsolosluk Bilgileri", systemImage: "building.columns.fill")
                        .foregroundStyle(Color.tgsRed)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }

                // Socials — moved above Rehber so platforms are seen first
                Section {
                    SocialsRow()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                        .listRowSeparator(.hidden)
                } header: {
                    Label("Bizi Takip Edin", systemImage: "heart.text.square.fill")
                        .foregroundStyle(Color.tgsRed)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }

                Section("Rehber") {
                    // Bağış — dedicated donation page (not a content page)
                    NavigationLink {
                        DonationView()
                    } label: {
                        Label("Bağış / Destekleyin", systemImage: "heart.fill")
                            .foregroundStyle(Color.tgsCharcoal)
                    }

                    if loading && pages.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Yükleniyor…").foregroundStyle(Color.tgsMuted)
                        }
                    } else {
                        // Exclude slugs shown elsewhere in this view
                        ForEach(pages.filter { !["emergency", "welcome", "consulate"].contains($0.slug) }) { page in
                            NavigationLink(page.title) {
                                ContentPageView(slug: page.slug)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.tgsCream)
            .navigationTitle("Bilgi")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            pages = try await APIClient.shared.contentPages()
        } catch {
            // Offline-friendly: keep whatever we already loaded.
        }
    }
}

struct EmergencyRow: View {
    let label: String
    let number: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .foregroundStyle(Color.tgsCharcoal)
            Spacer()
            Button {
                if let url = URL(string: "tel://\(number)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(number)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.tgsRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.tgsRed.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label): \(number) numarasını ara")
        }
    }
}

struct ContentPageView: View {
    let slug: String

    @State private var page: ContentPage?
    @State private var error: String?

    var body: some View {
        ScrollView {
            if let page {
                MarkdownView(markdown: page.bodyMarkdown)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error {
                // P2-5: reusable inline error state
                ErrorStateView(message: error) { self.error = nil; Task { await load() } }
                    .padding(.top, 32)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .background(Color.tgsCream)
        // NavigationStack push destinations don't inherit the parent's
        // safeAreaInset for the floating tab bar — apply locally so the last
        // paragraph clears the tab bar instead of disappearing behind it.
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .navigationTitle(page?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            page = try await APIClient.shared.contentPage(slug: slug)
        } catch let api as APIError {
            error = api.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

}

// MARK: - Consulate Row

// MARK: - Consulate model + data

struct Consulate: Identifiable {
    var id: String { city }
    let city: String
    let title: String
    let address: String
    /// E.164 format, used for `tel://` URLs (no spaces, no dashes).
    let phone: String
    /// Human-friendly format shown in UI.
    let phoneDisplay: String
    /// Optional — honorary consulates without published email are nil.
    let email: String?
    /// Public website (https://).
    let website: String
    /// Short hours summary (e.g. "Pzt - Cuma 09:00 - 13:00").
    let hoursSummary: String
    /// Detail/footnote on hours (e.g. randevu requirement).
    let hoursDetail: String?

    /// Current consul / ambassador. Optional so the card hides when not set.
    /// Update by editing `Consulate.all` below — single source of truth.
    let consulName: String?
    /// Their role, always shown ("T.C. … Büyükelçisi" / "… Başkonsolosu").
    let consulTitle: String
    /// Remote photo URL (https://…). Use the official MFA / consulate
    /// website photo. Nil → renders initials placeholder.
    let consulPhotoURL: String?

    /// All Turkish consulates serving Switzerland. Verify before launch —
    /// emails follow standard MFA patterns (embassy.*/consulate.*) but should
    /// be confirmed against the official mfa.gov.tr pages.
    static let all: [Consulate] = [
        Consulate(
            city: "Bern",
            title: "Türkiye Büyükelçiliği",
            address: "Villastrasse 32, 3006 Bern",
            phone: "+41313592200",
            phoneDisplay: "+41 31 359 22 00",
            email: "embassy.berne@mfa.gov.tr",
            website: "https://bern-be.mfa.gov.tr",
            hoursSummary: "Pzt - Cuma 09:00 - 13:00",
            hoursDetail: "Konsolosluk işlemleri için randevu zorunludur. Randevu için web sitesini ziyaret edin.",
            consulName: "Şebnem İncesu",
            consulTitle: "T.C. Bern Büyükelçisi",
            consulPhotoURL: "https://bern-be.mfa.gov.tr/Content/assets/consulate/images/localCache//60/866246c9-a693-427a-aab8-02ad0e68de29.png"
        ),
        Consulate(
            city: "Zürich",
            title: "Türkiye Cumhuriyeti Başkonsolosluğu",
            address: "Basteiplatz 2, 8001 Zürich",
            phone: "+41442016400",
            phoneDisplay: "+41 44 201 64 00",
            email: "konsolosluk.zurih@mfa.gov.tr",
            website: "https://zurih.bk.mfa.gov.tr",
            hoursSummary: "Pzt - Cuma 09:00 - 13:00",
            hoursDetail: "Konsolosluk işlemleri için randevu zorunludur.",
            // ⚠️ Replace with the current consul general's name + photo URL.
            // Source: zurih.bk.mfa.gov.tr/Mission/MissionChief
            consulName: nil,
            consulTitle: "T.C. Zürih Başkonsolosu",
            consulPhotoURL: nil
        ),
        Consulate(
            city: "Cenevre",
            title: "Türkiye Cumhuriyeti Başkonsolosluğu",
            address: "Avenue Soret 4, 1203 Genève",
            phone: "+41227321600",
            phoneDisplay: "+41 22 732 16 00",
            email: "konsolosluk.cenevre@mfa.gov.tr",
            website: "https://cenevre.bk.mfa.gov.tr",
            hoursSummary: "Pzt - Cuma 09:00 - 13:00",
            hoursDetail: "Konsolosluk işlemleri için randevu zorunludur.",
            // ⚠️ Replace with the current consul general's name + photo URL.
            // Source: cenevre.bk.mfa.gov.tr/Mission/MissionChief
            consulName: nil,
            consulTitle: "T.C. Cenevre Başkonsolosu",
            consulPhotoURL: nil
        ),
        Consulate(
            city: "Basel",
            title: "Fahri Konsolosluk",
            address: "Wallstrasse 11, 4051 Basel",
            phone: "+41613122061",
            phoneDisplay: "+41 61 312 20 61",
            email: nil,
            website: "https://bern.be.mfa.gov.tr",
            hoursSummary: "Randevu ile",
            hoursDetail: "Fahri konsolosluk. Lütfen önceden randevu alınız. Resmi konsolosluk işlemleri için Bern Büyükelçiliği'ne yönlendirilirsiniz.",
            // ⚠️ Replace with the current honorary consul's name + photo.
            consulName: nil,
            consulTitle: "T.C. Basel Fahri Konsolosu",
            consulPhotoURL: nil
        ),
    ]
}

// MARK: - Consulate row (in Bilgi tab list)

struct ConsulateTileRow: View {
    let consulate: Consulate

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(consulate.city)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.tgsCharcoal)
                    Text("·")
                        .foregroundStyle(Color.tgsMuted)
                    Text(consulate.title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.tgsMuted)
                        .lineLimit(1)
                }
                Text(consulate.address)
                    .font(.caption)
                    .foregroundStyle(Color.tgsMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(consulate.city) \(consulate.title) detayları")
    }
}

// MARK: - Consulate detail page

struct ConsulateDetailView: View {
    let consulate: Consulate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                consulCard

                // Tappable rows — call, mail, web, maps
                VStack(spacing: 0) {
                    ConsulateInfoRow(
                        icon: "phone.fill",
                        label: "Telefon",
                        value: consulate.phoneDisplay,
                        accent: Color.tgsRed,
                        isLast: false
                    ) {
                        if let url = URL(string: "tel://\(consulate.phone)") {
                            UIApplication.shared.open(url)
                        }
                    }
                    if let email = consulate.email {
                        ConsulateInfoRow(
                            icon: "envelope.fill",
                            label: "E-posta",
                            value: email,
                            accent: Color.tgsRed,
                            isLast: false
                        ) {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    ConsulateInfoRow(
                        icon: "globe",
                        label: "Web Sitesi",
                        value: consulate.website.replacingOccurrences(of: "https://", with: ""),
                        accent: Color.tgsRed,
                        isLast: false
                    ) {
                        if let url = URL(string: consulate.website) {
                            UIApplication.shared.open(url)
                        }
                    }
                    ConsulateInfoRow(
                        icon: "mappin.and.ellipse",
                        label: "Adres",
                        value: consulate.address,
                        accent: Color.tgsRed,
                        isLast: true
                    ) {
                        let q = consulate.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? consulate.address
                        if let url = URL(string: "https://maps.apple.com/?q=\(q)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.tgsBorder.opacity(0.7), lineWidth: 0.5)
                )

                // Hours card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.tgsRed)
                        Text("Çalışma Saatleri")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.tgsMuted)
                            .textCase(.uppercase)
                            .tracking(0.4)
                    }
                    Text(consulate.hoursSummary)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.tgsCharcoal)
                    if let detail = consulate.hoursDetail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Color.tgsMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.tgsCream.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.tgsBorder.opacity(0.6), lineWidth: 0.5)
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.tgsCream)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .navigationTitle(consulate.city)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 64, height: 64)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(consulate.city)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.tgsCharcoal)
                Text(consulate.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.tgsMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: – Consul / Ambassador card

    private var consulCard: some View {
        HStack(spacing: 14) {
            consulAvatar

            VStack(alignment: .leading, spacing: 4) {
                if let name = consulate.consulName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.tgsCharcoal)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(consulate.consulTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.tgsMuted)
                    .fixedSize(horizontal: false, vertical: true)

                // Show a subtle hint when name isn't filled in yet so the
                // card still reads as "this is the consul" rather than empty.
                if consulate.consulName == nil {
                    Text("(yakında güncellenecek)")
                        .font(.caption2)
                        .foregroundStyle(Color.tgsBorder)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.tgsBorder.opacity(0.7), lineWidth: 0.5)
        )
    }

    private var consulAvatar: some View {
        Group {
            if let urlStr = consulate.consulPhotoURL,
               let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.tgsRed.opacity(0.18), lineWidth: 1.5))
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Color.tgsRed.opacity(0.08)
            Image(systemName: "person.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.tgsRed.opacity(0.55))
        }
    }
}

// MARK: - Reusable tappable row for the consulate detail page

private struct ConsulateInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let accent: Color
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(accent.opacity(0.10))
                            .frame(width: 34, height: 34)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(Color.tgsMuted)
                        Text(value)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.tgsCharcoal)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.tgsBorder)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if !isLast {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Sosyal Yardım Hattı (Social Aid Hotline) Card

/// Featured card at the top of Bilgi tab. The TGS-ITT social-aid hotline
/// — lawyers, healthcare workers, educators who listen to community
/// problems and route callers to the right authorities.
struct SocialAidHotlineCard: View {
    private let phone = "+41445932424"
    private let phoneDisplay = "+41 44 593 24 24"

    var body: some View {
        Button(action: call) {
            ZStack(alignment: .bottomTrailing) {
                // Background gradient + decorative star
                LinearGradient(
                    colors: [Color.tgsRed, Color(red: 0.55, green: 0.07, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative star in the corner (subtle, like the original poster)
                Image(systemName: "star.fill")
                    .font(.system(size: 180))
                    .foregroundStyle(.white.opacity(0.06))
                    .offset(x: 50, y: 30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .top, spacing: TGSSpacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SOSYAL YARDIM HATTI")
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Tüm sosyal sorunlarınızda yanınızdayız")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: "headphones")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    // Description
                    Text("Hukukçu, sağlıkçı ve eğitimcilerimiz sorunlarınızı dinleyip doğru mercilere yönlendiriyor.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                        .padding(.bottom, 14)

                    // Phone CTA chip
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(phoneDisplay)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Spacer(minLength: 0)
                        Text("Bize ulaşın")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.6)
                            .opacity(0.7)
                    }
                    .foregroundStyle(Color.tgsRed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white)
                    )
                    .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 4)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: TGSRadius.card, style: .continuous))
            .shadow(color: Color.tgsRed.opacity(0.30), radius: 14, x: 0, y: 6)
            .padding(.horizontal, TGSSpacing.md)
        }
        .buttonStyle(TGSSpringButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sosyal Yardım Hattı'nı ara: \(phoneDisplay)")
    }

    private func call() {
        if let url = URL(string: "tel://\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Socials Row

/// Horizontal row of platform chips at the bottom of the Bilgi tab.
/// Each tile is tappable and opens the respective URL in the default
/// browser / mail app.
struct SocialsRow: View {
    private struct Social {
        let label: String
        let systemIcon: String?       // SF Symbol fallback
        let url: String
        let tint: Color
    }

    private let items: [Social] = [
        .init(label: "Facebook",  systemIcon: "f.square.fill",       url: "https://www.facebook.com/itt.tgs",                 tint: Color(red: 0.10, green: 0.36, blue: 0.78)),
        .init(label: "X",         systemIcon: "xmark",                url: "https://x.com/isvicreturkitt",                     tint: Color.black),
        .init(label: "Instagram", systemIcon: "camera.fill",          url: "https://www.instagram.com/isvicreturktoplumu_itt/", tint: Color(red: 0.78, green: 0.16, blue: 0.50)),
        .init(label: "Web",       systemIcon: "globe",                url: "https://tgs-itt.ch/",                              tint: Color.tgsRed),
        .init(label: "E-posta",   systemIcon: "envelope.fill",        url: "mailto:info@tgs-itt.ch",                           tint: Color.tgsCharcoal),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.label) { item in
                socialChip(item)
            }
        }
        .padding(.horizontal, TGSSpacing.md)
    }

    private func socialChip(_ item: Social) -> some View {
        Button {
            if let url = URL(string: item.url) {
                UIApplication.shared.open(url)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(item.tint.opacity(0.12))
                        .frame(height: 56)
                    Image(systemName: item.systemIcon ?? "link")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(item.tint)
                }
                Text(item.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.tgsCharcoal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TGSSpringButtonStyle())
        .accessibilityLabel("\(item.label) sayfasını aç")
    }
}

// MARK: - Markdown Renderer
//
// Renders headings (# ## ###), bullet lists (-), and inline **bold** / *italic*.
// SwiftUI's Text(_:markdown:) only does inline markdown, so we parse blocks ourselves
// and apply per-block fonts.

private enum MarkdownBlockKind {
    case h1, h2, h3, paragraph, listItem, blank
}

private struct MarkdownBlock: Identifiable {
    let id = UUID()
    let kind: MarkdownBlockKind
    let text: String
}

struct MarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(parseBlocks()) { block in
                row(for: block)
            }
        }
    }

    @ViewBuilder
    private func row(for block: MarkdownBlock) -> some View {
        switch block.kind {
        case .h1:
            inlineText(block.text)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tgsCharcoal)
                .padding(.top, 6)
                .padding(.bottom, 2)
        case .h2:
            inlineText(block.text)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.tgsRed)
                .padding(.top, 10)
                .padding(.bottom, 2)
        case .h3:
            inlineText(block.text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.tgsCharcoal)
                .padding(.top, 4)
        case .paragraph:
            inlineText(block.text)
                .font(.body)
                .foregroundStyle(Color.tgsCharcoal)
                .fixedSize(horizontal: false, vertical: true)
        case .listItem:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.tgsRed)
                inlineText(block.text)
                    .font(.body)
                    .foregroundStyle(Color.tgsCharcoal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .blank:
            Color.clear.frame(height: 2)
        }
    }

    private func inlineText(_ s: String) -> Text {
        if let attr = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(s)
    }

    private func parseBlocks() -> [MarkdownBlock] {
        markdown.components(separatedBy: "\n").map { line -> MarkdownBlock in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                return MarkdownBlock(kind: .blank, text: "")
            } else if trimmed.hasPrefix("### ") {
                return MarkdownBlock(kind: .h3, text: String(trimmed.dropFirst(4)))
            } else if trimmed.hasPrefix("## ") {
                return MarkdownBlock(kind: .h2, text: String(trimmed.dropFirst(3)))
            } else if trimmed.hasPrefix("# ") {
                return MarkdownBlock(kind: .h1, text: String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("- ") {
                return MarkdownBlock(kind: .listItem, text: String(trimmed.dropFirst(2)))
            } else {
                return MarkdownBlock(kind: .paragraph, text: trimmed)
            }
        }
    }
}

// MARK: - Donation page
//
// Surfaced from Bilgi → Rehber → "Bağış / Destekleyin". Static content for
// now — bank details live here so they don't require a backend deploy to
// edit; rotate the IBAN, TWINT, etc. by changing the constants below.

struct DonationView: View {
    // TGS-ITT donation account. The IBAN clearing 04835 historically belongs
    // to Credit Suisse Schweiz AG, which merged into UBS in 2023 — the IBAN
    // keeps routing correctly through UBS's systems. Update bankName if the
    // account migrates to a different institution.
    private let bankName = "UBS Switzerland AG"
    private let bankNote = "Önceki adı: Credit Suisse Schweiz AG"
    private let accountHolder = "Türkische Gemeinschaft Schweiz / İsviçre Türk Toplumu"
    private let accountAddress = "8953 Dietikon"
    private let iban = "CH60 0483 5016 0284 9100 2"
    /// Optional — only used for international (non-CH) transfers. Standard
    /// UBS Switzerland AG BIC after the CS merger.
    private let bic: String? = "UBSWCHZH80A"
    /// Optional — set to a phone/handle when TWINT is enabled. Hides the
    /// whole TWINT card when nil.
    private let twintPhone: String? = nil
    private let contactEmail = "info@tgs-itt.ch"

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                whyCard
                bankCard
                if twintPhone != nil { twintCard }
                contactRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.tgsCream)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .navigationTitle("Bağış")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Hero

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.12))
                    .frame(width: 84, height: 84)
                Image(systemName: "heart.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }
            Text("TGS-ITT'yi Destekleyin")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.tgsCharcoal)
                .multilineTextAlignment(.center)
            Text("Bağışlarınız İsviçre'deki Türk toplumuna sunduğumuz ücretsiz hizmetleri sürdürmemize yardımcı olur.")
                .font(.system(size: 14))
                .foregroundStyle(Color.tgsMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.top, 8)
    }

    // MARK: – Why-donate card

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Bağışlar nereye gidiyor?")
            VStack(alignment: .leading, spacing: 10) {
                whyRow(icon: "graduationcap.fill", text: "Öğrenci bursları ve eğitim destek programları")
                whyRow(icon: "phone.bubble.fill", text: "Sosyal Yardım Hattı'nın işletim giderleri")
                whyRow(icon: "calendar", text: "TGS-ITT etkinlikleri ve topluluk buluşmaları")
                whyRow(icon: "iphone", text: "İTT Rehber uygulamasının bakımı ve geliştirilmesi")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.tgsBorder.opacity(0.7), lineWidth: 0.5)
        )
    }

    private func whyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.tgsRed)
                .frame(width: 22, alignment: .center)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.tgsCharcoal)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: – Bank transfer card

    private var bankCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Banka Havalesi")
            VStack(spacing: 0) {
                copyRow(label: "Banka", value: bankName, footnote: bankNote, isLast: false)
                copyRow(label: "Hesap sahibi", value: accountHolder, footnote: accountAddress, isLast: false)
                copyRow(label: "IBAN", value: iban, isLast: bic == nil, mono: true)
                if let bic {
                    copyRow(label: "BIC / SWIFT", value: bic, footnote: "Sadece uluslararası havaleler için gerekli", isLast: true, mono: true)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.tgsBorder.opacity(0.7), lineWidth: 0.5)
            )
            Text("Herhangi bir satıra dokunarak değeri panoya kopyalayabilirsiniz.")
                .font(.caption)
                .foregroundStyle(Color.tgsMuted)
                .padding(.horizontal, 4)
        }
    }

    @State private var copiedField: String? = nil

    private func copyRow(label: String, value: String, footnote: String? = nil, isLast: Bool, mono: Bool = false) -> some View {
        Button {
            UIPasteboard.general.string = value
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                copiedField = label
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation { copiedField = nil }
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(Color.tgsMuted)
                        Text(value)
                            .font(mono ? .system(size: 14, weight: .semibold, design: .monospaced) : .system(size: 14, weight: .medium))
                            .foregroundStyle(Color.tgsCharcoal)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                        if let footnote, !footnote.isEmpty {
                            Text(footnote)
                                .font(.caption2)
                                .foregroundStyle(Color.tgsMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    if copiedField == label {
                        Label("Kopyalandı", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.tgsSuccess)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    } else {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.tgsRed)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                if !isLast {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label): \(value). Dokunarak kopyala.")
    }

    // MARK: – TWINT

    private var twintCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("TWINT")
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.02, green: 0.20, blue: 0.50))
                        .frame(width: 44, height: 44)
                    Text("TWINT")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(twintPhone ?? "")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.tgsCharcoal)
                    Text("TWINT uygulamasında bu numarayı kullanarak bağış yapabilirsiniz")
                        .font(.caption)
                        .foregroundStyle(Color.tgsMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.tgsBorder.opacity(0.7), lineWidth: 0.5)
            )
        }
    }

    // MARK: – Contact

    private var contactRow: some View {
        Button {
            if let url = URL(string: "mailto:\(contactEmail)?subject=Bağış%20hakkında") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Sorularınız için: \(contactEmail)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color.tgsRed, Color.tgsHeroGradientEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.tgsRed.opacity(0.25), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.tgsMuted)
            .textCase(.uppercase)
            .tracking(0.4)
            .padding(.leading, 4)
    }
}
