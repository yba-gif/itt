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
                    .background(Color.tgsCream)
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
        .background(Color.tgsCream)
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
            Button("Tekrar Dene") { error = nil; Task { await reload() } }
            Button("Kapat", role: .cancel) { error = nil }
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
                    .listRowBackground(Color.white)
                    .listRowSeparatorTint(Color.tgsBorder)
                }
            } header: {
                Text("\(totalCount) uzman bulundu")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.tgsMuted)
                    .textCase(nil)
                    .padding(.leading, 4)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.tgsCream)
        .refreshable { await reload() }
    }

    private func initialLoad() async {
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
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.tgsCharcoal)
                    .lineLimit(1)

                if let category = listing.category, !category.isEmpty {
                    Text(category)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.tgsRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.tgsRed.opacity(0.10)))
                        .lineLimit(1)
                }

                if !listing.kantons.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.tgsMuted)
                        Text(listing.kantons.prefix(3).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(Color.tgsMuted)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private var initialsPlaceholder: some View {
        ZStack {
            Color.tgsSurface
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.tgsMuted)
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
        // QW-6: use DesignSystem amber tokens instead of hardcoded colours
        .foregroundStyle(Color.tgsAmber)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.tgsAmberBg)
    }
}

struct EmptyStateView: View {
    let onClearFilters: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.tgsSurface)
                    .frame(width: 80, height: 80)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.tgsMuted)
            }
            VStack(spacing: 6) {
                Text("Sonuç bulunamadı")
                    .font(.headline)
                    .foregroundStyle(Color.tgsCharcoal)
                Text("Farklı anahtar kelimeler veya kanton deneyin.")
                    .font(.subheadline)
                    .foregroundStyle(Color.tgsMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button(action: onClearFilters) {
                Text("Filtreleri temizle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.tgsCharcoal)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.tgsSurface)
                            .overlay(Capsule().stroke(Color.tgsBorder, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tgsCream)
    }
}

struct SubmitGateView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 88, height: 88)
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.tgsRed)
            }
            VStack(spacing: 8) {
                Text("Önce giriş yapın")
                    .font(.title3.bold())
                    .foregroundStyle(Color.tgsCharcoal)
                Text("Hizmet eklemek için Profil sekmesinden hesap oluşturun veya giriş yapın.")
                    .font(.subheadline)
                    .foregroundStyle(Color.tgsMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button("Kapat", action: onClose)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.tgsRed)
                .padding(.top, 4)
        }
        .padding(24)
        .navigationTitle("Hizmetinizi Ekleyin")
        .navigationBarTitleDisplayMode(.inline)
    }
}
