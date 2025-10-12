import Foundation

struct Checklist: Identifiable, Hashable, Codable {
    struct Item: Identifiable, Hashable, Codable {
        let id: UUID
        var title: String
        var notes: String
        var isComplete: Bool

        init(id: UUID = UUID(), title: String, notes: String = "", isComplete: Bool = false) {
            self.id = id
            self.title = title
            self.notes = notes
            self.isComplete = isComplete
        }
    }

    let id: UUID
    var title: String
    var description: String
    var items: [Item]

    init(id: UUID = UUID(), title: String, description: String = "", items: [Item] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.items = items
    }

    var completedItemCount: Int {
        items.filter(\.isComplete).count
    }

    var completionFraction: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedItemCount) / Double(items.count)
    }

    var completionSummary: String {
        guard !items.isEmpty else { return "No items yet" }
        return "\(completedItemCount) of \(items.count) complete"
    }
}

extension Checklist {
    static let sampleData: [Checklist] = [
        Checklist(
            title: "Day-Before Departure",
            description: "Make sure the rig is ready to roll before travel day.",
            items: [
                Item(title: "Confirm campground reservation", notes: "Call the office if you haven't received the email.", isComplete: true),
                Item(title: "Top off fresh water tanks", notes: "Aim for 80% to manage weight.", isComplete: false),
                Item(title: "Stow patio setup", notes: "Roll the mat and pack chairs.", isComplete: false),
                Item(title: "Secure loose cabinets", notes: "Double-check the galley."),
                Item(title: "Review travel route", notes: "Watch for construction near exit 316."),
            ]
        ),
        Checklist(
            title: "Departure Morning",
            description: "Final sweep before hitting the road.",
            items: [
                Item(title: "Disconnect utilities", notes: "Power, water, sewer, and cable.", isComplete: false),
                Item(title: "Retract stabilizers", isComplete: false),
                Item(title: "Secure interior items", notes: "Latch drawers and doors."),
                Item(title: "Run light check", notes: "Brake, turn, and marker lights."),
            ]
        ),
        Checklist(
            title: "Arrival Setup",
            description: "Settle in and make camp comfortable.",
            items: [
                Item(title: "Level and chock", isComplete: false),
                Item(title: "Connect utilities", isComplete: false),
                Item(title: "Deploy awning", isComplete: false),
                Item(title: "Extend slides", notes: "Make sure there's clearance."),
            ]
        )
    ]
}
