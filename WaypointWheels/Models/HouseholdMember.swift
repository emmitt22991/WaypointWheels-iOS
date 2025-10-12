import Foundation

struct HouseholdMember: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

extension HouseholdMember {
    static let sampleMembers: [HouseholdMember] = [
        HouseholdMember(name: "Avery"),
        HouseholdMember(name: "Jordan"),
        HouseholdMember(name: "Kai")
    ]
}
