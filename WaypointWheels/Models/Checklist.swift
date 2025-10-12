import Foundation

struct Checklist: Identifiable, Hashable, Codable {
    struct Item: Identifiable, Hashable, Codable {
        let id: UUID
        var title: String
        var notes: String
        var isComplete: Bool
        var position: Int

        init(id: UUID = UUID(),
             title: String,
             notes: String = "",
             isComplete: Bool = false,
             position: Int = 0) {
            self.id = id
            self.title = title
            self.notes = notes
            self.isComplete = isComplete
            self.position = position
        }

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case notes
            case isComplete = "is_complete"
            case position
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
            isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
            position = try container.decodeIfPresent(Int.self, forKey: .position) ?? 0
        }
    }

    let id: UUID
    var title: String
    var description: String
    var items: [Item]
    var assignedMembers: [HouseholdMember]

    init(id: UUID = UUID(),
         title: String,
         description: String = "",
         items: [Item] = [],
         assignedMembers: [HouseholdMember] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.items = items
        self.assignedMembers = assignedMembers
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case items
        case assignedMembers = "assigned_members"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
        assignedMembers = try container.decodeIfPresent([HouseholdMember].self, forKey: .assignedMembers) ?? []
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
                Item(title: "Confirm campground reservation", notes: "Call the office if you haven't received the email.", isComplete: true, position: 0),
                Item(title: "Top off fresh water tanks", notes: "Aim for 80% to manage weight.", isComplete: false, position: 1),
                Item(title: "Stow patio setup", notes: "Roll the mat and pack chairs.", isComplete: false, position: 2),
                Item(title: "Secure loose cabinets", notes: "Double-check the galley.", position: 3),
                Item(title: "Review travel route", notes: "Watch for construction near exit 316.", position: 4),
            ],
            assignedMembers: Array(HouseholdMember.sampleMembers.prefix(2))
        ),
        Checklist(
            title: "Departure Morning",
            description: "Final sweep before hitting the road.",
            items: [
                Item(title: "Disconnect utilities", notes: "Power, water, sewer, and cable.", isComplete: false, position: 0),
                Item(title: "Retract stabilizers", isComplete: false, position: 1),
                Item(title: "Secure interior items", notes: "Latch drawers and doors.", position: 2),
                Item(title: "Run light check", notes: "Brake, turn, and marker lights.", position: 3),
            ],
            assignedMembers: [HouseholdMember.sampleMembers[2]]
        ),
        Checklist(
            title: "Arrival Setup",
            description: "Settle in and make camp comfortable.",
            items: [
                Item(title: "Level and chock", isComplete: false, position: 0),
                Item(title: "Connect utilities", isComplete: false, position: 1),
                Item(title: "Deploy awning", isComplete: false, position: 2),
                Item(title: "Extend slides", notes: "Make sure there's clearance.", position: 3),
            ],
            assignedMembers: []
        )
    ]
}
