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

        // Build the request with a browser-like User-Agent. Some servers
        // (e.g. mfa.gov.tr) return 403 to URLSession's default UA but 200
        // to a Safari-like UA. Setting it once here is the safe default —
        // anything that doesn't care will ignore it.
        var request = URLRequest(url: url)
        request.setValue(safariUserAgent, forHTTPHeaderField: "User-Agent")

        // 2. URLCache (disk) hit — also instant but needs a UIImage decode.
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

/// Safari-ish User-Agent. Required for some image servers (e.g.
/// bern-be.mfa.gov.tr) that 403 anything else. File-private constant
/// because CachedAsyncImage is a generic type and Swift disallows
/// stored statics on generics.
private let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

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
