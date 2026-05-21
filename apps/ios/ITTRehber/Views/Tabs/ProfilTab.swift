import SwiftUI

struct ProfilTab: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        NavigationStack {
            Group {
                if session.isAuthenticated {
                    ProfileLoggedInView()
                } else {
                    LoginView()
                }
            }
            .navigationTitle("Profil")
        }
    }
}

struct ProfileLoggedInView: View {
    @EnvironmentObject var session: SessionStore
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @State private var claimable: [Listing] = []

    var body: some View {
        List {
            Section {
                if let user = session.user {
                    LabeledContent("Ad", value: user.displayName ?? "—")
                    LabeledContent("E-posta", value: user.email)
                    if user.isAdmin {
                        LabeledContent("Rol", value: "Yönetici")
                    }
                }
            }

            if !claimable.isEmpty {
                Section {
                    NavigationLink {
                        ClaimableListingsView(claimable: $claimable)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.seal").foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text("v1 ilanlarınız hazır").font(.headline)
                                Text("\(claimable.count) ilan e-postanızla eşleşti")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Sahiplenebilecek ilanlar")
                } footer: {
                    Text("v1’den taşınan ilanlar arasında e-postanızla eşleşenleri sahiplenebilirsiniz.")
                }
            }

            Section {
                NavigationLink("Favorilerim") { FavoritesView() }
                // QW-10: SavedSearchesView hidden until AraTab has a "Save Search" button (Phase 2)
                NavigationLink("İlanlarım") { MyListingsView() }
            }

            Section {
                Button("Çıkış yap") { session.signOut() }
                    .foregroundStyle(.red)
            }

            Section {
                Button("Hesabımı Sil", role: .destructive) {
                    showDeleteConfirm = true
                }
            } footer: {
                Text("Hesabınızı silerseniz aktif ödemeli ilanlarınız ödendiği süre boyunca yayında kalır; sahiplik bilgileri anonimleştirilir.")
            }
        }
        .alert("Hesabı Sil", isPresented: $showDeleteConfirm) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sil", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("Hesabınız kalıcı olarak silinecek.")
        }
        .alert("Hata", isPresented: .constant(deleteError != nil)) {
            Button("Tekrar Dene", role: .destructive) { deleteError = nil; Task { await deleteAccount() } }
            Button("Kapat", role: .cancel) { deleteError = nil }
        } message: { Text(deleteError ?? "") }
        .task {
            do { claimable = try await APIClient.shared.claimableListings() }
            catch { /* offline OK */ }
        }
    }

    private func deleteAccount() async {
        do { try await session.deleteAccount() }
        catch { deleteError = error.localizedDescription }
    }
}

// MARK: - Claimable

struct ClaimableListingsView: View {
    @Binding var claimable: [Listing]
    @State private var busy: UUID?
    @State private var error: String?

    var body: some View {
        List {
            ForEach(claimable) { listing in
                VStack(alignment: .leading, spacing: 6) {
                    Text(listing.name).font(.headline)
                    let meta = ([listing.category] + listing.kantons).compactMap { $0 }.joined(separator: " • ")
                    if !meta.isEmpty {
                        Text(meta).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await claim(listing.id) }
                    } label: {
                        if busy == listing.id { ProgressView() } else { Text("Bu ilanı sahiplen") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy != nil)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Sahiplenebilecek")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Hata", isPresented: .constant(error != nil)) {
            Button("Tamam") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func claim(_ id: UUID) async {
        busy = id
        defer { busy = nil }
        do {
            _ = try await APIClient.shared.claimListing(id: id)
            claimable.removeAll(where: { $0.id == id })
        } catch let api as APIError {
            error = api.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Favorites

struct FavoritesView: View {
    @State private var favorites: [Listing] = []
    @State private var loading = false

    var body: some View {
        Group {
            if loading && favorites.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if favorites.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.tgsSurface).frame(width: 72, height: 72)
                        Image(systemName: "star")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.tgsMuted)
                    }
                    Text("Henüz favori yok")
                        .font(.headline)
                        .foregroundStyle(Color.tgsCharcoal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.tgsCream)
            } else {
                List {
                    ForEach(favorites) { listing in
                        NavigationLink(destination: DirectoryDetailView(listing: listing)) {
                            ListingRow(listing: listing)
                        }
                    }
                    .onDelete(perform: removeAt)
                }
            }
        }
        .navigationTitle("Favoriler")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do { favorites = try await APIClient.shared.favorites() }
        catch { /* keep last */ }
    }

    private func removeAt(_ offsets: IndexSet) {
        let toRemove = offsets.map { favorites[$0] }
        favorites.remove(atOffsets: offsets)
        Task {
            for f in toRemove {
                try? await APIClient.shared.removeFavorite(listingId: f.id)
            }
        }
    }
}

// MARK: - Saved searches

struct SavedSearchesView: View {
    @State private var rows: [SavedSearch] = []

    var body: some View {
        Group {
            if rows.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.tgsSurface).frame(width: 72, height: 72)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.tgsMuted)
                    }
                    Text("Kayıtlı arama yok")
                        .font(.headline)
                        .foregroundStyle(Color.tgsCharcoal)
                    Text("Ara sekmesinden yaptığınız bir aramayı kaydedebilirsiniz.")
                        .font(.subheadline)
                        .foregroundStyle(Color.tgsMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.tgsCream)
            } else {
                List {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.query ?? "(filtre)").font(.headline)
                            Text(row.filters.map { "\($0.key)=\($0.value.display)" }.joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteAt)
                }
            }
        }
        .navigationTitle("Kayıtlı Aramalar")
        .navigationBarTitleDisplayMode(.inline)
        .task { rows = (try? await APIClient.shared.savedSearches()) ?? [] }
    }

    private func deleteAt(_ offsets: IndexSet) {
        let toRemove = offsets.map { rows[$0] }
        rows.remove(atOffsets: offsets)
        Task {
            for r in toRemove {
                try? await APIClient.shared.deleteSavedSearch(id: r.id)
            }
        }
    }
}

// MARK: - My listings

struct MyListingsView: View {
    @State private var listings: [Listing] = []
    @State private var loading = false

    var body: some View {
        Group {
            if loading && listings.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if listings.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.tgsSurface).frame(width: 72, height: 72)
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.tgsMuted)
                    }
                    Text("Henüz ilan yok")
                        .font(.headline)
                        .foregroundStyle(Color.tgsCharcoal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.tgsCream)
            } else {
                List(listings) { listing in
                    NavigationLink(destination: DirectoryDetailView(listing: listing)) {
                        ListingRow(listing: listing)
                    }
                }
            }
        }
        .navigationTitle("İlanlarım")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            listings = try await APIClient.shared.myListings()
        } catch { /* keep empty */ }
    }
}
