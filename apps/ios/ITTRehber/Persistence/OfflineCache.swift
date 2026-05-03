import Foundation

/// Simple JSON-on-disk offline cache for last-viewed directory results and emergency data.
/// Phase 2 will replace this with SwiftData; the API surface stays the same.
@MainActor
final class OfflineCache: ObservableObject {
    static let shared = OfflineCache()

    private let fileManager = FileManager.default
    private let cacheURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Published var lastListingsByDirectory: [String: [Listing]] = [:]

    init() {
        let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("itt-cache", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.cacheURL = dir
        loadAll()
    }

    func saveListings(_ listings: [Listing], for directory: Directory) {
        lastListingsByDirectory[directory.rawValue] = listings
        let url = cacheURL.appendingPathComponent("listings-\(directory.rawValue).json")
        if let data = try? encoder.encode(listings) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func cachedListings(for directory: Directory) -> [Listing] {
        lastListingsByDirectory[directory.rawValue] ?? []
    }

    private func loadAll() {
        for directory in Directory.allCases {
            let url = cacheURL.appendingPathComponent("listings-\(directory.rawValue).json")
            if let data = try? Data(contentsOf: url),
               let cached = try? decoder.decode([Listing].self, from: data) {
                lastListingsByDirectory[directory.rawValue] = cached
            }
        }
    }
}
