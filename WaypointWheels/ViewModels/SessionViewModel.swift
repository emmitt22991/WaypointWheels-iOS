import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userName: String?

    private let apiClient: APIClient
    private let keychainStore: KeychainStore

    init(apiClient: APIClient = APIClient(),
         keychainStore: KeychainStore = KeychainStore()) {
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
    private func signInTask() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiClient.login(email: email, password: password)
            try keychainStore.save(token: response.token)
            userName = response.user.name
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
