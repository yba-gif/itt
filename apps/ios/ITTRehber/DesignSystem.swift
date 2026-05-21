import SwiftUI

// MARK: - TGS Color System
// Mirrors the TGS website design language (src/index.css in tgs-precision-rebuild)

extension Color {
    /// Page background — warm cream #F8F4EF
    static let tgsCream    = Color(tgsHex: 0xF8F4EF)
    /// Input / secondary surface — warm beige #EDE8E0
    static let tgsSurface  = Color(tgsHex: 0xEDE8E0)
    /// Primary text — deep charcoal #242C3B
    static let tgsCharcoal = Color(tgsHex: 0x242C3B)
    /// Brand accent — TGS red #B82030
    static let tgsRed      = Color(tgsHex: 0xB82030)
    /// Hairline border — warm gray #E3DEDA
    static let tgsBorder   = Color(tgsHex: 0xE3DEDA)
    /// Secondary / muted text — #626C7A
    static let tgsMuted    = Color(tgsHex: 0x626C7A)
    /// Warning / offline amber foreground — #7A5F00
    static let tgsAmber    = Color(tgsHex: 0x7A5F00)
    /// Warning / offline amber background — #FFF0B3
    static let tgsAmberBg  = Color(tgsHex: 0xFFF0B3)
    /// Destructive / error red — slightly lighter than tgsRed for backgrounds
    static let tgsError    = Color(tgsHex: 0x9E1B2A)
    /// Error background — very light red
    static let tgsErrorBg  = Color(tgsHex: 0xFDF0F1)
    /// Success green foreground — #1A7A48
    static let tgsSuccess  = Color(tgsHex: 0x1A7A48)
    /// Success background — #EDFAF3
    static let tgsSuccessBg = Color(tgsHex: 0xEDFAF3)

    init(tgsHex hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255
        )
    }
}

// MARK: - Type Scale (P1-6)
// Maps to SF Pro. Decorative sizes use @ScaledMetric for Dynamic Type support.

enum TGSFont {
    /// 28pt bold — hero titles (RehberTab, detail views)
    static let display: Font = .system(size: 28, weight: .bold, design: .default)
    /// 22pt bold — screen-level titles
    static let title: Font = .system(size: 22, weight: .bold, design: .default)
    /// 17pt semibold — card/section headings
    static let headline: Font = .system(size: 17, weight: .semibold, design: .default)
    /// 15pt semibold — row titles, tile labels
    static let rowTitle: Font = .system(size: 15, weight: .semibold, design: .default)
    /// 15pt regular — body copy
    static let body: Font = .system(size: 15, weight: .regular, design: .default)
    /// 13pt regular — secondary body
    static let subheadline: Font = .system(size: 13, weight: .regular, design: .default)
    /// 12pt medium — labels, eyebrows
    static let caption: Font = .system(size: 12, weight: .medium, design: .default)
    /// 11pt semibold — micro labels, pills
    static let micro: Font = .system(size: 11, weight: .semibold, design: .default)
}

// MARK: - Radius & Spacing Tokens (P1-7)

enum TGSRadius {
    /// 24pt — primary cards (DirectoryTile, sheet containers)
    static let card: CGFloat    = 24
    /// 16pt — inner cards (detail rows, description sections)
    static let inner: CGFloat   = 16
    /// 12pt — form fields, search bars
    static let field: CGFloat   = 12
    /// 999pt — pills and capsules
    static let pill: CGFloat    = 999
}

enum TGSSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 12
    static let lg: CGFloat  = 16
    static let xl: CGFloat  = 20
    static let xxl: CGFloat = 24
}

// MARK: - Section Eyebrow
/// Red pill label — mirrors website's `section-eyebrow` pattern.
struct TGSEyebrow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
        }
        .foregroundStyle(Color.tgsRed)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.tgsRed.opacity(0.10)))
    }
}

// MARK: - Card Modifiers

/// Primary card — white, 24 pt radius, warm hairline border, soft shadow.
/// Mirrors: `rounded-3xl bg-card border border-border shadow-sm`
struct TGSCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.tgsBorder, lineWidth: 1)
            )
            .shadow(color: Color.tgsCharcoal.opacity(0.06), radius: 14, x: 0, y: 4)
    }
}

/// Inner card — white, 16 pt radius, warm hairline border, no shadow.
struct TGSInnerCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.tgsBorder, lineWidth: 1)
            )
    }
}

extension View {
    func tgsCard() -> some View { modifier(TGSCardModifier()) }
    func tgsInnerCard() -> some View { modifier(TGSInnerCardModifier()) }

    /// Applies a symbol bounce effect when `value` changes on iOS 17+;
    /// no-ops on iOS 16 so the deployment target stays at 16.0.
    @ViewBuilder
    func tgsBounce<V: Equatable>(value: V) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }
}

// MARK: - TGS Form Components (P2-3)

/// Styled form section card — white inner card with optional header.
/// Replaces `Form { Section }` with TGS editorial aesthetics.
struct TGSFormSection<Content: View>: View {
    let header: String?
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(header: String? = nil, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                Text(header)
                    .font(TGSFont.caption)
                    .foregroundStyle(Color.tgsMuted)
                    .textCase(.uppercase)
                    .tracking(0.3)
                    .padding(.horizontal, TGSSpacing.xs)
                    .padding(.bottom, TGSSpacing.xs)
            }

            VStack(spacing: 0) {
                content()
            }
            .tgsInnerCard()

            if let footer {
                Text(footer)
                    .font(TGSFont.micro)
                    .foregroundStyle(Color.tgsMuted)
                    .padding(.horizontal, TGSSpacing.xs)
                    .padding(.top, TGSSpacing.xs)
            }
        }
    }
}

/// Styled text field row for use inside `TGSFormSection`.
/// Shows icon, label, and text field on a single row with a hairline divider.
struct TGSFieldRow: View {
    let icon: String?
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrect: Bool = true
    var isSecure: Bool = false
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: TGSSpacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.tgsMuted)
                        .frame(width: 20, alignment: .center)
                        .accessibilityHidden(true)
                }
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .textInputAutocapitalization(autocapitalization)
                            .autocorrectionDisabled(!autocorrect)
                    }
                }
                .font(TGSFont.body)
                .foregroundStyle(Color.tgsCharcoal)
            }
            .padding(.horizontal, TGSSpacing.lg)
            .padding(.vertical, TGSSpacing.md)

            if showDivider {
                Divider()
                    .overlay(Color.tgsBorder)
                    .padding(.leading, icon != nil ? TGSSpacing.lg + 20 + TGSSpacing.md : TGSSpacing.lg)
            }
        }
    }
}

// MARK: - Skeleton Loading (P2-1)

/// Animated shimmer placeholder for list rows and grid tiles while content loads.
struct SkeletonShape: View {
    @State private var phase: CGFloat = 0

    var cornerRadius: CGFloat = TGSRadius.field
    var height: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.tgsSurface, location: phase - 0.3),
                            .init(color: Color.tgsBorder.opacity(0.6), location: phase),
                            .init(color: Color.tgsSurface, location: phase + 0.3),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: height)
                .onAppear {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
        }
        .frame(height: height)
    }
}

/// Full listing-row skeleton — mirrors ListingRow layout.
struct ListingRowSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: TGSRadius.field, style: .continuous)
                .fill(Color.tgsSurface)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonShape(cornerRadius: 6, height: 14)
                    .frame(maxWidth: 160)
                SkeletonShape(cornerRadius: TGSRadius.pill, height: 11)
                    .frame(maxWidth: 80)
                SkeletonShape(cornerRadius: 4, height: 10)
                    .frame(maxWidth: 100)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityHidden(true) // skeleton is purely decorative
    }
}

/// Grid tile skeleton — mirrors DirectoryTile layout.
struct DirectoryTileSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Circle()
                .fill(Color.tgsSurface)
                .frame(width: 46, height: 46)
            Spacer(minLength: TGSSpacing.md)
            SkeletonShape(cornerRadius: 6, height: 14)
                .frame(maxWidth: 80)
            Spacer(minLength: TGSSpacing.md)
            SkeletonShape(cornerRadius: TGSRadius.pill, height: 10)
                .frame(maxWidth: 60)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .padding(TGSSpacing.lg)
        .tgsCard()
        .accessibilityHidden(true)
    }
}

// MARK: - Inline Error State (P2-5)

/// Reusable full-screen error state with an icon, message, and optional retry action.
/// Replaces one-off modal alerts for load failures throughout the app.
struct ErrorStateView: View {
    let message: String
    var retryLabel: String = "Tekrar Dene"
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: TGSSpacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.tgsErrorBg)
                    .frame(width: 72, height: 72)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.tgsError)
            }
            .accessibilityHidden(true)

            Text(message)
                .font(TGSFont.subheadline)
                .foregroundStyle(Color.tgsMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TGSSpacing.xl)

            if let onRetry {
                Button(retryLabel, action: onRetry)
                    .font(TGSFont.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.tgsRed)
                    .accessibilityHint("Yüklenirken bir hata oluştu, tekrar denemek için dokunun")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tgsCream)
        .accessibilityElement(children: .contain)
    }
}
