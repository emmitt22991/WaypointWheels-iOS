import Foundation

@MainActor
final class HealthViewModel: ObservableObject {
    @Published var status: String = "…"
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    private let healthService: HealthService

    init(healthService: HealthService = HealthService()) {
        self.healthService = healthService
        Task {
            await loadHealth()
        }
    }

    func loadHealth() async {
        isLoading = true
        errorMessage = nil

        do {
            let status = try await healthService.fetchHealthStatus()
            self.status = status
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
