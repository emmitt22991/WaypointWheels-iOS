import Foundation

@MainActor
final class ChecklistsViewModel: ObservableObject {
    @Published var checklists: [Checklist]
    @Published var householdMembers: [HouseholdMember]
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    @Published private(set) var validationErrors: [Checklist.ID: ValidationState]
    @Published private(set) var dailyChecklists: [ChecklistRun]
    @Published private(set) var dailyTargetDate: Date?
    @Published private(set) var dailyRelativeDay: Checklist.RelativeDay?
    @Published private(set) var dailyErrorMessage: String?

    private let service: ChecklistsService
    private var isUpdatingDailyItem: Bool

    init(checklists: [Checklist] = [],
         householdMembers: [HouseholdMember] = [],
         service: ChecklistsService = ChecklistsService(),
         autoLoad: Bool = true) {
        self.checklists = checklists
        self.householdMembers = householdMembers
        self.service = service
        self.isLoading = false
        self.errorMessage = nil
        self.validationErrors = [:]
        self.dailyChecklists = []
        self.dailyTargetDate = nil
        self.dailyRelativeDay = nil
        self.dailyErrorMessage = nil
        self.isUpdatingDailyItem = false

        if autoLoad {
            Task { [weak self] in
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        dailyErrorMessage = nil

        await loadLibraryData()
        await loadDailyAssignments()

        isLoading = false
    }

    @discardableResult
    func createChecklist() async -> Checklist? {
        let placeholder = Checklist(title: "New Checklist",
                                    description: "",
                                    items: [],
                                    assignedMembers: [],
                                    relativeDay: .dayBefore)
        checklists.insert(placeholder, at: 0)

        do {
            let draft = ChecklistsService.ChecklistDraft(checklist: placeholder)
            let created = try await service.createChecklist(from: draft)
            replaceChecklist(placeholder.id, with: created)
            clearValidationErrors(for: created.id)
            return created
        } catch {
            errorMessage = error.userFacingMessage
            removeChecklist(id: placeholder.id)
            return nil
        }
    }

    func removeChecklists(at offsets: IndexSet) {
        let removed = offsets
            .sorted()
            .map { index -> (index: Int, checklist: Checklist) in
                (index, checklists[index])
            }
            .reversed()

        removed.forEach { entry in
            checklists.remove(at: entry.index)
        }

        Task {
            for entry in removed.reversed() {
                do {
                    try await service.deleteChecklist(id: entry.checklist.id)
                } catch {
                    await MainActor.run {
                        errorMessage = error.userFacingMessage
                        checklists.insert(entry.checklist, at: min(entry.index, checklists.count))
                    }
                }
            }
        }
    }

    func duplicateChecklist(id: Checklist.ID) {
        guard let index = checklists.firstIndex(where: { $0.id == id }) else { return }
        let source = checklists[index]

        var duplicatedItems: [Checklist.Item] = []
        for (position, item) in source.items.enumerated() {
            duplicatedItems.append(Checklist.Item(title: item.title,
                                                  notes: item.notes,
                                                  isComplete: item.isComplete,
                                                  position: position))
        }

        let duplicate = Checklist(title: source.title + " Copy",
                                  description: source.description,
                                  items: duplicatedItems,
                                  assignedMembers: source.assignedMembers,
                                  relativeDay: source.relativeDay)
        let preparedDuplicate = sanitizedChecklist(duplicate)

        checklists.insert(preparedDuplicate, at: min(index + 1, checklists.count))

        Task {
            do {
                let draft = ChecklistsService.ChecklistDraft(checklist: preparedDuplicate)
                let created = try await service.createChecklist(from: draft)
                await MainActor.run {
                    replaceChecklist(duplicate.id, with: created)
                    clearValidationErrors(for: created.id)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.userFacingMessage
                    removeChecklist(id: duplicate.id)
                }
            }
        }
    }

    func resetChecklist(id: Checklist.ID) {
        guard let index = checklists.firstIndex(where: { $0.id == id }) else { return }
        var checklist = checklists[index]
        checklist.items = checklist.items.map { item in
            var next = item
            next.isComplete = false
            return next
        }
        normalizeItems(in: &checklist)
        checklists[index] = checklist

        Task { await persistChecklist(checklist) }
    }

    func addItem(to checklistID: Checklist.ID) {
        guard let index = checklists.firstIndex(where: { $0.id == checklistID }) else { return }
        var checklist = checklists[index]
        checklist.items.append(Checklist.Item(title: "New Item",
                                              notes: "",
                                              isComplete: false,
                                              position: checklist.items.count))
        normalizeItems(in: &checklist)
        checklists[index] = checklist

        Task { await persistChecklist(checklist) }
    }

    func removeItems(from checklistID: Checklist.ID, at offsets: IndexSet) {
        guard let index = checklists.firstIndex(where: { $0.id == checklistID }) else { return }
        var checklist = checklists[index]
        checklist.items.remove(atOffsets: offsets)
        normalizeItems(in: &checklist)
        checklists[index] = checklist

        Task { await persistChecklist(checklist) }
    }

    func moveItems(in checklistID: Checklist.ID, from source: IndexSet, to destination: Int) {
        guard let index = checklists.firstIndex(where: { $0.id == checklistID }) else { return }
        var checklist = checklists[index]
        checklist.items.move(fromOffsets: source, toOffset: destination)
        normalizeItems(in: &checklist)
        checklists[index] = checklist

        Task { await persistChecklist(checklist) }
    }

    func applyEditedChecklist(_ checklist: Checklist) {
        guard let index = checklists.firstIndex(where: { $0.id == checklist.id }) else { return }
        var updated = checklist
        normalizeItems(in: &updated)
        updated.assignedMembers.sort(by: { $0.name < $1.name })
        checklists[index] = updated

        Task { await persistChecklist(updated) }
    }

    func toggleAssignment(member: HouseholdMember, checklistID: Checklist.ID) {
        guard let index = checklists.firstIndex(where: { $0.id == checklistID }) else { return }
        var checklist = checklists[index]

        if let existingIndex = checklist.assignedMembers.firstIndex(where: { $0.id == member.id }) {
            checklist.assignedMembers.remove(at: existingIndex)
        } else {
            checklist.assignedMembers.append(member)
            checklist.assignedMembers.sort(by: { $0.name < $1.name })
        }

        checklists[index] = checklist
        Task { await persistChecklist(checklist) }
    }

    func toggleDailyItem(runID: ChecklistRun.ID, itemID: Checklist.Item.ID) {
        guard let runIndex = dailyChecklists.firstIndex(where: { $0.id == runID }) else { return }
        guard let itemIndex = dailyChecklists[runIndex].checklist.items.firstIndex(where: { $0.id == itemID }) else { return }

        dailyChecklists[runIndex].checklist.items[itemIndex].isComplete.toggle()
        let isComplete = dailyChecklists[runIndex].checklist.items[itemIndex].isComplete
        let targetDate = dailyChecklists[runIndex].targetDate
        let checklistID = dailyChecklists[runIndex].checklist.id

        Task { await updateDailyItem(checklistID: checklistID,
                                     itemID: itemID,
                                     targetDate: targetDate,
                                     isComplete: isComplete,
                                     optimisticRunIndex: runIndex) }
    }

    func validationMessage(for checklistID: Checklist.ID, field: ValidationField) -> String? {
        validationErrors[checklistID]?.message(for: field)
    }

    var featuredChecklist: Checklist? {
        checklists.first
    }
}

extension ChecklistsViewModel {
    enum ValidationField {
        case title
        case assignments
        case general
    }

    struct ValidationState {
        var title: String?
        var assignments: String?
        var general: String?

        func message(for field: ValidationField) -> String? {
            switch field {
            case .title:
                return title
            case .assignments:
                return assignments
            case .general:
                return general
            }
        }
    }
}

private extension ChecklistsViewModel {
    func loadLibraryData() async {
        do {
            async let checklistsTask = service.fetchChecklists()
            async let membersTask = service.fetchHouseholdMembers()

            let checklists = try await checklistsTask
            let members = try await membersTask

            await MainActor.run {
                self.checklists = checklists.map(sanitizedChecklist(_:))
                self.householdMembers = members.sorted(by: { $0.name < $1.name })
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.userFacingMessage
            }
        }
    }

    func loadDailyAssignments(for date: Date = Date()) async {
        do {
            let response = try await service.fetchDailyAssignments(for: date)
            await MainActor.run {
                dailyTargetDate = response.targetDate
                dailyRelativeDay = response.relativeDayContext
                dailyChecklists = response.checklists.map(sanitizedRun(_:))
                dailyErrorMessage = nil
            }
        } catch {
            await MainActor.run {
                dailyChecklists = []
                dailyTargetDate = nil
                dailyRelativeDay = nil
                dailyErrorMessage = error.userFacingMessage
            }
        }
    }

    func persistChecklist(_ checklist: Checklist) async {
        do {
            let draft = ChecklistsService.ChecklistDraft(checklist: checklist)
            let saved = try await service.updateChecklist(draft, id: checklist.id)
            await MainActor.run {
                replaceChecklist(checklist.id, with: saved)
                clearValidationErrors(for: checklist.id)
            }
        } catch {
            await MainActor.run {
                handlePersistError(error, checklistID: checklist.id)
            }
        }
    }

    func replaceChecklist(_ id: Checklist.ID, with checklist: Checklist) {
        let sanitized = sanitizedChecklist(checklist)
        if let index = checklists.firstIndex(where: { $0.id == id }) {
            checklists[index] = sanitized
        } else {
            checklists.insert(sanitized, at: 0)
        }
    }

    func removeChecklist(id: Checklist.ID) {
        if let index = checklists.firstIndex(where: { $0.id == id }) {
            checklists.remove(at: index)
        }
    }

    func normalizeItems(in checklist: inout Checklist) {
        for index in checklist.items.indices {
            checklist.items[index].position = index
        }
    }

    func sanitizedChecklist(_ checklist: Checklist) -> Checklist {
        var sanitized = checklist
        sanitized.items.sort(by: { $0.position < $1.position })
        sanitized.assignedMembers.sort(by: { $0.name < $1.name })
        normalizeItems(in: &sanitized)
        return sanitized
    }

    func sanitizedRun(_ run: ChecklistRun) -> ChecklistRun {
        var sanitized = run
        sanitized.checklist = sanitizedChecklist(run.checklist)
        return sanitized
    }

    func updateDailyItem(checklistID: Checklist.ID,
                         itemID: Checklist.Item.ID,
                         targetDate: Date,
                         isComplete: Bool,
                         optimisticRunIndex: Int) async {
        if isUpdatingDailyItem { return }
        isUpdatingDailyItem = true

        do {
            let updatedRun = try await service.setItemCompletion(checklistID: checklistID,
                                                                 itemID: itemID,
                                                                 targetDate: targetDate,
                                                                 isComplete: isComplete)
            await MainActor.run {
                replaceDailyRun(updatedRun)
                dailyErrorMessage = nil
            }
        } catch {
            await MainActor.run {
                if dailyChecklists.indices.contains(optimisticRunIndex),
                   let itemIndex = dailyChecklists[optimisticRunIndex].checklist.items.firstIndex(where: { $0.id == itemID }) {
                    dailyChecklists[optimisticRunIndex].checklist.items[itemIndex].isComplete.toggle()
                }
                dailyErrorMessage = error.userFacingMessage
            }
        }

        isUpdatingDailyItem = false
    }

    func replaceDailyRun(_ run: ChecklistRun) {
        let sanitized = sanitizedRun(run)
        if let index = dailyChecklists.firstIndex(where: { $0.id == run.id }) {
            dailyChecklists[index] = sanitized
        } else {
            dailyChecklists.append(sanitized)
        }
    }

    func handlePersistError(_ error: Error, checklistID: Checklist.ID) {
        if let serviceError = error as? ChecklistsService.ServiceError {
            switch serviceError {
            case .serverError(let message):
                applyValidationError(message: message, checklistID: checklistID)
            default:
                errorMessage = serviceError.userFacingMessage
            }
        } else {
            errorMessage = error.userFacingMessage
        }
    }

    func applyValidationError(message: String, checklistID: Checklist.ID) {
        var state = ValidationState()
        if message.localizedCaseInsensitiveContains("title") {
            state.title = friendlyValidationMessage(from: message)
        } else if message.localizedCaseInsensitiveContains("assign") ||
                    message.localizedCaseInsensitiveContains("member") {
            state.assignments = friendlyValidationMessage(from: message)
        } else {
            state.general = friendlyValidationMessage(from: message)
        }
        validationErrors[checklistID] = state
    }

    func clearValidationErrors(for checklistID: Checklist.ID) {
        validationErrors[checklistID] = nil
    }

    func friendlyValidationMessage(from message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Something went wrong. Please try again." }
        return trimmed
    }
}
