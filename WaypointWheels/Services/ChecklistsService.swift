import Foundation

final class ChecklistsService {
    enum ServiceError: LocalizedError, Equatable {
        case missingConfiguration
        case invalidBaseURL(String)
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Missing API base URL configuration."
            case let .invalidBaseURL(value):
                return "Invalid API base URL: \(value)."
            case .invalidResponse:
                return "Unexpected response from the checklists endpoint."
            case let .serverError(message):
                return message
            }
        }
    }

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchChecklists() async throws -> [Checklist] {
        do {
            let response: ChecklistsIndexResponse = try await apiClient.request(path: "households/current/checklists")
            return response.checklists
        } catch let error as APIClient.APIError {
            throw ServiceError(apiError: error)
        }
    }

    func fetchHouseholdMembers() async throws -> [HouseholdMember] {
        do {
            let response: HouseholdMembersResponse = try await apiClient.request(path: "households/current/members")
            return response.members
        } catch let error as APIClient.APIError {
            throw ServiceError(apiError: error)
        }
    }

    func createChecklist(from draft: ChecklistDraft) async throws -> Checklist {
        do {
            let response: ChecklistResponse = try await apiClient.request(path: "households/current/checklists",
                                                                         method: "POST",
                                                                         body: draft)
            return response.checklist
        } catch let error as APIClient.APIError {
            throw ServiceError(apiError: error)
        }
    }

    func updateChecklist(_ checklist: ChecklistDraft, id: Checklist.ID) async throws -> Checklist {
        do {
            let response: ChecklistResponse = try await apiClient.request(path: "households/current/checklists/\(id.uuidString)",
                                                                         method: "PATCH",
                                                                         body: checklist)
            return response.checklist
        } catch let error as APIClient.APIError {
            throw ServiceError(apiError: error)
        }
    }

    func deleteChecklist(id: Checklist.ID) async throws {
        do {
            let _: EmptyResponse = try await apiClient.request(path: "households/current/checklists/\(id.uuidString)",
                                                                method: "DELETE",
                                                                body: Optional<EmptyBody>.none)
        } catch let error as APIClient.APIError {
            throw ServiceError(apiError: error)
        }
    }

    func fetchDailyAssignments(for date: Date = Date()) async throws -> DailyAssignmentsResponse {
        let dateString = ChecklistsService.dateFormatter.string(from: date)
        do {
            let response: DailyAssignmentsResponse = try await apiClient.request(path: "households/current/checklists/daily/\(dateString)")
            return response
        } catch let error as APIClient.APIError {
            throw ServiceError(apiError: error)
        }
    }

    func setItemCompletion(checklistID: Checklist.ID,
                           itemID: Checklist.Item.ID,
                           targetDate: Date,
                           isComplete: Bool) async throws -> ChecklistRun {
        let payload = ChecklistItemCompletionRequest(targetDate: ChecklistsService.dateFormatter.string(from: targetDate),
                                                     isComplete: isComplete)
        do {
            let response: ChecklistRunResponse = try await apiClient.request(path: "households/current/checklists/\(checklistID.uuidString)/items/\(itemID.uuidString)/completion",
                                                                             method: "POST",
                                                                             body: payload)
            return response.checklist
        } catch let error as APIClient.APIError {
            throw ServiceError(apiError: error)
        }
    }
}

extension ChecklistsService {
    struct ChecklistDraft: Encodable {
        let title: String
        let description: String
        let items: [ChecklistItemPayload]
        let assignedMemberIDs: [UUID]
        let relativeDay: Checklist.RelativeDay

        enum CodingKeys: String, CodingKey {
            case title
            case description
            case items
            case assignedMemberIDs = "assigned_member_ids"
            case relativeDay = "relative_day"
        }
    }

    struct ChecklistItemPayload: Encodable {
        let id: UUID
        let title: String
        let notes: String
        let isComplete: Bool
        let position: Int

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case notes
            case isComplete = "is_complete"
            case position
        }
    }

    struct ChecklistsIndexResponse: Decodable {
        let checklists: [Checklist]
    }

    struct ChecklistResponse: Decodable {
        let checklist: Checklist
    }

    struct HouseholdMembersResponse: Decodable {
        let members: [HouseholdMember]
    }

    struct DailyAssignmentsResponse: Decodable {
        let targetDate: Date
        let relativeDayContext: Checklist.RelativeDay?
        let checklists: [ChecklistRun]

        enum CodingKeys: String, CodingKey {
            case targetDate = "target_date"
            case relativeDayContext = "relative_day_context"
            case checklists
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let dateString = try container.decode(String.self, forKey: .targetDate)
            guard let date = ChecklistsService.dateFormatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(forKey: .targetDate,
                                                       in: container,
                                                       debugDescription: "Unable to decode target date \(dateString)")
            }
            targetDate = date
            relativeDayContext = try container.decodeIfPresent(Checklist.RelativeDay.self, forKey: .relativeDayContext)
            checklists = try container.decodeIfPresent([ChecklistRun].self, forKey: .checklists) ?? []
        }
    }

    struct ChecklistRunResponse: Decodable {
        let checklist: ChecklistRun
    }

    struct ChecklistItemCompletionRequest: Encodable {
        let targetDate: String
        let isComplete: Bool

        enum CodingKeys: String, CodingKey {
            case targetDate = "target_date"
            case isComplete = "is_complete"
        }
    }

    struct EmptyResponse: Decodable, EmptyDecodable {}

    struct EmptyBody: Encodable {}
}

private extension ChecklistsService.ServiceError {
    init(apiError: APIClient.APIError) {
        switch apiError {
        case .missingConfiguration:
            self = .missingConfiguration
        case let .invalidBaseURL(value):
            self = .invalidBaseURL(value)
        case .invalidResponse:
            self = .invalidResponse
        case let .serverError(message, _):
            self = .serverError(message)
        }
    }
}

extension ChecklistsService.ChecklistDraft {
    init(checklist: Checklist) {
        self.title = checklist.title
        self.description = checklist.description
        self.items = checklist.items
            .sorted(by: { $0.position < $1.position })
            .enumerated()
            .map { index, item in
                ChecklistsService.ChecklistItemPayload(id: item.id,
                                                       title: item.title,
                                                       notes: item.notes,
                                                       isComplete: item.isComplete,
                                                       position: index)
            }
        self.assignedMemberIDs = checklist.assignedMembers.map(\.id)
        self.relativeDay = checklist.relativeDay
    }
}

private extension ChecklistsService {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
