import SwiftUI

struct BilgiTab: View {
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
                    NavigationLink("Hoş Geldiniz Rehberi") { ComingSoonInfoView(title: "Hoş Geldiniz") }
                    NavigationLink("Türk Konsoloslukları") { ComingSoonInfoView(title: "Konsolosluk Bilgileri") }
                    NavigationLink("Gizlilik Politikası") { ComingSoonInfoView(title: "Gizlilik") }
                    NavigationLink("Kullanım Koşulları") { ComingSoonInfoView(title: "Koşullar") }
                    NavigationLink("Hakkında") { AboutView() }
                }
            }
            .navigationTitle("Bilgi")
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
        .accessibilityElement(children: .combine)
        .accessibilityHint("Aramak için dokunun")
    }
}

struct ComingSoonInfoView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("İçerik yakında")
                .font(.title3.bold())
            Text("Bu sayfa Faz 2 kapsamında dolacak.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                Text("ITT-Rehber 2.0")
                    .font(.headline)
                Text("İsviçre’deki Türk topluluğu için rehber.")
                    .foregroundStyle(.secondary)
            }
            Section("Künye") {
                Text("İşleten: Roar (Yusuf Berkan Altun)")
                Text("Sürüm: 0.1.0 (Faz 1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Hakkında")
        .navigationBarTitleDisplayMode(.inline)
    }
}
