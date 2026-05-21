import SwiftUI

struct FilterBar: View {
    @Binding var query: String
    @Binding var selectedKanton: String
    let onChange: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.tgsMuted)
                TextField("İsim, uzmanlık veya adres ara", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .foregroundStyle(Color.tgsCharcoal)
                    .onSubmit(onChange)
                if !query.isEmpty {
                    Button {
                        query = ""
                        onChange()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.tgsMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.tgsBorder, lineWidth: 1)
                    )
            )

            // Kanton filter
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
                    HStack(spacing: 4) {
                        Text(selectedKanton.isEmpty ? "Kanton" : "Kanton: \(selectedKanton)")
                            .foregroundStyle(selectedKanton.isEmpty ? Color.tgsMuted : Color.tgsCharcoal)
                        Image(systemName: "chevron.down")
                            .foregroundStyle(Color.tgsMuted)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(selectedKanton.isEmpty ? Color.tgsSurface : Color.tgsRed.opacity(0.10))
                            .overlay(
                                Capsule()
                                    .stroke(selectedKanton.isEmpty ? Color.tgsBorder : Color.tgsRed.opacity(0.30),
                                            lineWidth: 1)
                            )
                    )
                }

                Spacer()

                if !query.isEmpty || !selectedKanton.isEmpty {
                    Button("Sıfırla") {
                        query = ""
                        selectedKanton = ""
                        onChange()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.tgsRed)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.tgsCream)
    }
}
