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

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = listing.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty: Color(.systemGray5)
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: Image(systemName: "photo").foregroundStyle(.secondary)
                    @unknown default: Color(.systemGray5)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "person.crop.square").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.name).font(.headline)
                let meta = ([listing.category] + listing.kantons).compactMap { $0 }.joined(separator: " • ")
                if !meta.isEmpty {
                    Text(meta).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("Çevrimdışı veri gösteriliyor")
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.yellow.opacity(0.18))
    }
}

struct EmptyStateView: View {
    let onClearFilters: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Aradığınız kriterlere uygun veri bulunamadı")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Filtreleri temizle", action: onClearFilters)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct SubmitGateView: View {
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Önce giriş yapın")
                .font(.title3.bold())
            Text("Hizmet eklemek için Profil sekmesinden hesap oluşturun veya giriş yapın.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Kapat", action: onClose).padding(.top, 8)
        }
        .padding()
        .navigationTitle("Hizmetinizi Ekleyin")
        .navigationBarTitleDisplayMode(.inline)
    }
}
