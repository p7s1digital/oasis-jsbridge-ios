import Foundation
import JavaScriptCore

/// https://developer.mozilla.org/en-US/docs/Web/API/Storage
@objc protocol JavascriptStorageExport: JSExport {
    /// When passed a key name and value, will add that key to the storage, or update that key's value if it already exists.
    /// - Parameter key: The key for which the value should be stored.
    /// - Parameter value: The actual value as `String`.
    func setItem(_ key: String, _ value: String)

    /// When passed a key name, will return that key's value.
    /// - Parameter key: The key for which the value has been stored.
    func getItem(_ key: String) -> String?

    /// When passed a key name, will remove that key from the storage.
    /// - Parameter key: The key for which a value has been stored.
    func removeItem(_ key: String)

    /// When invoked, will empty all keys out of the storage.
    func clear()
}

/// `localStorage` implementation for JavaScriptCore.
/// - SeeAlso: https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage
@objc class LocalStorage: NSObject, JavascriptStorageExport {
    
    // MARK: Private properties
    
    private var userDefaults: UserDefaults
    
    private var namespace:String

    private var keyPrefix:String{
        return namespace + "_jsBridge"
    }
        
    /// Init
    /// - Parameters:
    ///   - namespace: A unique prefix string to differenciates between keys of different instances of LocalStorage.
    ///   - userDefaults: UserDefaults to store values 
    init(with namespace:String,
         userDefaults:UserDefaults = UserDefaults.standard) {
        self.namespace = namespace
        self.userDefaults = userDefaults
    }

    // MARK: JavascriptStorageExport

    func setItem(_ key: String, _ value: String) {
        userDefaults.set(value, forKey: "\(keyPrefix)\(key)")
    }

    func getItem(_ key: String) -> String? {
        userDefaults.value(forKey: "\(keyPrefix)\(key)") as? String
    }

    func removeItem(_ key: String) {
        userDefaults.removeObject(forKey: "\(keyPrefix)\(key)")
    }

    func clear() {
        userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(keyPrefix) }
            .forEach(userDefaults.removeObject(forKey:))
    }
}

/// `sessionStorage` implementation for JavaScriptCore.
/// - SeeAlso: https://developer.mozilla.org/en-US/docs/Web/API/Window/sessionStorage
@objc class SessionStorage: NSObject, JavascriptStorageExport {
    // MARK: Private properties

    private var storage = [String: String]()

    // MARK: JavascriptStorageExport

    func setItem(_ key: String, _ value: String) {
        storage[key] = value
    }

    func getItem(_ key: String) -> String? {
        storage[key]
    }

    func removeItem(_ key: String) {
        storage.removeValue(forKey: key)
    }

    func clear() {
        storage.removeAll()
    }
}
