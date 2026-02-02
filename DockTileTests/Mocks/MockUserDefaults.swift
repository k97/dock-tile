import Foundation

/// Protocol for UserDefaults abstraction to enable testing
protocol UserDefaultsProtocol {
    func string(forKey defaultName: String) -> String?
    func integer(forKey defaultName: String) -> Int
    func bool(forKey defaultName: String) -> Bool
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
    func synchronize() -> Bool
}

// Conform UserDefaults to our protocol
extension UserDefaults: UserDefaultsProtocol {}

/// In-memory mock implementation of UserDefaults for testing
final class MockUserDefaults: UserDefaultsProtocol, @unchecked Sendable {

    // MARK: - State

    /// In-memory storage
    private var storage: [String: Any] = [:]

    /// Track method calls for verification
    var setCalls: [(key: String, value: Any?)] = []
    var removeObjectCalls: [String] = []
    var synchronizeCalls = 0

    // MARK: - Initialization

    init(initialValues: [String: Any] = [:]) {
        storage = initialValues
    }

    // MARK: - UserDefaultsProtocol

    func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    func integer(forKey defaultName: String) -> Int {
        storage[defaultName] as? Int ?? 0
    }

    func bool(forKey defaultName: String) -> Bool {
        storage[defaultName] as? Bool ?? false
    }

    func object(forKey defaultName: String) -> Any? {
        storage[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        setCalls.append((defaultName, value))

        if let value = value {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
    }

    func removeObject(forKey defaultName: String) {
        removeObjectCalls.append(defaultName)
        storage.removeValue(forKey: defaultName)
    }

    func synchronize() -> Bool {
        synchronizeCalls += 1
        return true
    }

    // MARK: - Test Helpers

    /// Get all stored keys
    var allKeys: [String] {
        Array(storage.keys)
    }

    /// Clear all storage
    func reset() {
        storage.removeAll()
        setCalls.removeAll()
        removeObjectCalls.removeAll()
        synchronizeCalls = 0
    }

    /// Direct access to storage for verification
    func value(forKey key: String) -> Any? {
        storage[key]
    }
}
