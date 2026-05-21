import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionStore
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var error: String?
    @State private var busy = false
    @State private var showSIWAPlaceholder = false

    enum Mode { case login, signup }

    var body: some View {
        Form {
            // QW-4: explicit tint so Form controls use TGS red even when system blue leaks through
            Section {
                Picker("Mod", selection: $mode) {
                    Text("Giriş").tag(Mode.login)
                    Text("Kayıt").tag(Mode.signup)
                }
                .pickerStyle(.segmented)
            }

            if mode == .signup {
                Section("Bilgiler") {
                    TextField("İsim (opsiyonel)", text: $displayName)
                        .textContentType(.name)
                }
            }

            Section("E-posta") {
                TextField("ornek@itt-rehber.ch", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Parola", text: $password)
                    .textContentType(mode == .login ? .password : .newPassword)
            }

            if let error {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                Button(action: submit) {
                    if busy { ProgressView() } else {
                        Text(mode == .login ? "Giriş yap" : "Kayıt ol")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy || email.isEmpty || password.count < 8)
            }

            Section {
                Button {
                    showSIWAPlaceholder = true
                } label: {
                    HStack {
                        Image(systemName: "applelogo")
                        Text("Apple ile Giriş")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } footer: {
                // QW-1: removed implementation detail from user-facing copy
                Text("Apple ile Giriş yakında aktif olacak. Şimdilik e-posta ile devam edebilirsiniz.")
                    .font(.caption)
            }
        }
        .tint(Color.tgsRed)
        .alert("Yakında", isPresented: $showSIWAPlaceholder) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Apple ile Giriş yakında aktif olacak.")
        }
    }

    private func submit() {
        Task {
            busy = true
            error = nil
            defer { busy = false }
            do {
                let token: AuthToken
                switch mode {
                case .login:
                    token = try await APIClient.shared.emailLogin(email: email, password: password)
                case .signup:
                    token = try await APIClient.shared.emailSignup(
                        email: email,
                        password: password,
                        displayName: displayName.isEmpty ? nil : displayName
                    )
                }
                await session.adopt(token.accessToken)
            } catch {
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
