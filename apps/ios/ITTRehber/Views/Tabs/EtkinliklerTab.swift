import SwiftUI

/// Phase 1 placeholder. Real Events feed (with v1 date-filter bug fixed) is Phase 2.
struct EtkinliklerTab: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(.tertiary)
                Text("Etkinlikler yakında")
                    .font(.title2.bold())
                Text("Topluluk etkinlikleri Faz 2 kapsamında geliyor. Yalnızca bugünden itibaren etkinlikler gösterilecek (v1’deki tarih filtresi hatası düzeltilecek).")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Etkinlikler")
        }
    }
}
