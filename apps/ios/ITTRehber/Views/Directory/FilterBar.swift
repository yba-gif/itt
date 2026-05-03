import SwiftUI

struct FilterBar: View {
    @Binding var query: String
    @Binding var selectedKanton: String
    let onChange: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("İsim, uzmanlık veya adres ara", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit(onChange)
                if !query.isEmpty {
                    Button {
                        query = ""
                        onChange()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )

            HStack(spacing: 8) {
                Menu {
                    Button("Tüm kantonlar", action: { selectedKanton = ""; onChange() })
                    Divider()
                    ForEach(Kanton.all) { kanton in
                        Button("\(kanton.code) — \(kanton.nameTR)") {
                            selectedKanton = kanton.code
                            onChange()
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedKanton.isEmpty ? "Kanton" : "Kanton: \(selectedKanton)")
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(.tertiarySystemBackground))
                    )
                }
                Spacer()
                if !query.isEmpty || !selectedKanton.isEmpty {
                    Button("Sıfırla") {
                        query = ""
                        selectedKanton = ""
                        onChange()
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}
