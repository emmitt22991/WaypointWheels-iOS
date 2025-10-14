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
    private(set) var removeTokenCallCount: Int = 0

    func save(token: String) throws {
        savedToken = token
    }

    func fetchToken() throws -> String? {
        savedToken
    }

    func removeToken() throws {
        savedToken = nil
        removeTokenCallCount += 1
    }
}

private let tripsFixtureExpectedIDs = ["leg-1", "leg-2", "leg-3", "leg-4"]
private let tripsFixtureExpectedDistances: [Double] = [49.5, 102.0, 96.4, 205.2]

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

    @Test("APIClient builds park endpoints relative to the configured base URL")
    func requestBuildsParksEndpoint() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let client = APIClient(session: session, bundle: bundle)

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/parks")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "{\"status\": \"ok\"}".data(using: .utf8)!
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let response: SampleResponse = try await client.request(path: "parks")

        #expect(response.status == "ok")
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

    @Test("APIClient leaves credentials intact when the session expires")
    func unauthorizedResponsePreservesSession() async {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let keychain = MockKeychainStore()
        let client = APIClient(session: session, bundle: bundle, keychainStore: keychain)

        try? keychain.save(token: "persisted-token")

        var receivedNotifications: [Notification] = []
        let observer = NotificationCenter.default.addObserver(forName: .sessionExpired, object: nil, queue: nil) { notification in
            receivedNotifications.append(notification)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { MockURLProtocol.requestHandler = nil }

        do {
            let _: SampleResponse = try await client.request(path: "health")
            #expect(false, "Expected unauthorized request to throw an error")
        } catch let error as APIClient.APIError {
            switch error {
            case .invalidResponse, .serverError:
                break
            default:
                #expect(false, "Unexpected APIError: \(error)")
            }
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }

        #expect(keychain.savedToken == "persisted-token")
        #expect(keychain.removeTokenCallCount == 0)
        #expect(receivedNotifications.isEmpty)
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

    private var sampleLegJSON: String {
        """
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
        """
    }

    @Test("TripsService requests the current itinerary and decodes legs")
    func fetchCurrentItineraryRequestsTripsEndpoint() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)

        let payload = loadFixtureData(named: "trips_current")

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/trips/current/")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let itinerary = try await service.fetchCurrentItinerary()

        #expect(itinerary.count == tripsFixtureExpectedIDs.count)
        #expect(itinerary.map(\.id) == tripsFixtureExpectedIDs)

        for (leg, expectedDistance) in zip(itinerary, tripsFixtureExpectedDistances) {
            #expect(abs(leg.distanceInMiles - expectedDistance) < 0.0001)
        }

        let firstLeg = try #require(itinerary.first)
        #expect(firstLeg.start.id == "loc-new-braunfels")
        #expect(abs(firstLeg.start.coordinate.latitude - 29.703) < 0.0001)
        #expect(abs(firstLeg.end.coordinate.longitude + 97.7404) < 0.0001)
    }

    @Test("TripsService decodes itineraries when the response is an array of legs")
    func fetchCurrentItineraryDecodesRootArray() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)

        let payload = """
        [
            \(sampleLegJSON)
        ]
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

    @Test("TripsService decodes itineraries when wrapped in a trip object")
    func fetchCurrentItineraryDecodesNestedTrip() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)

        let payload = """
        {
            "trip": {
                "itinerary": {
                    "legs": [
                        \(sampleLegJSON)
                    ]
                }
            }
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

    @Test("TripsService decodes itineraries wrapped in data/current_trip envelope")
    func fetchCurrentItineraryDecodesProductionEnvelope() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)

        let payload = """
        {
            "data": {
                "current_trip": {
                    "itinerary": {
                        "legs": [
                            \(sampleLegJSON)
                        ]
                    }
                }
            }
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

    @Test("TripsService treats empty itinerary responses as no legs")
    func fetchCurrentItineraryHandlesEmptyPayload() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/trips/current/")
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { MockURLProtocol.requestHandler = nil }

        let itinerary = try await service.fetchCurrentItinerary()

        #expect(itinerary.isEmpty)
    }

    @Test("TripsService exposes the raw itinerary payload for debugging")
    func fetchCurrentItineraryResultReturnsRawResponse() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)

        let payload = """
        {
            "legs": []
        }
        """.data(using: .utf8)!
        let expectedString = try #require(String(data: payload, encoding: .utf8))

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let result = try await service.fetchCurrentItineraryResult()

        #expect(result.legs.isEmpty)
        #expect(result.rawResponse == expectedString)
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
            switch error {
            case let .serverError(message, rawBody):
                #expect(message == "Trips unavailable")
                #expect(rawBody == "{\"message\": \"Trips unavailable\"}")
            default:
                #expect(false, "Unexpected TripsError: \(error)")
            }
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }
    }

    @Test("TripsService surfaces invalid responses as TripsError.invalidResponse")
    func fetchCurrentItineraryHandlesMissingLegs() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)

        let payload = """
        {
            "unexpected": []
        }
        """.data(using: .utf8)!
        let payloadString = try #require(String(data: payload, encoding: .utf8))

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        defer { MockURLProtocol.requestHandler = nil }

        do {
            _ = try await service.fetchCurrentItinerary()
            #expect(false, "Expected fetchCurrentItinerary to throw")
        } catch let error as TripsService.TripsError {
            switch error {
            case let .invalidResponse(rawBody):
                #expect(rawBody == payloadString)
                #expect(error.errorDescription == "Unexpected response from the trips endpoint.")
            default:
                #expect(false, "Unexpected TripsError: \(error)")
            }
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

        let payload = loadFixtureData(named: "trips_current")
        let payloadString = try #require(String(data: payload, encoding: .utf8))

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
        #expect(viewModel.itinerary.count == tripsFixtureExpectedIDs.count)
        #expect(viewModel.itinerary.map(\.id) == tripsFixtureExpectedIDs)

        for (leg, expectedDistance) in zip(viewModel.itinerary, tripsFixtureExpectedDistances) {
            #expect(abs(leg.distanceInMiles - expectedDistance) < 0.0001)
        }

        #expect(viewModel.debugPayload == payloadString)
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
        #expect(viewModel.debugPayload == "{\"message\": \"Network down\"}")
    }

    @Test("TripsViewModel surfaces friendly messaging for invalid responses")
    func loadItineraryPublishesFriendlyInvalidResponseMessage() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let apiClient = APIClient(session: session, bundle: bundle)
        let service = TripsService(apiClient: apiClient)
        let viewModel = TripsViewModel(service: service)

        let payload = """
        {
            "unexpected": []
        }
        """.data(using: .utf8)!
        let payloadString = try #require(String(data: payload, encoding: .utf8))

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        defer { MockURLProtocol.requestHandler = nil }

        await viewModel.loadItinerary(forceReload: true)

        #expect(!viewModel.isLoading)
        #expect(viewModel.itinerary.isEmpty)
        #expect(viewModel.errorMessage == TripsService.TripsError.invalidResponse(rawBody: nil).errorDescription)
        #expect(viewModel.debugPayload == payloadString)
    }
}

private func loadFixtureData(named name: String, file: StaticString = #filePath) -> Data {
    let currentFileURL = URL(fileURLWithPath: String(file))
    let directory = currentFileURL
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
    let url = directory.appendingPathComponent("\(name).json")
    guard let data = try? Data(contentsOf: url) else {
        fatalError("Unable to load fixture data for \(name).json")
    }
    return data
}

@MainActor
struct SessionViewModelSignOutTests {
    @Test("SessionViewModel ignores session expiration notifications to preserve authentication")
    func sessionExpiredNotificationDoesNotSignOut() async {
        let suiteName = "SessionViewModelTests.sessionExpiredNotificationDoesNotSignOut"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let keychain = MockKeychainStore()
        try? keychain.save(token: "cached-token")
        userDefaults.set("Stored User", forKey: "com.stepstonetexas.waypointwheels.name")
        userDefaults.set("stored@example.com", forKey: "com.stepstonetexas.waypointwheels.email")

        let viewModel = SessionViewModel(apiClient: APIClient(),
                                         keychainStore: keychain,
                                         userDefaults: userDefaults,
                                         makeAuthContext: { StubAuthenticationContext(canEvaluate: false) })

        await Task.yield()

        viewModel.email = "active@example.com"
        viewModel.password = "secret"
        viewModel.userName = "Active User"
        viewModel.isAuthenticated = true
        viewModel.canUseBiometricLogin = true

        NotificationCenter.default.post(name: .sessionExpired, object: nil)
        await Task.yield()

        #expect(viewModel.isAuthenticated)
        #expect(viewModel.canUseBiometricLogin)
        #expect(viewModel.userName == "Active User")
        #expect(viewModel.email == "active@example.com")
        #expect(viewModel.password == "secret")
        #expect(keychain.savedToken == "cached-token")
        #expect(keychain.removeTokenCallCount == 0)
        #expect(userDefaults.string(forKey: "com.stepstonetexas.waypointwheels.name") == "Stored User")
        #expect(userDefaults.string(forKey: "com.stepstonetexas.waypointwheels.email") == "stored@example.com")
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
        let keychainStore = MockKeychainStore()
        try keychainStore.save(token: "persisted-token")
        let apiClient = APIClient(session: session, bundle: bundle, keychainStore: keychainStore)

        let defaults = UserDefaults(suiteName: "SessionViewModelTests_restore")!
        defaults.removePersistentDomain(forName: "SessionViewModelTests_restore")
        defaults.set("Restored User", forKey: "com.stepstonetexas.waypointwheels.name")
        defaults.set("restored@example.com", forKey: "com.stepstonetexas.waypointwheels.email")
        defer { defaults.removePersistentDomain(forName: "SessionViewModelTests_restore") }

        let expectedURL = "https://example.com/api/trips/current/"

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == expectedURL)
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer persisted-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "\"\"".data(using: .utf8)!
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let viewModel = SessionViewModel(apiClient: apiClient,
                                         keychainStore: keychainStore,
                                         userDefaults: defaults,
                                         makeAuthContext: { StubAuthenticationContext(biometryType: .touchID) })

        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(viewModel.isAuthenticated)
        #expect(viewModel.userName == "Restored User")
        #expect(viewModel.email == "restored@example.com")
        #expect(viewModel.biometricButtonTitle == "Sign In with Touch ID")
    }

    @Test("SessionViewModel hides biometric login when stored session validation fails")
    func biometricValidationFailureClearsStoredSession() async throws {
        let session = makeSession()
        let bundle = StubBundle(info: ["API_BASE_URL": "https://example.com/api"])
        let keychainStore = MockKeychainStore()
        try keychainStore.save(token: "expired-token")

        let defaults = UserDefaults(suiteName: "SessionViewModelTests_expired")!
        defaults.removePersistentDomain(forName: "SessionViewModelTests_expired")
        defaults.set("Expired User", forKey: "com.stepstonetexas.waypointwheels.name")
        defaults.set("expired@example.com", forKey: "com.stepstonetexas.waypointwheels.email")
        defer { defaults.removePersistentDomain(forName: "SessionViewModelTests_expired") }

        let apiClient = APIClient(session: session, bundle: bundle, keychainStore: keychainStore)

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/api/trips/current/")
            #expect(request.httpMethod == "GET")
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let data = "{\"message\":\"Unauthorized\"}".data(using: .utf8)!
            return (response, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let viewModel = SessionViewModel(apiClient: apiClient,
                                         keychainStore: keychainStore,
                                         userDefaults: defaults,
                                         makeAuthContext: { StubAuthenticationContext() })

        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(!viewModel.isAuthenticated)
        #expect(!viewModel.canUseBiometricLogin)
        #expect(viewModel.errorMessage == "Session expired")
        #expect(keychainStore.savedToken == nil)
    }
}
