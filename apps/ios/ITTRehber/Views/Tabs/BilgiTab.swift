import SwiftUI

struct BilgiTab: View {
    @State private var pages: [ContentPage] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                Section("Acil Durumlar") {
                    EmergencyRow(label: "Polis", number: "117")
                    EmergencyRow(label: "İtfaiye", number: "118")
                    EmergencyRow(label: "Tıbbi Acil", number: "144")
                    EmergencyRow(label: "Zehir Danışma", number: "145")
                    EmergencyRow(label: "Yol Yardım", number: "140")
                }

                Section("Rehber") {
                    if loading && pages.isEmpty {
                        HStack { ProgressView(); Text("Yükleniyor…").foregroundStyle(.secondary) }
                    } else {
                        ForEach(pages.filter { $0.slug != "emergency" }) { page in
                            NavigationLink(page.title) { ContentPageView(slug: page.slug) }
                        }
                    }
                }
            }
            .navigationTitle("Bilgi")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            pages = try await APIClient.shared.contentPages()
        } catch {
            // Offline-friendly: keep whatever we already loaded.
        }
    }
}

struct EmergencyRow: View {
    let label: String
    let number: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button {
                if let url = URL(string: "tel://\(number)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(number)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.tint)
            }
        }
    }
}

struct ContentPageView: View {
    let slug: String

    @State private var page: ContentPage?
    @State private var error: String?

    var body: some View {
        ScrollView {
            if let page {
                VStack(alignment: .leading, spacing: 12) {
                    Text(page.bodyMarkdown).font(.body)
                    Text("Son güncelleme: \(formatted(page.updatedAt))")
                        .font(.caption).foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
                .padding(16)
            } else if let error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 60)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .navigationTitle(page?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            page = try await APIClient.shared.contentPage(slug: slug)
        } catch let api as APIError {
            error = api.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_CH")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}
