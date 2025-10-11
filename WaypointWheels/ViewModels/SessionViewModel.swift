import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userName: String?

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

        do {
            let response = try await apiClient.login(email: sanitizedEmail, password: currentPassword)
            try keychainStore.save(token: response.token)
            userName = response.user.name
            email = sanitizedEmail
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
