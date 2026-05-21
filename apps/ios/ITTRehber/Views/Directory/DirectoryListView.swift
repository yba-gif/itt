import SwiftUI

struct DirectoryListView: View {
    let directory: Directory

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var cache: OfflineCache

    /// Set during onboarding (Kanton.code or "" for all). Used as initial filter
    /// when entering a directory view for the first time in a session.
    @AppStorage("preferredKanton") private var preferredKanton = ""

    @State private var listings: [Listing] = []
    @State private var totalCount: Int = 0
    @State private var query: String = ""
    @State private var selectedKanton: String = ""
    @State private var loading: Bool = false
    @State private var error: APIError?
    @State private var isOffline: Bool = false
    @State private var showSubmit: Bool = false
    @State private var didInitialKantonSetup = false
    @Namespace private var rowNS

    var body: some View {
        VStack(spacing: 0) {
            FilterBar(query: $query, selectedKanton: $selectedKanton, onChange: { Task { await reload() } })

            if isOffline {
                OfflineBanner()
            }

            if loading && listings.isEmpty {
                // P2-1: skeleton rows while first load is in flight
                List {
                    ForEach(0..<6, id: \.self) { _ in
                        ListingRowSkeleton()
                            .listRowBackground(Color.white)
                            .listRowSeparatorTint(Color.tgsBorder)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.tgsCream)
                .allowsHitTesting(false)
            } else if let err = error, listings.isEmpty {
                // P2-5: inline error state replaces modal alert when list is empty
                ErrorStateView(message: err.errorDescription ?? "Bir hata oluştu") {
                    error = nil; Task { await reload() }
                }
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
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
        // P2-5: show alert only when list already has content (inline state handles empty case)
        .alert("Hata", isPresented: .constant(error != nil && !listings.isEmpty)) {
            Button("Tekrar Dene") { error = nil; Task { await reload() } }
            Button("Kapat", role: .cancel) { error = nil }
        } message: { Text(error?.errorDescription ?? "") }
        .task { await initialLoad() }
    }

    private var listingList: some View {
        List {
            Section {
                ForEach(listings) { listing in
                    NavigationLink(
                        destination: DirectoryDetailView(listing: listing)
                            .zoomNavTransition(sourceID: listing.id, in: rowNS)
                    ) {
                        ListingRow(listing: listing)
                            .zoomSource(id: listing.id, in: rowNS)
                    }
                    .listRowBackground(Color.white)
                    .listRowSeparatorTint(Color.tgsBorder)
                }
            } header: {
                Text("\(totalCount) \(directory.resultLabel) bulundu")
                    .font(TGSFont.caption)
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
        // First entry to this view in the session: seed the kanton filter with
        // the user's onboarding choice (if any). User can clear it via FilterBar.
        if !didInitialKantonSetup {
            didInitialKantonSetup = true
            if selectedKanton.isEmpty && !preferredKanton.isEmpty {
                selectedKanton = preferredKanton
            }
        }
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
    @State private var appeared = false

    private var initials: String {
        listing.name
            .components(separatedBy: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0) } }
            .joined()
            .uppercased()
    }

    /// Primary directory for color tinting the image fallback.
    /// Falls back to .isletme color if no recognized directory present.
    private var primaryDirectory: Directory {
        for code in listing.directories {
            if let d = Directory(rawValue: code) { return d }
        }
        return .isletme
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
            .clipShape(RoundedRectangle(cornerRadius: TGSRadius.field, style: .continuous))
            .accessibilityHidden(true) // decorative — row label covers this

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.name)
                    .font(TGSFont.rowTitle)
                    .foregroundStyle(Color.tgsCharcoal)
                    .lineLimit(1)

                if let category = listing.category, !category.isEmpty {
                    Text(category)
                        .font(TGSFont.micro)
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
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 20)
        .animation(.spring(response: 0.38, dampingFraction: 0.80), value: appeared)
        .onAppear { appeared = true }
        // P1-4: synthesise a single VoiceOver label from all visible text
        .accessibilityElement(children: .combine)
    }

    /// Color-tinted image fallback when listing has no `image_url`.
    /// Tints the background with the primary directory's color (12% opacity)
    /// and renders initials in the directory color for brand consistency.
    /// Falls back to the SF Symbol icon if the name has no extractable initials.
    private var initialsPlaceholder: some View {
        ZStack {
            primaryDirectory.color.opacity(0.12)
            if initials.isEmpty {
                Image(systemName: primaryDirectory.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(primaryDirectory.color)
            } else {
                Text(initials)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryDirectory.color)
            }
        }
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
            Text("Çevrimdışı — son önbellek gösteriliyor")
                .font(.caption.weight(.medium))
            Spacer()
        }
        // QW-6: use DesignSystem amber tokens instead of hardcoded colours
        .foregroundStyle(Color.tgsAmber)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.tgsAmberBg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Çevrimdışı — son önbellek gösteriliyor")
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
            .accessibilityLabel("Filtreleri temizle")
            .accessibilityHint("Arama ve kanton filtrelerini sıfırlar")
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
