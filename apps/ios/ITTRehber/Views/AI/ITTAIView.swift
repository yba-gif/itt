import SwiftUI

// MARK: - İTT AI — Full-screen conversational assistant
// Entry: hero glass card button in RehberTab → .fullScreenCover

struct ITTAIView: View {
    /// When true, shows the X dismiss button (modal presentation).
    /// When false, the view is hosted as a tab — no dismiss button.
    var isModal: Bool = true

    @StateObject private var service = ITTAIService.shared
    @EnvironmentObject var nav: Nav
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // Suggested starter questions
    private let suggestions: [(icon: String, text: String)] = [
        ("stethoscope",       "İsviçre'de nasıl doktor bulurum?"),
        ("doc.text",          "Oturum izni için ne gerekli?"),
        ("graduationcap",     "Çocuğum için dil kursu var mı?"),
        ("creditcard",        "Vergi beyannamesi nasıl yapılır?"),
        ("briefcase",         "İsviçre'de şirket nasıl kurulur?"),
        ("person.crop.circle","Türkçe avukat arıyorum")
    ]

    var body: some View {
        ZStack {
            // Deep dark background with subtle TGS-red glow at top
            Color.tgsAIDark.ignoresSafeArea()
            RadialGradient(
                colors: [Color.tgsRed.opacity(0.12), Color.clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: UIScreen.main.bounds.width
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                messagesArea
                inputBar
            }
        }
        .preferredColorScheme(.dark)
        // Intercept itt:// deep links emitted by the AI as markdown links.
        // Anything else (http/https/tel/mailto) falls through to the system.
        .environment(\.openURL, OpenURLAction { url in
            if nav.route(url) { return .handled }
            return .systemAction
        })
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            // Brand mark
            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("İTT AI")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text("TGS-ITT Asistanı · Beta")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            // Clear conversation
            if !service.messages.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { service.clear() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sohbeti temizle")
                .transition(.opacity)
            }

            // Dismiss — only in modal presentation
            if isModal {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kapat")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(.white.opacity(0.08)),
            alignment: .bottom
        )
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if service.messages.isEmpty {
                        welcomeView
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                    ForEach(service.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                            .transition(.opacity.combined(with: .move(edge: msg.role == .user ? .trailing : .leading)))
                    }
                    // Invisible scroll anchor
                    Color.clear.frame(height: 1).id("ittai-bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .animation(.easeOut(duration: 0.2), value: service.messages.count)
            }
            .tgsOnChange(of: service.messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("ittai-bottom", anchor: .bottom)
                }
            }
            // Scroll to bottom as streaming text grows
            .tgsOnChange(of: service.messages.last?.text) {
                proxy.scrollTo("ittai-bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Welcome / Empty State

    private var welcomeView: some View {
        VStack(spacing: 28) {
            // Animated sparkle icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.tgsRed.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 56
                        )
                    )
                    .frame(width: 112, height: 112)
                Image(systemName: "sparkles")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.tgsRed, Color(tgsHex: 0xFF6B7A)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.top, 32)

            VStack(spacing: 8) {
                Text("Merhaba, ben İTT AI")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("İsviçre'deki Türk topluluğuna dair\nher konuda yardımcı olurum.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Suggestion chips
            VStack(alignment: .leading, spacing: 10) {
                Text("Bir konu seçin veya kendi sorunuzu yazın")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(suggestions, id: \.text) { s in
                        suggestionChip(icon: s.icon, text: s.text)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 24)
    }

    private func suggestionChip(icon: String, text: String) -> some View {
        Button {
            Task { await service.sendMessage(text) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.tgsRed.opacity(0.8))
                    .frame(width: 16)
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.tgsAIChip)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(TGSSpringButtonStyle())
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.white.opacity(0.08))

            HStack(alignment: .bottom, spacing: 10) {
                // Text input.
                // Placeholder is rendered as a manual overlay because SwiftUI's
                // built-in TextField placeholder color uses the system's
                // `placeholderText` UIColor — on a light system theme this
                // renders as dark gray, which disappears on `tgsAIInput`. The
                // view's `.preferredColorScheme(.dark)` doesn't reliably
                // propagate to the underlying UITextField placeholder.
                TextField("", text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(Color.tgsRed)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.tgsAIInput)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .overlay(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text("Bir şey sorun…")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.42))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }
                    }

                // Send button
                Button { sendMessage() } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? Color.tgsRed : Color(tgsHex: 0x2A1A1E))
                            .frame(width: 40, height: 40)
                        if service.isStreaming {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(canSend ? .white : .white.opacity(0.3))
                        }
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: canSend)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Gönder")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.tgsAIDark)
        }
    }

    // MARK: - Helpers

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !service.isStreaming
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !service.isStreaming else { return }
        inputText = ""
        Task { await service.sendMessage(text) }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: AIMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 56)
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.tgsRed)
                    )
                    .textSelection(.enabled)
            } else {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(Color.tgsRed.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.tgsRed)
                }
                .alignmentGuide(.bottom) { d in d[.bottom] }

                Group {
                    if message.text.isEmpty {
                        ThinkingIndicator()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    } else {
                        Text(MessageBubble.attributed(message.text))
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.tgsAISurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.07), lineWidth: 1)
                        )
                )

                Spacer(minLength: 56)
            }
        }
    }

    /// Convert assistant markdown (bold, italic, links) into an AttributedString.
    /// We use `inlineOnlyPreservingWhitespace` so line breaks survive but block
    /// constructs (headings, fenced code, etc.) are treated as literal — those
    /// rarely appear in our chat answers and aren't worth the complexity.
    /// Falls back to plain text if parsing fails (e.g. mid-stream half-tokens).
    static func attributed(_ raw: String) -> AttributedString {
        if let attr = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attr
        }
        return AttributedString(raw)
    }
}

// MARK: - Thinking Indicator (three bouncing dots)

private struct ThinkingIndicator: View {
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                ThinkingDot(delay: Double(i) * 0.18)
            }
        }
    }
}

private struct ThinkingDot: View {
    let delay: Double
    @State private var up = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.45))
            .frame(width: 6, height: 6)
            .offset(y: up ? -5 : 0)
            .animation(
                .easeInOut(duration: 0.45)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: up
            )
            .onAppear { up = true }
    }
}
