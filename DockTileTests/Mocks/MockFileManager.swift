import Foundation

/// Protocol for FileManager abstraction to enable testing
protocol FileManagerProtocol {
    func fileExists(atPath path: String) -> Bool
    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
    func copyItem(at srcURL: URL, to dstURL: URL) throws
    func removeItem(at URL: URL) throws
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func contents(atPath path: String) -> Data?
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool
    var temporaryDirectory: URL { get }
}

// Conform FileManager to our protocol
extension FileManager: FileManagerProtocol {}

/// In-memory mock implementation of FileManager for testing
final class MockFileManager: FileManagerProtocol, @unchecked Sendable {

    // MARK: - State

    /// In-memory file system: path -> (data, isDirectory)
    private var files: [String: (data: Data?, isDirectory: Bool)] = [:]

    /// Track method calls for verification
    var createDirectoryCalls: [(URL, Bool)] = []
    var copyItemCalls: [(URL, URL)] = []
    var removeItemCalls: [URL] = []

    /// Errors to inject
    var shouldThrowOnCreateDirectory = false
    var shouldThrowOnCopyItem = false
    var shouldThrowOnRemoveItem = false
    var createDirectoryError: Error?
    var copyItemError: Error?
    var removeItemError: Error?

    // MARK: - Mock Temporary Directory

    private let _temporaryDirectory: URL

    var temporaryDirectory: URL {
        _temporaryDirectory
    }

    // MARK: - Initialization

    init() {
        _temporaryDirectory = URL(fileURLWithPath: "/tmp/mock-\(UUID().uuidString)")
        // Pre-create temp directory
        files[_temporaryDirectory.path] = (nil, true)
    }

    // MARK: - FileManagerProtocol

    func fileExists(atPath path: String) -> Bool {
        files[path] != nil
    }

    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        guard let entry = files[path] else { return false }
        isDirectory?.pointee = ObjCBool(entry.isDirectory)
        return true
    }

    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws {
        createDirectoryCalls.append((url, createIntermediates))

        if shouldThrowOnCreateDirectory {
            throw createDirectoryError ?? NSError(domain: "MockFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }

        if createIntermediates {
            // Create all intermediate directories
            var currentPath = ""
            for component in url.pathComponents where component != "/" {
                currentPath += "/" + component
                files[currentPath] = (nil, true)
            }
        } else {
            files[url.path] = (nil, true)
        }
    }

    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copyItemCalls.append((srcURL, dstURL))

        if shouldThrowOnCopyItem {
            throw copyItemError ?? NSError(domain: "MockFileManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }

        guard let srcEntry = files[srcURL.path] else {
            throw NSError(domain: "MockFileManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Source not found"])
        }

        files[dstURL.path] = srcEntry
    }

    func removeItem(at url: URL) throws {
        removeItemCalls.append(url)

        if shouldThrowOnRemoveItem {
            throw removeItemError ?? NSError(domain: "MockFileManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }

        // Remove the item and all children
        let pathToRemove = url.path
        files = files.filter { !$0.key.hasPrefix(pathToRemove) }
    }

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        let parentPath = url.path

        return files.keys
            .filter { path in
                guard path.hasPrefix(parentPath), path != parentPath else { return false }
                let relativePath = String(path.dropFirst(parentPath.count + 1))
                return !relativePath.contains("/") // Only direct children
            }
            .map { URL(fileURLWithPath: $0) }
    }

    func contents(atPath path: String) -> Data? {
        files[path]?.data
    }

    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool {
        files[path] = (data, false)
        return true
    }

    // MARK: - Test Helpers

    /// Add a file to the mock file system
    func addFile(at path: String, contents: Data? = nil) {
        files[path] = (contents, false)
    }

    /// Add a directory to the mock file system
    func addDirectory(at path: String) {
        files[path] = (nil, true)
    }

    /// Clear all files
    func reset() {
        files.removeAll()
        createDirectoryCalls.removeAll()
        copyItemCalls.removeAll()
        removeItemCalls.removeAll()
    }

    /// Get all paths in the mock file system
    var allPaths: [String] {
        Array(files.keys).sorted()
    }
}
