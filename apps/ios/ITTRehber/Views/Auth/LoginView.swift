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
                Text("Apple ile Giriş Faz 2 kapsamında etkinleştirilecek (gerçek Apple Developer Team gerektirir).")
                    .font(.caption)
            }
        }
        .alert("Yakında", isPresented: $showSIWAPlaceholder) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Apple ile Giriş için Apple Developer ekip kimliği yapılandırılmalı. Şimdilik e-posta ile devam edin.")
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
