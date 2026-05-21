import SwiftUI

struct RehberTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 28)

                    DirectoryGridView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.tgsCream)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .navigationDestination(for: Directory.self) { directory in
                DirectoryListView(directory: directory)
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TGSEyebrow(icon: "globe.europe.africa.fill", label: "İSVİÇRE'DE TÜRK TOPLULUĞU")
            Text("TGS-ITT Rehber")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.tgsCharcoal)
            Text("Uzman, hizmet ve etkinlik rehberi")
                .font(.system(size: 14))
                .foregroundStyle(Color.tgsMuted)
        }
    }
}

struct DirectoryGridView: View {
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Directory.allCases) { directory in
                NavigationLink(value: directory) {
                    DirectoryTile(directory: directory)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Editorial white card tile — mirrors website's Programs.tsx card pattern.
struct DirectoryTile: View {
    let directory: Directory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 46, height: 46)
                Image(systemName: directory.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.tgsRed)
            }

            Spacer(minLength: 12)

            Text(directory.titleTR)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.tgsCharcoal)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 14)

            // CTA arrow
            HStack(spacing: 3) {
                Text("İncele")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Color.tgsRed)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .padding(16)
        .tgsCard()
    }
}

struct ComingSoonView: View {
    let directory: Directory

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.tgsRed.opacity(0.10))
                    .frame(width: 90, height: 90)
                Image(systemName: directory.systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.tgsRed)
            }
            VStack(spacing: 8) {
                Text(directory.titleTR)
                    .font(.title2.bold())
                    .foregroundStyle(Color.tgsCharcoal)
                Text("Bu rehber yakında hizmete girecek.")
                    .font(.subheadline)
                    .foregroundStyle(Color.tgsMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tgsCream)
        .navigationTitle(directory.titleTR)
        .navigationBarTitleDisplayMode(.inline)
    }
}
