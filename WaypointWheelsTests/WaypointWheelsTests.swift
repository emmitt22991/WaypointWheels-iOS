//
//  WaypointWheelsTests.swift
//  WaypointWheelsTests
//
//  Created by Daniel Francis on 10/9/25.
//

import Foundation
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

        #expect(response.token == "abc")
        #expect(response.user.name == "Taylor")
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
        let viewModel = SessionViewModel(apiClient: apiClient, keychainStore: keychainStore)

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
        let viewModel = SessionViewModel(apiClient: apiClient, keychainStore: keychainStore)

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
}
