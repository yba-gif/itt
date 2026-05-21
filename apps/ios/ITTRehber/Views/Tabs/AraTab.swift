import SwiftUI

/// Global search across all directories. Phase 2: PRD §5.5.
struct AraTab: View {
    @State private var query = ""
    @State private var result: SearchResponse?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.tgsCream)

                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.tgsCream)
                } else if let result {
                    if result.total == 0 {
                        emptyState
                    } else {
                        resultsList(result)
                    }
                } else {
                    placeholder
                }
            }
            .background(Color.tgsCream)
            .navigationTitle("Ara")
            .alert("Hata", isPresented: .constant(error != nil)) {
                Button("Tamam") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.tgsMuted)
            TextField("Tüm rehberlerde ara", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(Color.tgsCharcoal)
                .onSubmit { Task { await search() } }
            if !query.isEmpty {
                Button {
                    query = ""
                    result = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.tgsMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.tgsBorder, lineWidth: 1)
                )
        )
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.tgsSurface)
                    .frame(width: 80, height: 80)
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.tgsMuted)
            }
            Text("Tüm rehberlerde tek aramada bulun")
                .font(.subheadline)
                .foregroundStyle(Color.tgsMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tgsCream)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.tgsSurface)
                    .frame(width: 80, height: 80)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.tgsMuted)
            }
            Text("Sonuç bulunamadı")
                .font(.headline)
                .foregroundStyle(Color.tgsCharcoal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tgsCream)
    }

    private func resultsList(_ result: SearchResponse) -> some View {
        List {
            ForEach(result.groups, id: \.directory) { group in
                let directory = Directory(rawValue: group.directory)
                Section {
                    ForEach(group.items) { listing in
                        NavigationLink(destination: DirectoryDetailView(listing: listing)) {
                            ListingRow(listing: listing)
                        }
                        .listRowBackground(Color.white)
                        .listRowSeparatorTint(Color.tgsBorder)
                    }
                } header: {
                    HStack {
                        Text(directory?.titleTR ?? group.directory)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.tgsMuted)
                            .textCase(nil)
                        Spacer()
                        Text("\(group.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.tgsMuted)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.tgsCream)
    }

    private func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            result = nil; return
        }
        loading = true
        defer { loading = false }
        do {
            result = try await APIClient.shared.globalSearch(query: query)
        } catch let api as APIError {
            error = api.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
