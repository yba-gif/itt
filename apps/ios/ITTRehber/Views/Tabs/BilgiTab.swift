import SwiftUI

struct BilgiTab: View {
    @State private var pages: [ContentPage] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // QW-7: sorted by urgency — medical first
                    EmergencyRow(label: "Tıbbi Acil",     number: "144", icon: "heart.fill",    color: .red)
                    EmergencyRow(label: "Polis",          number: "117", icon: "shield.fill",   color: .blue)
                    EmergencyRow(label: "İtfaiye",        number: "118", icon: "flame.fill",    color: .orange)
                    EmergencyRow(label: "Zehir Danışma",  number: "145", icon: "pills.fill",    color: .purple)
                    EmergencyRow(label: "Yol Yardım",     number: "140", icon: "car.fill",      color: Color.tgsMuted)
                } header: {
                    Label("Acil Durumlar", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.tgsError)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }

                Section("Rehber") {
                    if loading && pages.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Yükleniyor…").foregroundStyle(Color.tgsMuted)
                        }
                    } else {
                        ForEach(pages.filter { $0.slug != "emergency" }) { page in
                            NavigationLink(page.title) {
                                ContentPageView(slug: page.slug)
                            }
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
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .foregroundStyle(Color.tgsCharcoal)
            Spacer()
            Button {
                if let url = URL(string: "tel://\(number)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(number)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.tgsRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.tgsRed.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label): \(number) numarasını ara")
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
                        .font(.caption).foregroundStyle(Color.tgsMuted)
                        .padding(.top, 8)
                }
                .padding(16)
            } else if let error {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.tgsErrorBg).frame(width: 64, height: 64)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.tgsError)
                    }
                    Text(error)
                        .foregroundStyle(Color.tgsMuted)
                        .multilineTextAlignment(.center)
                    Button("Tekrar Dene") { self.error = nil; Task { await load() } }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.tgsRed)
                }
                .padding(.top, 60)
                .padding(.horizontal, 32)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .background(Color.tgsCream)
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
