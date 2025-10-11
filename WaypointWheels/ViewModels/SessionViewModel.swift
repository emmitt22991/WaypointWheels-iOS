import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userName: String?
    @Published var requestJSON: String?
    @Published var responseJSON: String?

    private let apiClient: APIClient
    private let keychainStore: any KeychainStoring

    init(apiClient: APIClient = APIClient(),
         keychainStore: any KeychainStoring = KeychainStore()) {
        self.apiClient = apiClient
        self.keychainStore = keychainStore
    }

    func signIn() {
        guard !isLoading else { return }

        Task { [weak self] in
            await self?.signInTask()
        }
    }

    @MainActor
    func signInTask() async {
        isLoading = true
        errorMessage = nil
        requestJSON = nil
        responseJSON = nil

        let sanitizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPassword = password

        guard !sanitizedEmail.isEmpty else {
            errorMessage = "Please enter your email address."
            isLoading = false
            return
        }

        guard !currentPassword.isEmpty else {
            errorMessage = "Please enter your password."
            isLoading = false
            return
        }

        requestJSON = makeJSON(email: sanitizedEmail, password: currentPassword)

        do {
            let response = try await apiClient.login(email: sanitizedEmail, password: currentPassword)
            try keychainStore.save(token: response.value.token)
            userName = response.value.user.name
            email = sanitizedEmail
            responseJSON = response.rawString
        } catch {
            if let apiError = error as? APIClient.APIError,
               case let APIClient.APIError.serverError(_, body) = apiError {
                responseJSON = body
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func makeJSON(email: String, password: String) -> String? {
        let payload: [String: String] = [
            "email": email,
            "password": password
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
