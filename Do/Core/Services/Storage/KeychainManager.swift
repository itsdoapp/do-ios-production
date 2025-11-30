//
//  KeychainManager.swift
//  Do
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    func clear() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - API Key Management
    
    /// Save an API key for a service (uses keychain with "GenieAPIKey_" prefix)
    func saveAPIKey(_ key: String, for service: String) -> Bool {
        let keychainKey = "GenieAPIKey_\(service)"
        return save(key, forKey: keychainKey)
    }
    
    /// Get an API key for a service (checks keychain first, then falls back to developer keys)
    func getAPIKey(for service: String) -> String? {
        let keychainKey = "GenieAPIKey_\(service)"
        
        // First try to get from keychain
        if let key = get(keychainKey), !key.isEmpty {
            return key
        }
        
        // Fall back to developer keys (from old project)
        let developerKeys: [String: String] = [
            "openai": "YOUR_OPENAI_API_KEY_HERE",
            "anthropic": "YOUR_ANTHROPIC_API_KEY_HERE",
            "google": "AIzaSyBElMsbFnJMuylk7hsdpbMacMicvT8aRyI", // From GoogleService-Info.plist
            "together": "YOUR_TOGETHER_API_KEY_HERE",
            "deepseek": "YOUR_DEEPSEEK_API_KEY_HERE"
        ]
        
        return developerKeys[service]
    }
}
