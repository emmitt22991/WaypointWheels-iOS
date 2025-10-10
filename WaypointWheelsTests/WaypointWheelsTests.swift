//
//  WaypointWheelsTests.swift
//  WaypointWheelsTests
//
//  Created by Daniel Francis on 10/9/25.
//

import Foundation
import Testing
@testable import WaypointWheels

struct WaypointWheelsTests {

    @Test("HealthService builds the /health URL relative to the base URL")
    func healthURLAppendsPath() throws {
        let service = HealthService()

        let url = try service.healthURL(from: "https://example.com/api")
        let urlWithTrailingSlash = try service.healthURL(from: "https://example.com/api/")

        #expect(url.absoluteString == "https://example.com/api/health")
        #expect(urlWithTrailingSlash.absoluteString == "https://example.com/api/health")
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
