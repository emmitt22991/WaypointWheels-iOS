import Foundation
import LocalAuthentication

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userName: String?
    @Published var isAuthenticated: Bool = false
    @Published var canUseBiometricLogin: Bool = false

    var biometricButtonTitle: String {
        switch biometricType {
        case .faceID:
            return "Sign In with Face ID"
        case .touchID:
            return "Sign In with Touch ID"
        default:
            return "Sign In Securely"
        }
    }

    var biometricButtonIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }

    private let apiClient: APIClient
    private let keychainStore: any KeychainStoring
    private let userDefaults: UserDefaults
    private let makeAuthContext: @MainActor () -> LAContext
    private var storedToken: String?
    private var biometricType: LABiometryType = .none
    private var sessionExpiredObserver: NSObjectProtocol?

    private enum DefaultsKeys {
        static let email = "com.stepstonetexas.waypointwheels.email"
        static let name = "com.stepstonetexas.waypointwheels.name"
    }

    init(apiClient: APIClient = APIClient(),
         keychainStore: any KeychainStoring = KeychainStore(),
         userDefaults: UserDefaults = .standard,
         makeAuthContext: @escaping @MainActor () -> LAContext = { LAContext() }) {
        self.apiClient = apiClient
        self.keychainStore = keychainStore
        self.userDefaults = userDefaults
        self.makeAuthContext = makeAuthContext

        observeSessionExpiration()
        configureStoredSession()
    }

    deinit {
        if let sessionExpiredObserver {
            NotificationCenter.default.removeObserver(sessionExpiredObserver)
        }
    }

    func signIn() {
        guard !isLoading else { return }

        Task { @MainActor [weak self] in
            await self?.signInTask()
        }
    }

    @MainActor
    func signInTask() async {
        isLoading = true
        errorMessage = nil
        isAuthenticated = false

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
            try keychainStore.save(token: response.value.token)
            storedToken = response.value.token
            userName = response.value.user.name
            email = sanitizedEmail
            password = ""
            persist(userName: response.value.user.name, email: sanitizedEmail)
            updateBiometricAvailability()
            isAuthenticated = true
        } catch {
            errorMessage = error.userFacingMessage
        }

        isLoading = false
    }

    func authenticateWithBiometrics() {
        Task { @MainActor [weak self] in
            await self?.performBiometricAuthentication(isAutomatic: false)
        }
    }

    private func configureStoredSession() {
        do {
            storedToken = try keychainStore.fetchToken()
            canUseBiometricLogin = storedToken != nil
            updateBiometricAvailability()
            if storedToken != nil {
                Task { @MainActor [weak self] in
                    await self?.performBiometricAuthentication(isAutomatic: true)
                }
            }
        } catch {
            storedToken = nil
            canUseBiometricLogin = false
        }
    }

    private func persist(userName: String, email: String) {
        userDefaults.set(userName, forKey: DefaultsKeys.name)
        userDefaults.set(email, forKey: DefaultsKeys.email)
    }

    private func restorePersistedProfile() {
        if let storedName = userDefaults.string(forKey: DefaultsKeys.name) {
            userName = storedName
        }

        if let storedEmail = userDefaults.string(forKey: DefaultsKeys.email) {
            email = storedEmail
        }
    }

    private func updateBiometricAvailability() {
        guard storedToken != nil else {
            canUseBiometricLogin = false
            biometricType = .none
            return
        }

        let context = makeAuthContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
            canUseBiometricLogin = true
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            biometricType = context.biometryType
            canUseBiometricLogin = true
        } else {
            biometricType = context.biometryType
            canUseBiometricLogin = false
        }
    }

    private func performBiometricAuthentication(isAutomatic: Bool) async {
        guard storedToken != nil else {
            canUseBiometricLogin = false
            return
        }

        let context = makeAuthContext()
        var authError: NSError?
        var policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            biometricType = context.biometryType
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            biometricType = context.biometryType
            policy = .deviceOwnerAuthentication
        } else {
            biometricType = context.biometryType
            canUseBiometricLogin = false
            if !isAutomatic, let authError {
                errorMessage = authError.userFacingMessage
            }
            return
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: "Authenticate to access Waypoint Wheels.")
            if success {
                let validationSucceeded = await resumeStoredSession()
                if validationSucceeded {
                    completeBiometricLogin()
                }
            } else if !isAutomatic {
                errorMessage = "Authentication failed."
            }
        } catch {
            if isAutomatic, let laError = error as? LAError,
               [.userCancel, .systemCancel, .appCancel].contains(laError.code) {
                return
            }

            errorMessage = error.userFacingMessage
        }
    }

    private func resumeStoredSession() async -> Bool {
        guard storedToken != nil else { return false }

        do {
            _ = try await apiClient.request(path: "trips/current/", method: "GET") as APIClient.APIResponse<Data>
            return true
        } catch is APIClient.APIError {
            invalidateStoredSession(withMessage: "Session expired")
            return false
        } catch {
            errorMessage = error.userFacingMessage
            return false
        }
    }

    private func invalidateStoredSession(withMessage message: String?) {
        storedToken = nil
        canUseBiometricLogin = false
        biometricType = .none
        isAuthenticated = false
        if let message {
            errorMessage = message
        }
        try? keychainStore.removeToken()
    }

    private func completeBiometricLogin() {
        restorePersistedProfile()
        password = ""
        isAuthenticated = true
        errorMessage = nil
        canUseBiometricLogin = true
    }

    func signOut() {
        storedToken = nil
        isLoading = false
        isAuthenticated = false
        canUseBiometricLogin = false
        biometricType = .none
        userName = nil
        email = ""
        password = ""
        errorMessage = nil

        try? keychainStore.removeToken()
        userDefaults.removeObject(forKey: DefaultsKeys.name)
        userDefaults.removeObject(forKey: DefaultsKeys.email)
    }

    private func observeSessionExpiration() {
        sessionExpiredObserver = NotificationCenter.default.addObserver(forName: .sessionExpired, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if self.isAuthenticated {
                    self.signOut()
                } else {
                    self.storedToken = nil
                    self.canUseBiometricLogin = false
                    self.biometricType = .none
                }
            }
        }
    }
}
