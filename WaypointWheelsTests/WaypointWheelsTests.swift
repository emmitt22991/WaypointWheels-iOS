//
//  WaypointWheelsTests.swift
//  WaypointWheelsTests
//
//  Created by Daniel Francis on 10/9/25.
//

import Foundation
import LocalAuthentication
import Testing
@testable import WaypointWheels

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class StubBundle: Bundle {
    private let values: [String: Any]

    init(info: [String: Any]) {
        self.values = info
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func object(forInfoDictionaryKey key: String) -> Any? {
        values[key]
    }
}

final class MockKeychainStore: KeychainStoring {
    private(set) var savedToken: String?

    func save(token: String) throws {
        savedToken = token
    }

    func fetchToken() throws -> String? {
        savedToken
    }

    func removeToken() throws {
        savedToken = nil
    }
}

final class StubAuthenticationContext: LAContext {
    private let canEvaluate: Bool
    private let stubBiometryType: LABiometryType
    private let evaluationResult: Result<Bool, Error>

    init(canEvaluate: Bool = true,
         biometryType: LABiometryType = .faceID,
         evaluationResult: Result<Bool, Error> = .success(true)) {
        self.canEvaluate = canEvaluate
        self.stubBiometryType = biometryType
        self.evaluationResult = evaluationResult
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        if !canEvaluate,
           case let .failure(error) = evaluationResult {
            error?.pointee = error as NSError
        }
        return canEvaluate
    }

    override var biometryType: LABiometryType {
        stubBiometryType
    }

    override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
        switch evaluationResult {
        case let .success(success):
            reply(success, nil)
        case let .failure(error):
            reply(false, error)
        }
    }
}

struct APIClientTests {
    struct SampleResponse: Codable, Equatable {
        let status: String
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test("APIClient decodes responses relative to the configured base URL")
    func requestDecodesJSON() async throws {
        let expectedStatus = "ok"
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let client = APIClient(session: session, bundle: bundle)

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/health")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONEncoder().encode(SampleResponse(status: expectedStatus))
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let response: SampleResponse = try await client.request(path: "health")

        #expect(response.status == expectedStatus)
    }

    @Test("APIClient login builds a POST request to /login")
    func loginBuildsPostRequest() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let client = APIClient(session: session, bundle: bundle)

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/login/")
            #expect(request.httpMethod == "POST")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{""token"": ""abc"", ""user"": {""name"": ""Taylor""}}".data(using: .utf8)!
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let response = try await client.login(email: "user@example.com", password: "secret")

        #expect(response.value.token == "abc")
        #expect(response.value.user.name == "Taylor")
        #expect(response.rawString == "{\"token\":\"abc\",\"user\":{\"name\":\"Taylor\"}}")
    }

    @Test("APIClient preserves trailing slashes when building URLs")
    func requestPreservesTrailingSlash() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let client = APIClient(session: session, bundle: bundle)

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/trips/current/")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{\"status\": \"ok\"}".data(using: .utf8)!
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let response: SampleResponse = try await client.request(path: "trips/current/")

        #expect(response.status == "ok")
    }

    @Test("APIClient attaches the stored bearer token to requests")
    func requestIncludesAuthorizationHeader() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let keychain = MockKeychainStore()
        try keychain.save(token: "secret-token")
        let client = APIClient(session: session, bundle: bundle, keychainStore: keychain)

        MockURLProtocol.requestHandler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{""status"": ""ok""}".data(using: .utf8)!
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let response: SampleResponse = try await client.request(path: "health")

        #expect(response.status == "ok")
    }
}

struct HealthServiceTests {
    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test("HealthService builds the /health URL relative to the base URL")
    func healthURLAppendsPath() throws {
        let service = HealthService()

        let url = try service.healthURL(from: "https://example.com/api")
        let urlWithTrailingSlash = try service.healthURL(from: "https://example.com/api/")

        #expect(url.absoluteString == "https://example.com/api/health")
        #expect(urlWithTrailingSlash.absoluteString == "https://example.com/api/health")
    }

    @Test("HealthService fetches status via APIClient")
    func fetchHealthStatusUsesAPIClient() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = HealthService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/health")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{""status"": ""ok""}".data(using: .utf8)!
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let status = try await service.fetchHealthStatus()

        #expect(status == "ok")
    }

    @Test("HealthService maps APIClient errors")
    func fetchHealthStatusMapsErrors() async {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = HealthService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { MockURLProtocol.requestHandler = nil }

        do {
            _ = try await service.fetchHealthStatus()
            #expect(false, "Expected fetchHealthStatus to throw")
        } catch let error as HealthService.HealthError {
            switch error {
            case .invalidResponse:
                break
            default:
                #expect(false, "Unexpected HealthError: \(error)")
            }
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }
    }

    @Test("HealthService decodes status from API response with extra fields")
    func healthResponseDecodingAllowsAdditionalFields() throws {
        let json = """
        {
            "status": "ok",
            "version": "1.0.0"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(HealthService.HealthResponse.self, from: json)

        #expect(response.status == "ok")
    }
}

struct TripsServiceTests {
    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test("TripsService requests the current itinerary and decodes legs")
    func fetchCurrentItineraryRequestsTripsEndpoint() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)

        let payload = """
        {
            "legs": [
                {
                    "id": "leg-1",
                    "day_label": "Leg 1",
                    "date_range_description": "Mon · Apr 14",
                    "start": {
                        "id": "loc-austin",
                        "name": "Austin, TX",
                        "description": "Pecan Grove RV Park",
                        "coordinate": {
                            "latitude": 30.2747,
                            "longitude": -97.7404
                        }
                    },
                    "end": {
                        "id": "loc-waco",
                        "name": "Waco, TX",
                        "description": "Riverview Resort",
                        "coordinate": {
                            "latitude": 31.5493,
                            "longitude": -97.1467
                        }
                    },
                    "distance_in_miles": 102,
                    "estimated_drive_time": "1 hr 45 min",
                    "highlights": [
                        "Arrive by lunch for a riverside picnic"
                    ],
                    "notes": "Campground has limited shade — plan for awning setup."
                }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/trips/current/")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let itinerary = try await service.fetchCurrentItinerary()

        #expect(itinerary.count == 1)
        let leg = try #require(itinerary.first)
        #expect(leg.id == "leg-1")
        #expect(leg.start.id == "loc-austin")
        #expect(abs(leg.start.coordinate.latitude - 30.2747) < 0.0001)
        #expect(abs(leg.end.coordinate.longitude + 97.1467) < 0.0001)
        #expect(leg.highlights == ["Arrive by lunch for a riverside picnic"])
    }

    @Test("TripsService maps APIClient errors into TripsError")
    func fetchCurrentItineraryMapsErrors() async {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            let data = "{""message"": ""Trips unavailable""}".data(using: .utf8)!
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        do {
            _ = try await service.fetchCurrentItinerary()
            #expect(false, "Expected fetchCurrentItinerary to throw")
        } catch let error as TripsService.TripsError {
            #expect(error == .serverError("Trips unavailable"))
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }
    }
}

@MainActor
struct TripsViewModelTests {
    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test("TripsViewModel loads itinerary and updates published state")
    func loadItineraryPublishesLegs() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)
        let viewModel = TripsViewModel(service: service)

        let payload = """
        {
            "legs": [
                {
                    "id": "leg-42",
                    "day_label": "Leg 42",
                    "date_range_description": "Fri · May 2",
                    "start": {
                        "id": "loc-start",
                        "name": "Start",
                        "description": "First stop",
                        "coordinate": {"latitude": 1.0, "longitude": 2.0}
                    },
                    "end": {
                        "id": "loc-end",
                        "name": "End",
                        "description": "Final stop",
                        "coordinate": {"latitude": 3.0, "longitude": 4.0}
                    },
                    "distance_in_miles": 10,
                    "estimated_drive_time": "15 min",
                    "highlights": ["Highlight"],
                    "notes": null
                }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let task = Task {
            await viewModel.loadItinerary(forceReload: true)
        }

        await Task.yield()
        #expect(viewModel.isLoading)

        await task.value

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.itinerary.count == 1)
        #expect(viewModel.itinerary.first?.id == "leg-42")
    }

    @Test("TripsViewModel surfaces errors from the service")
    func loadItineraryPublishesErrors() async {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)
        let viewModel = TripsViewModel(service: service)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            let data = "{""message"": ""Network down""}".data(using: .utf8)!
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        await viewModel.loadItinerary(forceReload: true)

        #expect(!viewModel.isLoading)
        #expect(viewModel.itinerary.isEmpty)
        #expect(viewModel.errorMessage == "Network down")
    }
}

@MainActor
struct SessionViewModelTests {
    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test("SessionViewModel trims email whitespace before attempting login")
    func signInTrimsEmailWhitespace() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let keychainStore = MockKeychainStore()
        let viewModel = SessionViewModel(apiClient: apiClient,
                                         keychainStore: keychainStore,
                                         userDefaults: .standard,
                                         makeAuthContext: { StubAuthenticationContext(canEvaluate: false) })

        let expectedToken = "abc123"

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/login/")

            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: String] {
                #expect(json["email"] == "user@example.com")
                #expect(json["password"] == "secret")
            } else {
                #expect(false, "Expected JSON body in login request")
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """{"token":"\(expectedToken)","user":{"name":"Taylor"}}""".data(using: .utf8)!
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        viewModel.email = "  user@example.com  "
        viewModel.password = "secret"

        await viewModel.signInTask()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.userName == "Taylor")
        #expect(viewModel.email == "user@example.com")
        #expect(keychainStore.savedToken == expectedToken)
    }

    @Test("SessionViewModel validates email and password before calling the API")
    func signInValidatesInputs() async {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let keychainStore = MockKeychainStore()
        let viewModel = SessionViewModel(apiClient: apiClient,
                                         keychainStore: keychainStore,
                                         userDefaults: .standard,
                                         makeAuthContext: { StubAuthenticationContext(canEvaluate: false) })

        MockURLProtocol.requestHandler = { request in
            #expect(false, "API should not be called when inputs are invalid")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { MockURLProtocol.requestHandler = nil }

        viewModel.email = "   "
        viewModel.password = "secret"

        await viewModel.signInTask()
        #expect(viewModel.errorMessage == "Please enter your email address.")

        viewModel.email = "user@example.com"
        viewModel.password = ""

        await viewModel.signInTask()
        #expect(viewModel.errorMessage == "Please enter your password.")
    }
    
    @Test("SessionViewModel persists credentials for biometric login")
    func signInPersistsCredentialsForBiometrics() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let keychainStore = MockKeychainStore()
        let defaults = UserDefaults(suiteName: "SessionViewModelTests_persistence")!
        defaults.removePersistentDomain(forName: "SessionViewModelTests_persistence")
        defer { defaults.removePersistentDomain(forName: "SessionViewModelTests_persistence") }

        let viewModel = SessionViewModel(apiClient: apiClient,
                                         keychainStore: keychainStore,
                                         userDefaults: defaults,
                                         makeAuthContext: { StubAuthenticationContext(biometryType: .faceID) })

        let expectedToken = "storedToken"
        let expectedName = "Biometric User"
        let expectedEmail = "biometric@example.com"

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/login/")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """{"token":"\(expectedToken)","user":{"name":"\(expectedName)"}}""".data(using: .utf8)!
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        viewModel.email = expectedEmail
        viewModel.password = "secret"

        await viewModel.signInTask()

        #expect(viewModel.canUseBiometricLogin)
        #expect(viewModel.biometricButtonTitle == "Sign In with Face ID")
        #expect(defaults.string(forKey: "com.stepstonetexas.waypointwheels.name") == expectedName)
        #expect(defaults.string(forKey: "com.stepstonetexas.waypointwheels.email") == expectedEmail)
    }

    @Test("SessionViewModel restores persisted sessions using biometrics when available")
    func restoresSessionWithBiometrics() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let keychainStore = MockKeychainStore()
        try keychainStore.save(token: "persisted-token")

        let defaults = UserDefaults(suiteName: "SessionViewModelTests_restore")!
        defaults.removePersistentDomain(forName: "SessionViewModelTests_restore")
        defaults.set("Restored User", forKey: "com.stepstonetexas.waypointwheels.name")
        defaults.set("restored@example.com", forKey: "com.stepstonetexas.waypointwheels.email")
        defer { defaults.removePersistentDomain(forName: "SessionViewModelTests_restore") }

        let viewModel = SessionViewModel(apiClient: apiClient,
                                         keychainStore: keychainStore,
                                         userDefaults: defaults,
                                         makeAuthContext: { StubAuthenticationContext(biometryType: .touchID) })

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.isAuthenticated)
        #expect(viewModel.userName == "Restored User")
        #expect(viewModel.email == "restored@example.com")
        #expect(viewModel.biometricButtonTitle == "Sign In with Touch ID")
    }
}
