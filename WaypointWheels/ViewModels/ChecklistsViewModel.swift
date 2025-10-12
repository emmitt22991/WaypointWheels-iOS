import Foundation

@MainActor
final class ChecklistsViewModel: ObservableObject {
    @Published var checklists: [Checklist]

    init(checklists: [Checklist] = Checklist.sampleData) {
        self.checklists = checklists
    }

    @discardableResult
    func addChecklist() -> Checklist {
        let newChecklist = Checklist(title: "New Checklist", description: "", items: [])
        checklists.insert(newChecklist, at: 0)
        return newChecklist
    }

    func removeChecklists(at offsets: IndexSet) {
        checklists.remove(atOffsets: offsets)
    }

    func duplicateChecklist(id: Checklist.ID) {
        guard let index = checklists.firstIndex(where: { $0.id == id }) else { return }
        let source = checklists[index]
        let duplicate = Checklist(title: source.title + " Copy", description: source.description, items: source.items)
        checklists.insert(duplicate, at: index + 1)
    }

    func resetChecklist(id: Checklist.ID) {
        guard let index = checklists.firstIndex(where: { $0.id == id }) else { return }
        checklists[index].items = checklists[index].items.map { item in
            var next = item
            next.isComplete = false
            return next
        }
    }

    func addItem(to checklistID: Checklist.ID) {
        guard let index = checklists.firstIndex(where: { $0.id == checklistID }) else { return }
        checklists[index].items.append(Checklist.Item(title: "New Item"))
    }

    func removeItems(from checklistID: Checklist.ID, at offsets: IndexSet) {
        guard let index = checklists.firstIndex(where: { $0.id == checklistID }) else { return }
        checklists[index].items.remove(atOffsets: offsets)
    }

    func toggleItem(_ itemID: Checklist.Item.ID, in checklistID: Checklist.ID) {
        guard let checklistIndex = checklists.firstIndex(where: { $0.id == checklistID }),
              let itemIndex = checklists[checklistIndex].items.firstIndex(where: { $0.id == itemID }) else { return }

        checklists[checklistIndex].items[itemIndex].isComplete.toggle()
    }

    var featuredChecklist: Checklist? {
        checklists.first
    }
}
