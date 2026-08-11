import Foundation

/// Small in-memory TTL cache for hot API payloads (dashboard / sessions).
public final class MemoryTTLCache {
    public static let shared = MemoryTTLCache()

    private let lock = NSLock()
    private var store: [String: Entry] = [:]

    private struct Entry {
        let expiresAt: Date
        let data: Data
    }

    public func get(_ key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = store[key] else { return nil }
        if entry.expiresAt < Date() {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    public func set(_ key: String, data: Data, ttl: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        store[key] = Entry(expiresAt: Date().addingTimeInterval(ttl), data: data)
    }

    public func remove(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        store.removeValue(forKey: key)
    }

    public func removePrefix(_ prefix: String) {
        lock.lock()
        defer { lock.unlock() }
        store = store.filter { !$0.key.hasPrefix(prefix) }
    }
}
