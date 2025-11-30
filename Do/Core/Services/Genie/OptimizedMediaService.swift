//
//  MediaService.swift
//  Do.
//
//  Optimized media loading with caching and parallel downloads
//

import Foundation
import UIKit

class OptimizedMediaService {
    static let shared = OptimizedMediaService()
    
    // In-memory cache for images (internal for access by other managers)
    let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.name = "MediaServiceImageCache"
        cache.countLimit = 200 // Cache up to 200 images
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB limit
        return cache
    }()
    
    // Track ongoing downloads to avoid duplicates
    private var ongoingDownloads: [String: Task<UIImage?, Never>] = [:]
    private let downloadQueue = DispatchQueue(label: "com.doapp.mediaservice.downloads")
    
    // URLSession for image downloads
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // PERFORMANCE: Increased to 30s for S3 images
        config.timeoutIntervalForResource = 45 // Total timeout for resource
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB memory
            diskCapacity: 200 * 1024 * 1024    // 200MB disk
        )
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    /// Load image from URL with caching and deduplication
    /// - Parameters:
    ///   - urlString: URL string of the image
    ///   - priority: Priority for loading (thumbnail = high, full = normal)
    /// - Returns: UIImage if successful, nil otherwise
    func loadImage(from urlString: String, priority: TaskPriority = .medium) async -> UIImage? {
        // Check cache first
        if let cached = imageCache.object(forKey: urlString as NSString) {
            return cached
        }
        
        // Check if already downloading
        let existingTask = await downloadQueue.sync {
            return ongoingDownloads[urlString]
        }
        
        if let existingTask = existingTask {
            return await existingTask.value
        }
        
        // Start new download
        let task = Task(priority: priority) { () -> UIImage? in
            defer {
                Task {
                    await self.downloadQueue.sync {
                        self.ongoingDownloads.removeValue(forKey: urlString)
                    }
                }
            }
            
            guard let url = URL(string: urlString) else {
                return nil
            }
            
            // Retry logic with exponential backoff (up to 3 attempts)
            // PERFORMANCE: Improved retry logic for S3 timeout errors
            let maxRetries = 3
            
            for attempt in 1...maxRetries {
                do {
                    let (data, response) = try await session.data(from: url)
                    
                    // Verify response
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        if attempt < maxRetries {
                            // Wait before retry (exponential backoff: 0.5s, 1s, 2s)
                            let delay = UInt64(0.5 * Double(attempt) * 1_000_000_000) // nanoseconds
                            try await Task.sleep(nanoseconds: delay)
                            continue
                        }
                        return nil
                    }
                    
                    guard let image = UIImage(data: data) else {
                        if attempt < maxRetries {
                            let delay = UInt64(0.5 * Double(attempt) * 1_000_000_000)
                            try await Task.sleep(nanoseconds: delay)
                            continue
                        }
                        return nil
                    }
                    
                    // Cache the image
                    let cost = data.count
                    self.imageCache.setObject(image, forKey: urlString as NSString, cost: cost)
                    
                    if attempt > 1 {
                        print("✅ [MediaService] Successfully loaded image after \(attempt) attempts: \(urlString)")
                    }
                    
                    return image
                } catch {
                    // Don't retry on certain errors (invalid URL, etc.)
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .badURL, .unsupportedURL, .cannotFindHost:
                            print("❌ [MediaService] Non-retryable error for \(urlString): \(error.localizedDescription)")
                            return nil
                        case .timedOut:
                            // PERFORMANCE: Special handling for timeout errors (common with S3)
                            if attempt < maxRetries {
                                // Longer delay for timeouts: 1s, 2s, 4s
                                let delay = UInt64(1.0 * Double(attempt) * 1_000_000_000) // nanoseconds
                                print("⚠️ [MediaService] Timeout on attempt \(attempt)/\(maxRetries) for \(urlString), retrying in \(Double(delay) / 1_000_000_000)s...")
                                try? await Task.sleep(nanoseconds: delay)
                                continue
                            }
                        default:
                            break
                        }
                    }
                    
                    if attempt < maxRetries {
                        // Exponential backoff: 0.5s, 1s, 2s
                        let delay = UInt64(0.5 * Double(attempt) * 1_000_000_000) // nanoseconds
                        print("⚠️ [MediaService] Attempt \(attempt)/\(maxRetries) failed for \(urlString), retrying in \(Double(delay) / 1_000_000_000)s...")
                        try? await Task.sleep(nanoseconds: delay)
                    } else {
                        print("❌ [MediaService] Failed to load image from \(urlString) after \(maxRetries) attempts: \(error.localizedDescription)")
                    }
                }
            }
            
            return nil
        }
        
        await downloadQueue.sync {
            ongoingDownloads[urlString] = task
        }
        
        return await task.value
    }
    
    /// Preload multiple images in parallel with priority
    /// - Parameters:
    ///   - urls: Array of URL strings to preload
    ///   - maxConcurrent: Maximum concurrent downloads (default: 6)
    func preloadImages(urls: [String], maxConcurrent: Int = 6) async {
        // Filter out already cached images
        let uncachedUrls = urls.filter { imageCache.object(forKey: $0 as NSString) == nil }
        
        guard !uncachedUrls.isEmpty else { return }
        
        // Load images in batches
        for batch in stride(from: 0, to: uncachedUrls.count, by: maxConcurrent) {
            let end = min(batch + maxConcurrent, uncachedUrls.count)
            let batchUrls = Array(uncachedUrls[batch..<end])
            
            await withTaskGroup(of: Void.self) { group in
                for url in batchUrls {
                    group.addTask {
                        _ = await self.loadImage(from: url)
                    }
                }
            }
        }
    }
    
    /// Clear all cached images
    func clearCache() {
        imageCache.removeAllObjects()
    }
    
    /// Get cache statistics
    func getCacheStats() -> (count: Int, memorySize: String) {
        let count = imageCache.countLimit
        let size = imageCache.totalCostLimit
        let sizeInMB = Double(size) / (1024 * 1024)
        return (count, String(format: "%.1f MB", sizeInMB))
    }
}

// MARK: - Post Media Loading Extension

extension Post {
    /// Load media for post with progressive enhancement (thumb -> medium -> large)
    /// Returns immediately with placeholder, updates as better quality loads
    mutating func loadMediaProgressive() async {
        // Prioritize loading order: thumb (fast) -> medium (balanced) -> large (high quality)
        let urls = [
            (mediaUrlThumb, TaskPriority.high),
            (mediaUrlMedium ?? mediaUrl, TaskPriority.medium),
            (mediaUrlLarge, TaskPriority.low)
        ].compactMap { url, priority -> (String, TaskPriority)? in
            guard let url = url, !url.isEmpty else { return nil }
            return (url, priority)
        }
        
        // Load progressively - start with thumbnail, upgrade to better quality
        for (urlString, priority) in urls {
            if let image = await OptimizedMediaService.shared.loadImage(from: urlString, priority: priority) {
                self.media = image
                // Don't break - keep loading better quality versions
            }
        }
    }
}

// MARK: - Batch Post Loading

extension Array where Element == Post {
    /// Load media for multiple posts in parallel
    /// - Parameter maxConcurrent: Maximum concurrent downloads (default: 10)
    /// - Note: Since Post is a struct, this doesn't mutate the array but loads images into cache
    ///         The caller should re-access the posts or use the cached images
    func loadMediaBatch(maxConcurrent: Int = 10) async {
        // Collect all thumbnail URLs for fast initial loading
        let thumbUrls = compactMap { $0.mediaUrlThumb }.filter { !$0.isEmpty }
        
        // Preload all thumbnails first (into cache)
        await OptimizedMediaService.shared.preloadImages(urls: thumbUrls, maxConcurrent: maxConcurrent)
        
        // Collect all other media URLs to preload
        var allMediaUrls: [String] = []
        for post in self {
            // Add medium quality URLs
            if let url = post.mediaUrlMedium ?? post.mediaUrl, !url.isEmpty {
                allMediaUrls.append(url)
            }
            // Add large quality URLs
            if let url = post.mediaUrlLarge, !url.isEmpty {
                allMediaUrls.append(url)
            }
        }
        
        // Preload all medium/large quality images in parallel
        await OptimizedMediaService.shared.preloadImages(urls: allMediaUrls, maxConcurrent: maxConcurrent)
        
        print("✅ Preloaded media for \(self.count) posts into cache")
    }
}

