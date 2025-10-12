import Foundation
import Security

protocol KeychainStoring {
    func save(token: String) throws
    func fetchToken() throws -> String?
    func removeToken() throws
}

struct KeychainStore {
    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)
        case invalidTokenData

        var errorDescription: String? {
            switch self {
            case let .unexpectedStatus(status):
                return "Failed to access credentials (status: \(status))."
            case .invalidTokenData:
                return "Stored credentials are invalid."
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
        let query = baseQuery()

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func fetchToken() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let token = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidTokenData
            }
            return token
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func removeToken() throws {
        let query = baseQuery()
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

extension KeychainStore: KeychainStoring {}
