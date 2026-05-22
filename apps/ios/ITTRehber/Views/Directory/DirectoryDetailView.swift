import SwiftUI
import MapKit

struct DirectoryDetailView: View {
    let listing: Listing
    @EnvironmentObject var session: SessionStore
    @State private var isFavorite = false
    @State private var favError: String?
    @State private var showFavToast = false
    @State private var favToastMessage = ""
    @State private var cardAppeared = false

    // Per-directory accent colour from the listing's first directory
    private var accent: Color {
        guard let raw = listing.directories.first,
              let dir = Directory(rawValue: raw) else { return Color.tgsRed }
        return dir.color
    }
    private var accentIcon: String {
        guard let raw = listing.directories.first,
              let dir = Directory(rawValue: raw) else { return "star.fill" }
        return dir.systemImage
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                contentCard
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.white)
        // NavigationStack push doesn't inherit the parent tab's safeAreaInset
        // for the floating tab bar — apply locally so the bottom of the
        // content card clears the tab bar.
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    if session.isAuthenticated {
                        Button { Task { await toggleFavorite() } } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isFavorite ? Color.red : .white)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.black.opacity(0.28)))
                        }
                        .buttonStyle(.plain)
                        .tgsBounce(value: isFavorite)
                        .accessibilityLabel(isFavorite ? "Favorilerden çıkar" : "Favorilere ekle")
                    }
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.black.opacity(0.28)))
                    }
                }
            }
        }
        .alert("Hata", isPresented: .constant(favError != nil)) {
            Button("Tamam", role: .cancel) { favError = nil }
        } message: { Text(favError ?? "") }
        .overlay(toastOverlay, alignment: .bottom)
        .task { await checkFavorite() }
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                cardAppeared = true
            }
        }
    }

    // MARK: – Hero (full-bleed, behind nav bar)

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Image or colour gradient fallback. .scaledToFill() can render
            // wider than the parent if the parent doesn't have an explicit
            // width — that's what was pushing the whole detail page past the
            // screen edge. Constraining maxWidth + clipping locally fixes it.
            heroBackground
                .frame(maxWidth: .infinity, maxHeight: 310)
                .clipped()

            // Gradient for text legibility
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .init(x: 0.5, y: 0.3),
                endPoint: .bottom
            )

            // Metadata overlaid on image
            VStack(alignment: .leading, spacing: 6) {
                if let cat = listing.category, !cat.isEmpty {
                    Text(cat)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(accent))
                }

                Text(listing.name)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !listing.kantons.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                        Text(listing.kantons.joined(separator: " · "))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 44) // extra breathing room for card overlap
        }
        // Constrain the whole hero to parent width — prevents a wide source
        // image from forcing the entire detail screen past the screen edge.
        .frame(maxWidth: .infinity, maxHeight: 310)
        .clipped()
    }

    @ViewBuilder
    private var heroBackground: some View {
        if let urlStr = listing.imageURL, let url = URL(string: urlStr) {
            // GeometryReader gives us the available width so .scaledToFill()
            // never renders larger than the parent's actual size — fixes wide
            // logos (e.g. Cennet Consulting banner) overflowing the screen.
            GeometryReader { proxy in
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    default:
                        colorFallback
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        } else {
            colorFallback
        }
    }

    private var colorFallback: some View {
        ZStack {
            LinearGradient(
                colors: [accent, accent.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(GrainOverlay())

            Image(systemName: accentIcon)
                .font(.system(size: 90, weight: .thin))
                .foregroundStyle(.white.opacity(0.18))
        }
    }

    // MARK: – White card (slides over hero)

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            primaryCTA
            if hasSecondary { secondaryActions }
            if hasContact { contactSection }
            if let desc = listing.description, !desc.isEmpty { descriptionSection(desc) }

        }
        .padding(.bottom, 32)
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? -24 : 2)   // settles upward into its overlap position
        .padding(.bottom, -24)
    }

    // MARK: – Primary CTA (full-width, accent colour)

    @ViewBuilder
    private var primaryCTA: some View {
        if let phone = listing.phone,
           let url = URL(string: "tel://\(phone.filter { !$0.isWhitespace })") {
            Button { UIApplication.shared.open(url) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Hemen Ara")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    Text(phone)
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.78)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent)
                        .shadow(color: accent.opacity(0.40), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(TGSSpringButtonStyle())
        } else if let website = listing.website, let url = URL(string: website) {
            Button { UIApplication.shared.open(url) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Web Sitesini Aç")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .opacity(0.78)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent)
                        .shadow(color: accent.opacity(0.40), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(TGSSpringButtonStyle())
        }
    }

    // MARK: – Secondary actions (pills)

    private var hasSecondary: Bool {
        (listing.email != nil) || (listing.address != nil) ||
        (listing.website != nil && listing.phone != nil)
    }

    private var secondaryActions: some View {
        HStack(spacing: 10) {
            if let email = listing.email, let url = URL(string: "mailto:\(email)") {
                PillButton(icon: "envelope.fill", label: "E-posta", accent: accent) {
                    UIApplication.shared.open(url)
                }
            }
            if listing.address != nil {
                PillButton(icon: "map.fill", label: "Harita", accent: accent) {
                    openInMaps()
                }
            }
            if let website = listing.website, let url = URL(string: website),
               listing.phone != nil {
                PillButton(icon: "safari.fill", label: "Web", accent: accent) {
                    UIApplication.shared.open(url)
                }
            }
            Spacer()
        }
    }

    // MARK: – Contact info section

    private var hasContact: Bool {
        listing.address != nil || listing.phone != nil ||
        listing.email != nil || listing.website != nil
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow("İletişim Bilgileri")

            VStack(spacing: 0) {
                if let address = listing.address {
                    ContactRow(icon: "mappin.and.ellipse", label: "Adres",
                               value: address, accent: accent, isLast: listing.phone == nil && listing.email == nil && listing.website == nil)
                }
                if let phone = listing.phone {
                    ContactRow(icon: "phone.fill", label: "Telefon",
                               value: phone, accent: accent,
                               isLast: listing.email == nil && listing.website == nil) {
                        if let url = URL(string: "tel://\(phone.filter { !$0.isWhitespace })") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                if let email = listing.email {
                    ContactRow(icon: "envelope.fill", label: "E-posta",
                               value: email, accent: accent,
                               isLast: listing.website == nil) {
                        if let url = URL(string: "mailto:\(email)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                if let website = listing.website {
                    ContactRow(icon: "globe", label: "Web Sitesi",
                               value: website, accent: accent, isLast: true) {
                        if let url = URL(string: website) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.tgsBorder.opacity(0.7), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: – Description

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow("Hakkında")
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.tgsCharcoal)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.tgsCream.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.tgsBorder.opacity(0.6), lineWidth: 0.5)
                )
        }
    }

    // MARK: – Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if showFavToast {
            HStack(spacing: 8) {
                Image(systemName: isFavorite ? "heart.fill" : "heart.slash.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.80, green: 0.20, blue: 0.20))
                Text(favToastMessage)
                    .font(TGSFont.caption)
                    .foregroundStyle(Color.tgsCharcoal)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding(.bottom, 32)
        }
    }

    // MARK: – Helpers

    private func checkFavorite() async {
        guard session.isAuthenticated else { return }
        do {
            let favs = try await APIClient.shared.favorites()
            isFavorite = favs.contains(where: { $0.id == listing.id })
        } catch { /* offline ok */ }
    }

    private func toggleFavorite() async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do {
            if isFavorite {
                try await APIClient.shared.removeFavorite(listingId: listing.id)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { isFavorite = false }
                showToast("Favorilerden çıkarıldı")
            } else {
                try await APIClient.shared.addFavorite(listingId: listing.id)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { isFavorite = true }
                showToast("Favorilere eklendi")
            }
        } catch let api as APIError { favError = api.errorDescription
        } catch { favError = error.localizedDescription }
    }

    private func showToast(_ message: String) {
        favToastMessage = message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showFavToast = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.25)) { showFavToast = false }
        }
    }

    private func openInMaps() {
        guard let address = listing.address else { return }
        CLGeocoder().geocodeAddressString(address) { placemarks, _ in
            if let loc = placemarks?.first?.location {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: loc.coordinate))
                item.name = listing.name; item.openInMaps()
            } else {
                let q = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
                if let url = URL(string: "https://maps.apple.com/?q=\(q)") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var shareURL: URL {
        URL(string: "https://tgs-itt.ch/listing/\(listing.id.uuidString)")
            ?? URL(string: "https://tgs-itt.ch")!
    }

}


// MARK: - Section Eyebrow Label

private struct SectionEyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.tgsMuted)
            .tracking(1.1)
    }
}

// MARK: - Pill Action Button

struct PillButton: View {
    let icon: String
    let label: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(accent.opacity(0.10))
            )
            .overlay(Capsule().stroke(accent.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(TGSSpringButtonStyle())
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let icon: String
    let label: String
    let value: String
    let accent: Color
    var isLast: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 14) {
                // Icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(accent.opacity(0.11))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                }

                // Text
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.tgsMuted)
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.tgsCharcoal)
                        .lineLimit(2)
                }

                Spacer()

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.tgsMuted.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)

        if !isLast {
            Divider()
                .padding(.leading, 68)
                .overlay(Color.tgsBorder.opacity(0.6))
        }
    }
}

// MARK: - Legacy stubs (kept for backward compat with other files if any)

struct ActionButton: View {
    let icon: String; let label: String
    var a11yLabel: String = ""; var color: Color = Color.tgsRed
    let action: () -> Void
    var body: some View {
        PillButton(icon: icon, label: label, accent: color, action: action)
            .accessibilityLabel(a11yLabel.isEmpty ? label : a11yLabel)
    }
}

struct DetailRow: View {
    var icon: String = ""; let label: String; let value: String
    var body: some View {
        ContactRow(icon: icon, label: label, value: value, accent: Color.tgsRed)
    }
}
