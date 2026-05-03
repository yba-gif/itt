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

            Section("Listelerim") {
                Text("Faz 1 kapsamında: Sağlık dizinine listelenmiş öğeleriniz burada görünecek.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                Text("Hesabınızı silerseniz aktif ödemeli ilanlarınız ödendiği süre boyunca yayında kalır; sahiplik bilgileri anonimleştirilir. Bu işlem geri alınamaz.")
            }
        }
        .alert("Hesabı Sil", isPresented: $showDeleteConfirm) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sil", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("Hesabınız kalıcı olarak silinecek. Devam etmek istiyor musunuz?")
        }
        .alert("Hata", isPresented: .constant(deleteError != nil)) {
            Button("Tamam") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func deleteAccount() async {
        do { try await session.deleteAccount() }
        catch { deleteError = error.localizedDescription }
    }
}
