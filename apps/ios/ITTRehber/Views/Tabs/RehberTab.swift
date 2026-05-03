import SwiftUI

struct RehberTab: View {
    var body: some View {
        NavigationStack {
            DirectoryGridView()
                .navigationTitle("Rehber")
        }
    }
}

struct DirectoryGridView: View {
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Directory.allCases) { directory in
                    NavigationLink(value: directory) {
                        DirectoryTile(directory: directory)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(for: Directory.self) { directory in
            DirectoryListView(directory: directory)
        }
    }
}

struct DirectoryTile: View {
    let directory: Directory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: directory.systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color.accentColor)
            Text(directory.titleTR)
                .font(.headline)
                .foregroundStyle(Color.primary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct ComingSoonView: View {
    let directory: Directory

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: directory.systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text(directory.titleTR)
                .font(.title2.bold())
            Text("Bu rehber yakında. Faz 2 kapsamında etkinleştirilecek.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(directory.titleTR)
        .navigationBarTitleDisplayMode(.inline)
    }
}
