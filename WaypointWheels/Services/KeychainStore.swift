import Foundation
import Security

protocol KeychainStoring {
    func save(token: String) throws
}

struct KeychainStore {
    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case let .unexpectedStatus(status):
                return "Failed to save credentials (status: \(status))."
            }
        }
    }

    private let service: String
    private let account: String

    init(service: String = "com.stepstonetexas.waypointwheels",
         account: String = "authToken") {
        self.service = service
        self.account = account
    }

    func save(token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

extension KeychainStore: KeychainStoring {}
