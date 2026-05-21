import SwiftUI
import MapKit

struct DirectoryDetailView: View {
    let listing: Listing
    @EnvironmentObject var session: SessionStore
    @State private var isFavorite: Bool = false
    @State private var favError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                actionsRow
                details

                if let description = listing.description, !description.isEmpty {
                    descriptionSection(description)
                }

                if session.isAuthenticated {
                    Button {
                        Task { await toggleFavorite() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 15, weight: .semibold))
                            Text(isFavorite ? "Favorilerden çıkar" : "Favorilere ekle")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(
                            isFavorite
                                ? Color(red: 0.80, green: 0.55, blue: 0.0)
                                : Color.tgsMuted
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    isFavorite
                                        ? Color(red: 1.0, green: 0.88, blue: 0.40).opacity(0.20)
                                        : Color.tgsSurface
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.tgsBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("Son güncelleme: \(formatted(listing.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(Color.tgsMuted)
                    .padding(.top, 2)
            }
            .padding(16)
        }
        .background(Color.tgsCream)
        .navigationTitle(listing.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: shareURL) { Image(systemName: "square.and.arrow.up") }
            }
        }
        .alert("Hata", isPresented: .constant(favError != nil)) {
            Button("Tekrar Dene") { favError = nil; Task { await checkFavorite() } }
            Button("Kapat", role: .cancel) { favError = nil }
        } message: { Text(favError ?? "") }
        .task { await checkFavorite() }
    }

    private func checkFavorite() async {
        guard session.isAuthenticated else { return }
        do {
            let favs = try await APIClient.shared.favorites()
            isFavorite = favs.contains(where: { $0.id == listing.id })
        } catch { /* offline ok */ }
    }

    private func toggleFavorite() async {
        do {
            if isFavorite {
                try await APIClient.shared.removeFavorite(listingId: listing.id)
                isFavorite = false
            } else {
                try await APIClient.shared.addFavorite(listingId: listing.id)
                isFavorite = true
            }
        } catch let api as APIError {
            favError = api.errorDescription
        } catch {
            favError = error.localizedDescription
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageURL = listing.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Color.tgsSurface
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.tgsMuted)
                            )
                    }
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityLabel("\(listing.name) görseli")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(listing.name)
                    .font(.title2.bold())
                    .foregroundStyle(Color.tgsCharcoal)

                HStack(spacing: 8) {
                    if let category = listing.category, !category.isEmpty {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.tgsRed)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.tgsRed.opacity(0.10)))
                    }
                    if !listing.kantons.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.tgsMuted)
                            Text(listing.kantons.prefix(3).joined(separator: " · "))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.tgsMuted)
                        }
                    }
                }
            }
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 10) {
            if let phone = listing.phone,
               let url = URL(string: "tel://\(phone.filter { !$0.isWhitespace })") {
                ActionButton(icon: "phone.fill", label: "Ara",
                             a11yLabel: "\(listing.name) ara: \(phone)",
                             color: Color(red: 0.13, green: 0.65, blue: 0.37)) {
                    UIApplication.shared.open(url)
                }
            }
            if let email = listing.email, let url = URL(string: "mailto:\(email)") {
                ActionButton(icon: "envelope.fill", label: "E-posta",
                             a11yLabel: "\(listing.name) e-posta gönder",
                             color: Color.tgsRed) {
                    UIApplication.shared.open(url)
                }
            }
            if listing.address != nil {
                ActionButton(icon: "map.fill", label: "Harita",
                             a11yLabel: "Haritada aç",
                             color: Color(red: 0.95, green: 0.40, blue: 0.05)) {
                    openInMaps()
                }
            }
            if let website = listing.website, let url = URL(string: website) {
                ActionButton(icon: "safari.fill", label: "Web",
                             a11yLabel: "Web sitesini aç",
                             color: Color(red: 0.02, green: 0.50, blue: 0.65)) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let address = listing.address {
                DetailRow(icon: "mappin.and.ellipse", label: "Adres", value: address)
                Divider().padding(.leading, 44).overlay(Color.tgsBorder)
            }
            if let phone = listing.phone {
                DetailRow(icon: "phone", label: "Telefon", value: phone)
                if listing.email != nil || listing.website != nil {
                    Divider().padding(.leading, 44).overlay(Color.tgsBorder)
                }
            }
            if let email = listing.email {
                DetailRow(icon: "envelope", label: "E-posta", value: email)
                if listing.website != nil {
                    Divider().padding(.leading, 44).overlay(Color.tgsBorder)
                }
            }
            if let website = listing.website {
                DetailRow(icon: "globe", label: "Web", value: website)
            }
        }
        .padding(.vertical, 4)
        .tgsInnerCard()
    }

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hakkında")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.tgsMuted)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(Color.tgsCharcoal)
                .lineSpacing(5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tgsInnerCard()
    }

    private func openInMaps() {
        guard let address = listing.address else { return }
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, _ in
            if let placemark = placemarks?.first, let location = placemark.location {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                mapItem.name = listing.name
                mapItem.openInMaps()
            } else {
                let escaped = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
                if let url = URL(string: "https://maps.apple.com/?q=\(escaped)") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var shareURL: URL {
        URL(string: "https://itt-rehber.ch/listing/\(listing.id.uuidString)")
            ?? URL(string: "https://itt-rehber.ch")!
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_CH")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    var a11yLabel: String = ""
    var color: Color = Color.tgsRed
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.tgsBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11yLabel.isEmpty ? label : a11yLabel)
    }
}

struct DetailRow: View {
    var icon: String = ""
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.tgsMuted)
                    .frame(width: 20, alignment: .center)
                    .padding(.top, 1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.tgsMuted)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color.tgsCharcoal)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
