import Foundation
import XCTest

final class MockURLProtocol: URLProtocol {
    struct Response {
        let expectedMethod: String
        let expectedPath: String
        let statusCode: Int
        let headers: [String: String]
        let data: Data
    }

    static var queuedResponses: [Response] = []
    static var requestObserver: ((URLRequest) -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard !MockURLProtocol.queuedResponses.isEmpty else {
            XCTFail("No queued responses remaining for request \(request.httpMethod ?? "") \(request.url?.path ?? "")")
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let response = MockURLProtocol.queuedResponses.removeFirst()
        MockURLProtocol.requestObserver?(request)

        guard request.httpMethod == response.expectedMethod else {
            XCTFail("Expected method \(response.expectedMethod) but received \(request.httpMethod ?? "").")
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        guard let requestPath = request.url?.path, requestPath == response.expectedPath else {
            XCTFail("Expected path \(response.expectedPath) but received \(request.url?.path ?? "").")
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let httpResponse = HTTPURLResponse(url: request.url!,
                                           statusCode: response.statusCode,
                                           httpVersion: nil,
                                           headerFields: response.headers)!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func queue(_ responses: [Response]) {
        queuedResponses.append(contentsOf: responses)
    }

    static func reset() {
        queuedResponses.removeAll()
        requestObserver = nil
    }
}
