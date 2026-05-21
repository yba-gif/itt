import SwiftUI

struct BilgiTab: View {
    @State private var pages: [ContentPage] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                // Featured hotline card — full-bleed, prominent, sits at the top
                Section {
                    SocialAidHotlineCard()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                Section {
                    // QW-7: sorted by urgency — medical first
                    EmergencyRow(label: "Tıbbi Acil",     number: "144", icon: "heart.fill",    color: .red)
                    EmergencyRow(label: "Polis",          number: "117", icon: "shield.fill",   color: .blue)
                    EmergencyRow(label: "İtfaiye",        number: "118", icon: "flame.fill",    color: .orange)
                    EmergencyRow(label: "Zehir Danışma",  number: "145", icon: "pills.fill",    color: .purple)
                    EmergencyRow(label: "Yol Yardım",     number: "140", icon: "car.fill",      color: Color.tgsMuted)
                } header: {
                    Label("Acil Durumlar", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.tgsError)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }

                Section {
                    ConsulateTileRow(
                        city: "Bern",
                        title: "Türkiye Büyükelçiliği",
                        address: "Villastrasse 32, 3006 Bern",
                        phone: "+41313592200"
                    )
                    ConsulateTileRow(
                        city: "Zürich",
                        title: "Başkonsolosluk",
                        address: "Basteiplatz 2, 8001 Zürich",
                        phone: "+41442016400"
                    )
                    ConsulateTileRow(
                        city: "Cenevre",
                        title: "Başkonsolosluk",
                        address: "Avenue Soret 4, 1203 Genève",
                        phone: "+41227321600"
                    )
                    ConsulateTileRow(
                        city: "Basel",
                        title: "Konsolosluk",
                        address: "Wallstrasse 11, 4051 Basel",
                        phone: "+41613122061"
                    )
                } header: {
                    Label("Konsolosluk Bilgileri", systemImage: "building.columns.fill")
                        .foregroundStyle(Color.tgsRed)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }

                Section("Rehber") {
                    if loading && pages.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Yükleniyor…").foregroundStyle(Color.tgsMuted)
                        }
                    } else {
                        // Exclude slugs shown elsewhere in this view
                        ForEach(pages.filter { !["emergency", "welcome", "consulate"].contains($0.slug) }) { page in
                            NavigationLink(page.title) {
                                ContentPageView(slug: page.slug)
                            }
                        }
                    }
                }

                // Socials section — full-bleed row of platform chips
                Section {
                    SocialsRow()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 40, trailing: 0))
                        .listRowSeparator(.hidden)
                } header: {
                    Label("Bizi Takip Edin", systemImage: "heart.text.square.fill")
                        .foregroundStyle(Color.tgsRed)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.tgsCream)
            .navigationTitle("Bilgi")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            pages = try await APIClient.shared.contentPages()
        } catch {
            // Offline-friendly: keep whatever we already loaded.
        }
    }
}

struct EmergencyRow: View {
    let label: String
    let number: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .foregroundStyle(Color.tgsCharcoal)
            Spacer()
            Button {
                if let url = URL(string: "tel://\(number)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(number)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.tgsRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.tgsRed.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label): \(number) numarasını ara")
        }
    }
}

struct ContentPageView: View {
    let slug: String

    @State private var page: ContentPage?
    @State private var error: String?

    var body: some View {
        ScrollView {
            if let page {
                MarkdownView(markdown: page.bodyMarkdown)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error {
                // P2-5: reusable inline error state
                ErrorStateView(message: error) { self.error = nil; Task { await load() } }
                    .padding(.top, 32)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .background(Color.tgsCream)
        // NavigationStack push destinations don't inherit the parent's
        // safeAreaInset for the floating tab bar — apply locally so the last
        // paragraph clears the tab bar instead of disappearing behind it.
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .navigationTitle(page?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            page = try await APIClient.shared.contentPage(slug: slug)
        } catch let api as APIError {
            error = api.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

}

// MARK: - Consulate Row

struct ConsulateTileRow: View {
    let city: String
    let title: String
    let address: String
    let phone: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(city)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.tgsCharcoal)
                    Text("·")
                        .foregroundStyle(Color.tgsMuted)
                    Text(title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.tgsMuted)
                }
                Text(address)
                    .font(.caption)
                    .foregroundStyle(Color.tgsMuted)
            }

            Spacer()

            Button {
                if let url = URL(string: "tel://\(phone)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
                    .frame(width: 36, height: 36)
                    .background(Capsule().fill(Color.tgsRed.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(city) konsolosluğunu ara")
        }
    }
}

// MARK: - Sosyal Yardım Hattı (Social Aid Hotline) Card

/// Featured card at the top of Bilgi tab. The TGS-ITT social-aid hotline
/// — lawyers, healthcare workers, educators who listen to community
/// problems and route callers to the right authorities.
struct SocialAidHotlineCard: View {
    private let phone = "+41445932424"
    private let phoneDisplay = "+41 44 593 24 24"

    var body: some View {
        Button(action: call) {
            ZStack(alignment: .bottomTrailing) {
                // Background gradient + decorative star
                LinearGradient(
                    colors: [Color.tgsRed, Color(red: 0.55, green: 0.07, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative star in the corner (subtle, like the original poster)
                Image(systemName: "star.fill")
                    .font(.system(size: 180))
                    .foregroundStyle(.white.opacity(0.06))
                    .offset(x: 50, y: 30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .top, spacing: TGSSpacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SOSYAL YARDIM HATTI")
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Tüm sosyal sorunlarınızda yanınızdayız")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: "headphones")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    // Description
                    Text("Hukukçu, sağlıkçı ve eğitimcilerimiz sorunlarınızı dinleyip doğru mercilere yönlendiriyor.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                        .padding(.bottom, 14)

                    // Phone CTA chip
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(phoneDisplay)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Spacer(minLength: 0)
                        Text("Bize ulaşın")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.6)
                            .opacity(0.7)
                    }
                    .foregroundStyle(Color.tgsRed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white)
                    )
                    .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 4)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: TGSRadius.card, style: .continuous))
            .shadow(color: Color.tgsRed.opacity(0.30), radius: 14, x: 0, y: 6)
            .padding(.horizontal, TGSSpacing.md)
        }
        .buttonStyle(TGSSpringButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sosyal Yardım Hattı'nı ara: \(phoneDisplay)")
    }

    private func call() {
        if let url = URL(string: "tel://\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Socials Row

/// Horizontal row of platform chips at the bottom of the Bilgi tab.
/// Each tile is tappable and opens the respective URL in the default
/// browser / mail app.
struct SocialsRow: View {
    private struct Social {
        let label: String
        let systemIcon: String?       // SF Symbol fallback
        let url: String
        let tint: Color
    }

    private let items: [Social] = [
        .init(label: "Facebook",  systemIcon: "f.square.fill",       url: "https://www.facebook.com/itt.tgs",                 tint: Color(red: 0.10, green: 0.36, blue: 0.78)),
        .init(label: "X",         systemIcon: "xmark",                url: "https://x.com/isvicreturkitt",                     tint: Color.black),
        .init(label: "Instagram", systemIcon: "camera.fill",          url: "https://www.instagram.com/isvicreturktoplumu_itt/", tint: Color(red: 0.78, green: 0.16, blue: 0.50)),
        .init(label: "Web",       systemIcon: "globe",                url: "https://tgs-itt.ch/",                              tint: Color.tgsRed),
        .init(label: "E-posta",   systemIcon: "envelope.fill",        url: "mailto:info@tgs-itt.ch",                           tint: Color.tgsCharcoal),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.label) { item in
                socialChip(item)
            }
        }
        .padding(.horizontal, TGSSpacing.md)
    }

    private func socialChip(_ item: Social) -> some View {
        Button {
            if let url = URL(string: item.url) {
                UIApplication.shared.open(url)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(item.tint.opacity(0.12))
                        .frame(height: 56)
                    Image(systemName: item.systemIcon ?? "link")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(item.tint)
                }
                Text(item.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.tgsCharcoal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TGSSpringButtonStyle())
        .accessibilityLabel("\(item.label) sayfasını aç")
    }
}

// MARK: - Markdown Renderer
//
// Renders headings (# ## ###), bullet lists (-), and inline **bold** / *italic*.
// SwiftUI's Text(_:markdown:) only does inline markdown, so we parse blocks ourselves
// and apply per-block fonts.

private enum MarkdownBlockKind {
    case h1, h2, h3, paragraph, listItem, blank
}

private struct MarkdownBlock: Identifiable {
    let id = UUID()
    let kind: MarkdownBlockKind
    let text: String
}

struct MarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(parseBlocks()) { block in
                row(for: block)
            }
        }
    }

    @ViewBuilder
    private func row(for block: MarkdownBlock) -> some View {
        switch block.kind {
        case .h1:
            inlineText(block.text)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tgsCharcoal)
                .padding(.top, 6)
                .padding(.bottom, 2)
        case .h2:
            inlineText(block.text)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.tgsRed)
                .padding(.top, 10)
                .padding(.bottom, 2)
        case .h3:
            inlineText(block.text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.tgsCharcoal)
                .padding(.top, 4)
        case .paragraph:
            inlineText(block.text)
                .font(.body)
                .foregroundStyle(Color.tgsCharcoal)
                .fixedSize(horizontal: false, vertical: true)
        case .listItem:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.tgsRed)
                inlineText(block.text)
                    .font(.body)
                    .foregroundStyle(Color.tgsCharcoal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .blank:
            Color.clear.frame(height: 2)
        }
    }

    private func inlineText(_ s: String) -> Text {
        if let attr = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(s)
    }

    private func parseBlocks() -> [MarkdownBlock] {
        markdown.components(separatedBy: "\n").map { line -> MarkdownBlock in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                return MarkdownBlock(kind: .blank, text: "")
            } else if trimmed.hasPrefix("### ") {
                return MarkdownBlock(kind: .h3, text: String(trimmed.dropFirst(4)))
            } else if trimmed.hasPrefix("## ") {
                return MarkdownBlock(kind: .h2, text: String(trimmed.dropFirst(3)))
            } else if trimmed.hasPrefix("# ") {
                return MarkdownBlock(kind: .h1, text: String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("- ") {
                return MarkdownBlock(kind: .listItem, text: String(trimmed.dropFirst(2)))
            } else {
                return MarkdownBlock(kind: .paragraph, text: trimmed)
            }
        }
    }
}
