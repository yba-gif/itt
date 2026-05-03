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
                        Label(
                            isFavorite ? "Favorilerden çıkar" : "Favorilere ekle",
                            systemImage: isFavorite ? "star.fill" : "star"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }

                Text("Son güncelleme: \(formatted(listing.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .navigationTitle(listing.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: shareURL) { Image(systemName: "square.and.arrow.up") }
            }
        }
        .alert("Hata", isPresented: .constant(favError != nil)) {
            Button("Tamam") { favError = nil }
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
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = listing.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty: Color(.systemGray5)
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: Color(.systemGray5)
                    @unknown default: Color(.systemGray5)
                    }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text(listing.name).font(.title2.bold())
            let meta = ([listing.category] + listing.kantons).compactMap { $0 }.joined(separator: " • ")
            if !meta.isEmpty {
                Text(meta).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            if let phone = listing.phone, let url = URL(string: "tel://\(phone.filter { !$0.isWhitespace })") {
                ActionButton(icon: "phone.fill", label: "Ara") { UIApplication.shared.open(url) }
            }
            if let email = listing.email, let url = URL(string: "mailto:\(email)") {
                ActionButton(icon: "envelope.fill", label: "E-posta") { UIApplication.shared.open(url) }
            }
            if listing.address != nil {
                ActionButton(icon: "map.fill", label: "Harita") { openInMaps() }
            }
            if let website = listing.website, let url = URL(string: website) {
                ActionButton(icon: "safari.fill", label: "Web") { UIApplication.shared.open(url) }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let address = listing.address {
                DetailRow(label: "Adres", value: address)
            }
            if let phone = listing.phone {
                DetailRow(label: "Telefon", value: phone)
            }
            if let email = listing.email {
                DetailRow(label: "E-posta", value: email)
            }
            if let website = listing.website {
                DetailRow(label: "Web", value: website)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hakkında").font(.headline)
            Text(description).font(.body)
        }
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
        URL(string: "https://itt-rehber.ch/listing/\(listing.id.uuidString)") ?? URL(string: "https://itt-rehber.ch")!
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
