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
        // P2-3: TGS form component replaces system Form/Section
        ScrollView {
            VStack(spacing: TGSSpacing.lg) {
                // Mode picker
                Picker("Mod", selection: $mode) {
                    Text("Giriş").tag(Mode.login)
                    Text("Kayıt").tag(Mode.signup)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, TGSSpacing.lg)
                .padding(.top, TGSSpacing.lg)

                if mode == .signup {
                    TGSFormSection(header: "Profil") {
                        TGSFieldRow(icon: "person",
                                    placeholder: "İsim (opsiyonel)",
                                    text: $displayName,
                                    autocapitalization: .words,
                                    showDivider: false)
                    }
                    .padding(.horizontal, TGSSpacing.lg)
                }

                TGSFormSection(header: "E-posta ile giriş") {
                    TGSFieldRow(icon: "envelope",
                                placeholder: "ornek@itt-rehber.ch",
                                text: $email,
                                keyboardType: .emailAddress,
                                autocapitalization: .never,
                                autocorrect: false)
                    TGSFieldRow(icon: "lock",
                                placeholder: "Parola",
                                text: $password,
                                isSecure: true,
                                showDivider: false)
                }
                .padding(.horizontal, TGSSpacing.lg)

                // Inline error
                if let error {
                    HStack(spacing: TGSSpacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.tgsError)
                        Text(error)
                            .font(TGSFont.subheadline)
                            .foregroundStyle(Color.tgsError)
                        Spacer()
                    }
                    .padding(TGSSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: TGSRadius.field, style: .continuous)
                            .fill(Color.tgsErrorBg)
                    )
                    .padding(.horizontal, TGSSpacing.lg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Submit button
                Button(action: submit) {
                    Group {
                        if busy {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(mode == .login ? "Giriş yap" : "Kayıt ol")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TGSSpacing.md)
                    .font(TGSFont.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.tgsRed)
                .disabled(busy || email.isEmpty || password.count < 8)
                .padding(.horizontal, TGSSpacing.lg)

                // Apple Sign In placeholder
                TGSFormSection(
                    footer: "Apple ile Giriş yakında aktif olacak. Şimdilik e-posta ile devam edebilirsiniz."
                ) {
                    Button {
                        showSIWAPlaceholder = true
                    } label: {
                        HStack(spacing: TGSSpacing.sm) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 15))
                            Text("Apple ile Giriş")
                                .font(TGSFont.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TGSSpacing.md)
                        .foregroundStyle(Color.tgsCharcoal)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, TGSSpacing.lg)

                Spacer(minLength: TGSSpacing.xl)
            }
            .animation(.easeInOut(duration: 0.2), value: error)
            .animation(.easeInOut(duration: 0.2), value: mode)
        }
        .background(Color.tgsCream)
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
