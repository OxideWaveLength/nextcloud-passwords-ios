import Foundation


/// Functions for managing key-value string pairs in keychain
final class Keychain {
    
    private let service: String
    private let accessGroup: String
    
    init(service: String, accessGroup: String) {
        self.service = service
        self.accessGroup = accessGroup
    }
    
    public func store(key: String, value: String) {
        if ProcessInfo.processInfo.environment["TEST"] == "true" {
            return
        }
        
        guard let dataFromString = value.data(using: .utf8) else {
            return
        }
        var attributes = [kSecAttrService: service,
                          kSecAttrAccessGroup: accessGroup,
                          kSecClass: kSecClassGenericPassword,
                          kSecAttrAccount: key] as CFDictionary
        let attributesToUpdate = [kSecValueData: dataFromString] as CFDictionary
        let status = SecItemUpdate(attributes, attributesToUpdate)
        
        if status == errSecItemNotFound {
            attributes = [kSecAttrService: service,
                          kSecAttrAccessGroup: accessGroup,
                          kSecClass: kSecClassGenericPassword,
                          kSecAttrAccount: key,
                          kSecValueData: dataFromString] as CFDictionary
            SecItemAdd(attributes, nil)
        }
    }
    
    public func load(key: String) -> String? {
        if ProcessInfo.processInfo.environment["TEST"] == "true" {
            return nil
        }
        
        let attributes = [kSecAttrService: service,
                          kSecAttrAccessGroup: accessGroup,
                          kSecClass: kSecClassGenericPassword,
                          kSecAttrAccount: key,
                          kSecReturnData: kCFBooleanTrue!,
                          kSecMatchLimit: kSecMatchLimitOne] as CFDictionary
        var result: AnyObject?
        let status = SecItemCopyMatching(attributes, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    public func remove(key: String) {
        if ProcessInfo.processInfo.environment["TEST"] == "true" {
            return
        }
        
        let attributes = [kSecAttrService: service,
                          kSecAttrAccessGroup: accessGroup,
                          kSecClass: kSecClassGenericPassword,
                          kSecAttrAccount: key] as CFDictionary
        SecItemDelete(attributes)
    }
    
}
