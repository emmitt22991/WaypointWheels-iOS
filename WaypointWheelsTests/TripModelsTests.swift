import XCTest
@testable import WaypointWheels

final class TripModelsTests: XCTestCase {
    func testTripLegDecodesWithNumericAndStringDistances() throws {
        let json = """
        [
          {
            "id": "leg-numeric",
            "day_label": "Day 1",
            "date_range_description": "Jan 1",
            "start": {
              "id": "loc-start",
              "name": "Start",
              "description": "Start Location",
              "coordinate": {
                "latitude": 1.0,
                "longitude": 2.0
              }
            },
            "end": {
              "id": "loc-end",
              "name": "End",
              "description": "End Location",
              "coordinate": {
                "latitude": 3.0,
                "longitude": 4.0
              }
            },
            "distance_in_miles": 42.5,
            "estimated_drive_time": "1 hr",
            "highlights": ["One"],
            "notes": null
          },
          {
            "id": "leg-string",
            "day_label": "Day 2",
            "date_range_description": "Jan 2",
            "start": {
              "id": "loc-start-2",
              "name": "Start 2",
              "description": "Start Location 2",
              "coordinate": {
                "latitude": 5.0,
                "longitude": 6.0
              }
            },
            "end": {
              "id": "loc-end-2",
              "name": "End 2",
              "description": "End Location 2",
              "coordinate": {
                "latitude": 7.0,
                "longitude": 8.0
              }
            },
            "distance_in_miles": "55.75",
            "estimated_drive_time": "2 hr",
            "highlights": ["Two"],
            "notes": "Bring snacks"
          }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let tripLegs = try decoder.decode([TripLeg].self, from: json)

        XCTAssertEqual(tripLegs.count, 2)
        XCTAssertEqual(tripLegs[0].distanceInMiles, 42.5, accuracy: 0.0001)
        XCTAssertEqual(tripLegs[1].distanceInMiles, 55.75, accuracy: 0.0001)
    }
}
