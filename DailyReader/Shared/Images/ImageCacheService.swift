import Foundation
import Kingfisher

enum ImageCacheService {
    static let memoryCostLimit = 64 * 1024 * 1024
    static let memoryExpirationSeconds: TimeInterval = 60 * 60
    static let memoryExpiration: StorageExpiration = .seconds(memoryExpirationSeconds)
    static let diskSizeLimit: UInt = 300 * 1024 * 1024
    static let diskExpirationDays = 7
    static let diskExpiration: StorageExpiration = .days(diskExpirationDays)

    static func configure(cache: ImageCache = .default) {
        cache.memoryStorage.config.totalCostLimit = memoryCostLimit
        cache.memoryStorage.config.expiration = memoryExpiration
        cache.diskStorage.config.sizeLimit = diskSizeLimit
        cache.diskStorage.config.expiration = diskExpiration

        cache.cleanExpiredMemoryCache()
        cache.cleanExpiredDiskCache()
    }

    static func diskStorageSize(cache: ImageCache = .default) async throws -> UInt {
        try await cache.diskStorageSize
    }

    static func clearMemoryCache(cache: ImageCache = .default) {
        cache.clearMemoryCache()
    }

    static func clearDiskCache(cache: ImageCache = .default) async {
        await cache.clearDiskCache()
    }

    static func clearAll(cache: ImageCache = .default) async {
        clearMemoryCache(cache: cache)
        await clearDiskCache(cache: cache)
    }
}
