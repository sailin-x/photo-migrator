import Foundation
import IOKit
import Security

/// Service to generate and manage machine identifiers for license activation
class MachineIdentifier {
    /// Shared singleton instance
    static let shared = MachineIdentifier()
    
    /// Default hardware identifier key
    private let hardwareIdKey = "PhotoMigrator.HardwareIdentifier"
    
    /// Private initializer for singleton
    private init() {}
    
    /// Get or create the hardware identifier for this machine
    func getHardwareIdentifier() -> String {
        // First check if we already have a saved identifier
        if let savedId = getSavedIdentifier() {
            return savedId
        }
        
        // If not, generate a new one and save it
        let newId = generateHardwareIdentifier()
        saveIdentifier(newId)
        return newId
    }
    
    /// Get previously saved hardware identifier
    private func getSavedIdentifier() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: hardwareIdKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let identifier = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return identifier
    }
    
    /// Save hardware identifier to keychain
    private func saveIdentifier(_ identifier: String) {
        guard let data = identifier.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: hardwareIdKey,
            kSecValueData as String: data
        ]
        
        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Then add the new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    /// Generate a unique hardware identifier from system information
    private func generateHardwareIdentifier() -> String {
        var components: [String] = []
        
        // Get system information as unique identifiers
        
        // 1. Model identifier and serial number
        if let model = getModelIdentifier() {
            components.append(model)
        }
        
        if let serial = getHardwareSerialNumber() {
            components.append(serial)
        }
        
        // 2. UUID from IOPlatformUUID
        if let uuid = getMachineUUID() {
            components.append(uuid)
        }
        
        // 3. macOS version as an additional component
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        components.append(osVersion)
        
        // 4. Current user's username
        let username = NSUserName()
        components.append(username)
        
        // Join all components and generate a SHA-256 hash
        let combinedString = components.joined(separator: "|")
        return sha256(combinedString)
    }
    
    /// Get model identifier of the Mac
    private func getModelIdentifier() -> String? {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        
        guard size > 0 else { return nil }
        
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        
        return String(cString: model)
    }
    
    /// Get hardware serial number
    private func getHardwareSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        
        guard platformExpert != 0 else { return nil }
        
        if let serialNumber = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0) {
            return serialNumber.takeRetainedValue() as? String
        }
        
        return nil
    }
    
    /// Get machine UUID
    private func getMachineUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        
        guard platformExpert != 0 else { return nil }
        
        if let uuid = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0) {
            return uuid.takeRetainedValue() as? String
        }
        
        return nil
    }
    
    /// Create SHA-256 hash of a string
    private func sha256(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}