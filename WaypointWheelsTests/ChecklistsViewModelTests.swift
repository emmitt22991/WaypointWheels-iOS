import XCTest
@testable import WaypointWheels

@MainActor
final class ChecklistsViewModelTests: XCTestCase {
    private var apiClient: APIClient!
    private var service: ChecklistsService!
    private var viewModel: ChecklistsViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockURLProtocol.reset()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        apiClient = APIClient(session: session,
                              bundle: .main,
                              baseURL: URL(string: "https://example.com/api")!,
                              keychainStore: nil)
        service = ChecklistsService(apiClient: apiClient)
        viewModel = ChecklistsViewModel(service: service, autoLoad: false)
    }

    override func tearDownWithError() throws {
        viewModel = nil
        service = nil
        apiClient = nil
        MockURLProtocol.reset()
        try super.tearDownWithError()
    }

    func testChecklistLifecycleFlow() async throws {
        MockURLProtocol.queue([
            .init(expectedMethod: "GET",
                  expectedPath: "/households/current/checklists",
                  statusCode: 200,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "checklists_index")),
            .init(expectedMethod: "GET",
                  expectedPath: "/households/current/members",
                  statusCode: 200,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "members_index"))
        ])

        await viewModel.refresh()
        XCTAssertEqual(viewModel.checklists.count, 1)
        XCTAssertEqual(viewModel.householdMembers.count, 2)
        let initialChecklistID = try XCTUnwrap(viewModel.checklists.first?.id)

        MockURLProtocol.queue([
            .init(expectedMethod: "POST",
                  expectedPath: "/households/current/checklists",
                  statusCode: 201,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "checklists_create"))
        ])

        let created = await viewModel.createChecklist()
        XCTAssertEqual(viewModel.checklists.first?.id, created?.id)
        XCTAssertEqual(viewModel.checklists.count, 2)

        let createdID = try XCTUnwrap(created?.id)

        MockURLProtocol.queue([
            .init(expectedMethod: "PATCH",
                  expectedPath: "/households/current/checklists/\(createdID.uuidString)",
                  statusCode: 200,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "checklists_update_title")),
            .init(expectedMethod: "PATCH",
                  expectedPath: "/households/current/checklists/\(createdID.uuidString)",
                  statusCode: 200,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "checklists_update_assignment")),
            .init(expectedMethod: "PATCH",
                  expectedPath: "/households/current/checklists/\(createdID.uuidString)",
                  statusCode: 200,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "checklists_update_completion"))
        ])

        var editedChecklist = try XCTUnwrap(viewModel.checklists.first(where: { $0.id == createdID }))
        editedChecklist.title = "Camp Setup"
        viewModel.applyEditedChecklist(editedChecklist)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.checklists.first?.title, "Camp Setup")

        let secondMember = try XCTUnwrap(viewModel.householdMembers.last)
        viewModel.toggleAssignment(member: secondMember, checklistID: createdID)
        try await Task.sleep(nanoseconds: 50_000_000)
        let assignedNames = try XCTUnwrap(viewModel.checklists.first(where: { $0.id == createdID })?.assignedMembers.map(\.name))
        XCTAssertTrue(assignedNames.contains(secondMember.name))

        var completionChecklist = try XCTUnwrap(viewModel.checklists.first(where: { $0.id == createdID }))
        completionChecklist.items[0].isComplete = true
        viewModel.applyEditedChecklist(completionChecklist)
        try await Task.sleep(nanoseconds: 50_000_000)
        let completedItem = try XCTUnwrap(viewModel.checklists.first(where: { $0.id == createdID })?.items.first)
        XCTAssertTrue(completedItem.isComplete)

        // Ensure the original checklist remains untouched
        let originalChecklist = try XCTUnwrap(viewModel.checklists.first(where: { $0.id == initialChecklistID }))
        XCTAssertEqual(originalChecklist.assignedMembers.count, 1)
    }

    func testValidationErrorSurfacedInline() async throws {
        MockURLProtocol.queue([
            .init(expectedMethod: "GET",
                  expectedPath: "/households/current/checklists",
                  statusCode: 200,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "checklists_index")),
            .init(expectedMethod: "GET",
                  expectedPath: "/households/current/members",
                  statusCode: 200,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "members_index"))
        ])

        await viewModel.refresh()
        let checklistID = try XCTUnwrap(viewModel.checklists.first?.id)

        MockURLProtocol.queue([
            .init(expectedMethod: "PATCH",
                  expectedPath: "/households/current/checklists/\(checklistID.uuidString)",
                  statusCode: 422,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "checklists_update_validation_error")),
            .init(expectedMethod: "PATCH",
                  expectedPath: "/households/current/checklists/\(checklistID.uuidString)",
                  statusCode: 200,
                  headers: ["Content-Type": "application/json"],
                  data: loadFixture(named: "checklists_update_title"))
        ])

        var invalidChecklist = try XCTUnwrap(viewModel.checklists.first)
        invalidChecklist.title = ""
        viewModel.applyEditedChecklist(invalidChecklist)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.validationMessage(for: checklistID, field: .title), "Title is required.")

        var validChecklist = invalidChecklist
        validChecklist.title = "Camp Setup"
        viewModel.applyEditedChecklist(validChecklist)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(viewModel.validationMessage(for: checklistID, field: .title))
        XCTAssertEqual(viewModel.checklists.first?.title, "Camp Setup")
    }

    private func loadFixture(named name: String) -> Data {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        let directory = currentFileURL.deletingLastPathComponent().appendingPathComponent("Fixtures")
        let url = directory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Unable to load fixture data for \(name).json")
        }
        return data
    }
}
