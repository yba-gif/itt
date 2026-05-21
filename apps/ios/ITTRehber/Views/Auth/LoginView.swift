import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var session: SessionStore
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var error: String?
    @State private var busy = false

    enum Mode { case login, signup }

    var body: some View {
        ScrollView {
            VStack(spacing: TGSSpacing.lg) {

                // ── Apple Sign In (primary CTA) ──────────────────────────
                SIWAButton { credential in
                    await handleSIWA(credential)
                }
                .frame(height: 50)
                .padding(.horizontal, TGSSpacing.lg)
                .padding(.top, TGSSpacing.lg)

                // Divider
                HStack {
                    Rectangle().fill(Color.tgsBorder).frame(height: 1)
                    Text("veya e-posta ile")
                        .font(.caption)
                        .foregroundStyle(Color.tgsMuted)
                        .fixedSize()
                    Rectangle().fill(Color.tgsBorder).frame(height: 1)
                }
                .padding(.horizontal, TGSSpacing.lg)

                // ── Email/password ───────────────────────────────────────
                Picker("Mod", selection: $mode) {
                    Text("Giriş").tag(Mode.login)
                    Text("Kayıt").tag(Mode.signup)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, TGSSpacing.lg)

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

                Button(action: submit) {
                    Group {
                        if busy {
                            ProgressView().tint(.white)
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

                Spacer(minLength: TGSSpacing.xl)
            }
            .animation(.easeInOut(duration: 0.2), value: error)
            .animation(.easeInOut(duration: 0.2), value: mode)
        }
        .background(Color.tgsCream)
    }

    // MARK: - Apple Sign In handler

    private func handleSIWA(_ credential: ASAuthorizationAppleIDCredential) async {
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            error = "Apple kimlik doğrulaması başarısız oldu."
            return
        }
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        busy = true
        error = nil
        defer { busy = false }
        do {
            let token = try await APIClient.shared.siwaLogin(
                identityToken: identityToken,
                displayName: fullName.isEmpty ? nil : fullName
            )
            await session.adopt(token.accessToken)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Email submit

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

// MARK: - Sign In With Apple Button (UIViewRepresentable)

struct SIWAButton: UIViewRepresentable {
    let onCredential: (ASAuthorizationAppleIDCredential) async -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCredential: onCredential) }

    final class Coordinator: NSObject, ASAuthorizationControllerDelegate,
                             ASAuthorizationControllerPresentationContextProviding {
        let onCredential: (ASAuthorizationAppleIDCredential) async -> Void

        init(onCredential: @escaping (ASAuthorizationAppleIDCredential) async -> Void) {
            self.onCredential = onCredential
        }

        @objc func tapped() {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithAuthorization auth: ASAuthorization) {
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            Task { await onCredential(credential) }
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithError error: Error) {
            // User cancelled or error — no-op
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
