import Foundation

struct ChecklistRun: Identifiable, Hashable, Codable {
    private static let targetDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var checklist: Checklist
    let targetDate: Date
    let relativeDay: Checklist.RelativeDay

    var id: String {
        let dateString = ChecklistRun.targetDateFormatter.string(from: targetDate)
        return "\(checklist.id.uuidString)-\(dateString)"
    }

    init(checklist: Checklist, targetDate: Date, relativeDay: Checklist.RelativeDay) {
        self.checklist = checklist
        self.targetDate = targetDate
        self.relativeDay = relativeDay
    }

    enum CodingKeys: String, CodingKey {
        case checklist
        case targetDate = "target_date"
        case relativeDay = "relative_day"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checklist = try container.decode(Checklist.self, forKey: .checklist)
        relativeDay = try container.decodeIfPresent(Checklist.RelativeDay.self, forKey: .relativeDay) ?? .dayBefore

        let dateString = try container.decode(String.self, forKey: .targetDate)
        guard let date = ChecklistRun.targetDateFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .targetDate,
                                                   in: container,
                                                   debugDescription: "Unable to decode target date \(dateString)")
        }
        targetDate = date
    }

    func formattedTargetDate(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: targetDate)
    }

    var completionFraction: Double {
        checklist.completionFraction
    }

    var completionSummary: String {
        checklist.completionSummary
    }
}
