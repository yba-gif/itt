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
}
