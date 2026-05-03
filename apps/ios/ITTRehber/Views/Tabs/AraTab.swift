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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .navigationTitle("Ara")
            .alert("Hata", isPresented: .constant(error != nil)) {
                Button("Tamam") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Tüm rehberlerde ara", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await search() } }
            if !query.isEmpty {
                Button {
                    query = ""
                    result = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Tüm rehberlerde tek aramada bulun")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Sonuç bulunamadı")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func resultsList(_ result: SearchResponse) -> some View {
        List {
            ForEach(result.groups, id: \.directory) { group in
                let directory = Directory(rawValue: group.directory)
                Section(header: HStack {
                    Text(directory?.titleTR ?? group.directory)
                    Spacer()
                    Text("\(group.count)").foregroundStyle(.secondary)
                }) {
                    ForEach(group.items) { listing in
                        NavigationLink(destination: DirectoryDetailView(listing: listing)) {
                            ListingRow(listing: listing)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
