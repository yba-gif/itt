import SwiftUI
import UIKit

// MARK: - CachedAsyncImage
//
// Drop-in replacement for SwiftUI's `AsyncImage` that adds a memory cache
// (NSCache, 50 MB / 200 entries) on top of `URLCache.shared` (200 MB disk
// after the app-launch bump). Once a URL has been fetched anywhere in the
// app, every subsequent render of the same URL is instant — no fade-in,
// no network call, no lazy "pop" on scroll.
//
// The phase-closure API matches AsyncImage so the existing call sites
// (ListingRow, EventDetailView, DirectoryDetailView hero) need only the
// type name swapped.

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            await update(.empty)
            return
        }

        // 1. In-memory hit — instant.
        if let cached = ImageCache.shared.image(for: url) {
            await update(.success(Image(uiImage: cached)))
            return
        }

        // 2. URLCache (disk) hit — also instant but needs a UIImage decode.
        let request = URLRequest(url: url)
        if let cachedResp = URLCache.shared.cachedResponse(for: request),
           let img = UIImage(data: cachedResp.data) {
            ImageCache.shared.set(img, for: url)
            await update(.success(Image(uiImage: img)))
            return
        }

        // 3. Network. Falls through URLSession.shared (which writes back to
        // URLCache automatically based on response Cache-Control headers).
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let img = UIImage(data: data) else {
                await update(.failure(URLError(.cannotDecodeContentData)))
                return
            }
            ImageCache.shared.set(img, for: url)
            await update(.success(Image(uiImage: img)))
        } catch {
            await update(.failure(error))
        }
    }

    @MainActor
    private func update(_ newPhase: AsyncImagePhase) {
        phase = newPhase
    }
}

// MARK: - ImageCache
//
// Process-wide in-memory image cache. Auto-evicts under memory pressure
// (NSCache integrates with UIApplication memory warnings).

final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        let bytes = (image.cgImage?.bytesPerRow ?? 4) * (image.cgImage?.height ?? 0)
        cache.setObject(image, forKey: url as NSURL, cost: max(bytes, 4096))
    }
}

// MARK: - URLCache bump
//
// Call this once at app launch (`ITTRehberApp.init`) to give the on-disk
// cache enough room for the ~300 listing thumbnails + a few hero images.

enum URLCacheBoost {
    static func install() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50 MB
            diskCapacity: 200 * 1024 * 1024,    // 200 MB
            diskPath: nil
        )
    }
}
