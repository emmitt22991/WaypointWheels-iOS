"""Simple development server exposing the endpoints expected by the iOS client.

Run with `python mock-backend/mock_api.py` to serve mock data locally.
"""
from __future__ import annotations

import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any, Dict, List
from urllib.parse import urlparse


_PARKS: List[Dict[str, Any]] = [
    {
        "id": "8f8f5c6a-9384-4f8f-8db8-9b19dbd9a1d1",
        "name": "Riverbend Retreat",
        "state": "TX",
        "city": "New Braunfels",
        "rating": 4.6,
        "description": (
            "Nestled right along the Guadalupe River, Riverbend Retreat offers oversized "
            "pull-through sites, shade from towering pecan trees, and quick access to tubing outfitters."
        ),
        "memberships": ["Thousand Trails", "Harvest Hosts"],
        "amenities": [
            {"id": "1a06319c-5d96-4cb7-9872-5b56c41b3e98", "name": "50 AMP Full Hookups", "system_image": "bolt.fill"},
            {"id": "ab0db9ec-2587-4713-b3c4-33cc04c40ae8", "name": "River Access", "system_image": "drop.fill"},
            {"id": "c2ff056f-728a-4e5f-9cbc-4a3d0aa794a7", "name": "Pool & Hot Tub", "system_image": "figure.pool.swim"},
        ],
        "featured_notes": [
            "Family favorite for summer floating trips",
            "Friendly hosts who remember returning members",
            "Reserve the riverfront premium sites early",
        ],
    },
    {
        "id": "1eb7c8a0-5ffc-4010-a8f9-5eb5410ab5bd",
        "name": "Juniper Ridge Camp",
        "state": "UT",
        "city": "Moab",
        "rating": 4.2,
        "description": (
            "Wake up to red rock views and be minutes away from both Arches and Canyonlands National Parks. "
            "Juniper Ridge balances rustic desert vibes with modern amenities."
        ),
        "memberships": ["KOA", "Passport America"],
        "amenities": [
            {"id": "a8227c52-4a13-46ae-8ef2-71f242091b32", "name": "Adventure Concierge", "system_image": "figure.hiking"},
            {"id": "ed64d3ed-ef15-4f6e-9cf3-71b15a2e1762", "name": "Camp Store", "system_image": "bag.fill"},
            {"id": "7b5f885d-7dbf-4f53-8c61-3d0c364f6919", "name": "Desert Wi-Fi Lounge", "system_image": "wifi"},
        ],
        "featured_notes": [
            "Ask for the rim-view sites when booking",
            "Pool is clutch after a day on the trails",
        ],
    },
    {
        "id": "2a934efd-1f21-4cbc-95d9-5d2b2bb00180",
        "name": "Evergreen Lakeside",
        "state": "WA",
        "city": "Leavenworth",
        "rating": 3.8,
        "description": (
            "A pine-canopied hideaway with waterfront sites on Icicle Creek. This stop is perfect for quiet mornings, "
            "paddle boarding, and quick trips into Bavarian downtown."
        ),
        "memberships": ["Thousand Trails", "Independent"],
        "amenities": [
            {"id": "d82703f9-59cb-47b7-b170-1e79968d7df8", "name": "Creekside Kayak Launch", "system_image": "sailboat.fill"},
            {"id": "050d9355-3bf0-4ed6-82ef-5f2bc4f5c790", "name": "Laundry Cottage", "system_image": "washer"},
            {"id": "9c8e33f6-4140-44c3-a984-f7b5e0d8e82f", "name": "Seasonal Events Pavilion", "system_image": "tent.2.fill"},
        ],
        "featured_notes": [
            "Shaded sites stay cooler mid-summer",
            "Limited cell service—download maps ahead",
        ],
    },
]


class MockAPIHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802 - signature defined by BaseHTTPRequestHandler
        parsed = urlparse(self.path)
        if parsed.path.rstrip("/") == "/api/parks":
            self._send_json(_PARKS)
            return

        self._send_json({"error": "Route not found"}, status=HTTPStatus.NOT_FOUND)

    def log_message(self, format: str, *args: object) -> None:  # noqa: A003 - signature defined by parent
        # Silence default logging; tests and developers can add logging if desired.
        return

    def _send_json(self, payload: Any, status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def run(host: str = "127.0.0.1", port: int = 8000) -> None:
    server = HTTPServer((host, port), MockAPIHandler)
    print(f"Mock API server listening on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down mock API server.")
    finally:
        server.server_close()


if __name__ == "__main__":
    run()
