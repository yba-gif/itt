import SwiftUI

struct DirectoryListView: View {
    let directory: Directory

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var cache: OfflineCache

    @State private var listings: [Listing] = []
    @State private var totalCount: Int = 0
    @State private var query: String = ""
    @State private var selectedKanton: String = ""
    @State private var loading: Bool = false
    @State private var error: APIError?
    @State private var isOffline: Bool = false
    @State private var showSubmit: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            FilterBar(query: $query, selectedKanton: $selectedKanton, onChange: { Task { await reload() } })

            if isOffline {
                OfflineBanner()
            }

            if loading && listings.isEmpty {
                ProgressView("Yükleniyor…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if listings.isEmpty {
                EmptyStateView(onClearFilters: {
                    query = ""
                    selectedKanton = ""
                    Task { await reload() }
                })
            } else {
                listingList
            }
        }
        .navigationTitle(directory.titleTR)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSubmit = true
                } label: {
                    Label("Hizmetinizi Ekleyin", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showSubmit) {
            NavigationStack {
                if session.isAuthenticated {
                    SubmitListingView(directory: directory, onSubmitted: {
                        showSubmit = false
                        Task { await reload() }
                    })
                } else {
                    SubmitGateView(onClose: { showSubmit = false })
                }
            }
        }
        .alert("Hata", isPresented: .constant(error != nil)) {
            Button("Tamam") { error = nil }
        } message: { Text(error?.errorDescription ?? "") }
        .task { await initialLoad() }
    }

    private var listingList: some View {
        List {
            Section {
                ForEach(listings) { listing in
                    NavigationLink(destination: DirectoryDetailView(listing: listing)) {
                        ListingRow(listing: listing)
                    }
                }
            } header: {
                Text("\(totalCount) uzman bulundu")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .refreshable { await reload() }
    }

    private func initialLoad() async {
        // Hydrate from cache so the list paints immediately.
        let cached = cache.cachedListings(for: directory)
        if !cached.isEmpty && listings.isEmpty {
            listings = cached
            totalCount = cached.count
        }
        await reload()
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        do {
            let page = try await APIClient.shared.listings(
                directory: directory,
                kanton: selectedKanton.isEmpty ? nil : selectedKanton,
                query: query.isEmpty ? nil : query
            )
            listings = page.items
            totalCount = page.total
            isOffline = false
            cache.saveListings(page.items, for: directory)
        } catch let api as APIError {
            error = api
            isOffline = true
            listings = cache.cachedListings(for: directory)
        } catch {
            self.error = .http(0, error.localizedDescription)
            isOffline = true
            listings = cache.cachedListings(for: directory)
        }
    }
}

struct ListingRow: View {
    let listing: Listing

    private var initials: String {
        listing.name
            .components(separatedBy: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0) } }
            .joined()
            .uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Logo / avatar
            ZStack {
                if let urlString = listing.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            initialsPlaceholder
                        }
                    }
                } else {
                    initialsPlaceholder
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Text
            VStack(alignment: .leading, spacing: 5) {
                Text(listing.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let category = listing.category, !category.isEmpty {
                    Text(category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !listing.kantons.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(listing.kantons.prefix(3).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var initialsPlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(.systemGray2))
        }
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption.weight(.semibold))
            Text("Çevrimdışı — son önbellek gösteriliyor")
                .font(.caption.weight(.medium))
            Spacer()
        }
        .foregroundStyle(Color(red: 0.55, green: 0.42, blue: 0.0))
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color(red: 1.0, green: 0.92, blue: 0.60))
    }
}

struct EmptyStateView: View {
    let onClearFilters: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 80, height: 80)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(.systemGray3))
            }
            VStack(spacing: 6) {
                Text("Sonuç bulunamadı")
                    .font(.headline)
                Text("Farklı anahtar kelimeler veya kanton deneyin.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button(action: onClearFilters) {
                Text("Filtreleri temizle")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color(.systemGray5)))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct SubmitGateView: View {
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 88, height: 88)
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 8) {
                Text("Önce giriş yapın")
                    .font(.title3.bold())
                Text("Hizmet eklemek için Profil sekmesinden hesap oluşturun veya giriş yapın.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button("Kapat", action: onClose)
                .font(.subheadline.weight(.semibold))
                .padding(.top, 4)
        }
        .padding(24)
        .navigationTitle("Hizmetinizi Ekleyin")
        .navigationBarTitleDisplayMode(.inline)
    }
}
