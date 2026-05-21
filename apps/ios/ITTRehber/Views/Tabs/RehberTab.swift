import SwiftUI

struct RehberTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero banner
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("TGS-ITT Rehber")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("İsviçre'deki Türk topluluğu için")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: "globe.europe.africa.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    DirectoryGridView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .navigationDestination(for: Directory.self) { directory in
                DirectoryListView(directory: directory)
            }
        }
    }
}

struct DirectoryGridView: View {
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Directory.allCases) { directory in
                NavigationLink(value: directory) {
                    DirectoryTile(directory: directory)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DirectoryTile: View {
    let directory: Directory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon in a frosted circle
            ZStack {
                Circle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 50, height: 50)
                Image(systemName: directory.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 14)

            Text(directory.titleTR)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            directory.color,
                            directory.color.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: directory.color.opacity(0.40), radius: 10, x: 0, y: 5)
    }
}

struct ComingSoonView: View {
    let directory: Directory

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(directory.color.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: directory.systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(directory.color)
            }
            VStack(spacing: 8) {
                Text(directory.titleTR)
                    .font(.title2.bold())
                Text("Bu rehber yakında hizmete girecek.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(directory.titleTR)
        .navigationBarTitleDisplayMode(.inline)
    }
}
