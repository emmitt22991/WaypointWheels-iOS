import SwiftUI

struct ChecklistsView: View {
    @ObservedObject var viewModel: ChecklistsViewModel

    var body: some View {
        NavigationStack {
            List {
                if let message = viewModel.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("checklists-error-message")
                    }
                }

                if viewModel.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }

                if viewModel.checklists.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.checklists) { checklist in
                        if let checklistBinding = binding(for: checklist) {
                            NavigationLink {
                                ChecklistDetailView(checklist: checklistBinding, viewModel: viewModel)
                            } label: {
                                ChecklistRowView(checklist: checklist)
                            }
                        }
                    }
                    .onDelete(perform: viewModel.removeChecklists)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Checklists")
            .refreshable {
                await viewModel.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.checklists.isEmpty {
                        EditButton()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addChecklist) {
                        Label("Add Checklist", systemImage: "plus")
                    }
                    .accessibilityIdentifier("add-checklist-button")
                }
            }
        }
    }

    private func addChecklist() {
        Task {
            await viewModel.createChecklist()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Create your first checklist")
                .font(.headline)
            Text("Organize departure tasks, arrival setup, maintenance routines, or anything else that keeps your adventures rolling smoothly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowBackground(Color.clear)
    }
}

private extension ChecklistsView {
    func binding(for checklist: Checklist) -> Binding<Checklist>? {
        guard viewModel.checklists.contains(where: { $0.id == checklist.id }) else { return nil }

        return Binding(
            get: {
                guard let index = viewModel.checklists.firstIndex(where: { $0.id == checklist.id }) else {
                    return checklist
                }
                return viewModel.checklists[index]
            },
            set: { updatedChecklist in
                viewModel.applyEditedChecklist(updatedChecklist)
            }
        )
    }
}

private struct ChecklistRowView: View {
    let checklist: Checklist

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(checklist.title)
                .font(.headline)
            if !checklist.description.isEmpty {
                Text(checklist.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !checklist.assignedMembers.isEmpty {
                Text(checklist.assignedMembers.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("checklist-row-assignees")
            }

            HStack(alignment: .center, spacing: 12) {
                ProgressView(value: checklist.completionFraction)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 120)
                Text(checklist.completionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ChecklistDetailView: View {
    @Binding var checklist: Checklist
    @ObservedObject var viewModel: ChecklistsViewModel
    @FocusState private var focusedItemID: Checklist.Item.ID?

    var body: some View {
        Form {
            if let message = viewModel.validationMessage(for: checklist.id, field: .general) {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Details") {
                TextField("Title", text: $checklist.title)
                    .textInputAutocapitalization(.words)
                if let message = viewModel.validationMessage(for: checklist.id, field: .title) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("checklist-title-error")
                }
                TextField("Description", text: $checklist.description, axis: .vertical)
            }

            Section("Assign to") {
                if viewModel.householdMembers.isEmpty {
                    Text("Invite household members to assign tasks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.householdMembers) { member in
                        Button {
                            viewModel.toggleAssignment(member: member, checklistID: checklist.id)
                        } label: {
                            HStack {
                                Text(member.name)
                                Spacer()
                                if checklist.assignedMembers.contains(member) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let message = viewModel.validationMessage(for: checklist.id, field: .assignments) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("checklist-assignment-error")
                }
            }

            Section {
                if checklist.items.isEmpty {
                    Button(action: addItem) {
                        Label("Add your first item", systemImage: "plus")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach($checklist.items) { $item in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                item.isComplete.toggle()
                            } label: {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isComplete ? Color.green : Color.secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Item title", text: $item.title)
                                    .textInputAutocapitalization(.sentences)
                                    .focused($focusedItemID, equals: item.id)
                                TextField("Notes", text: $item.notes, axis: .vertical)
                                    .textInputAutocapitalization(.sentences)
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        viewModel.removeItems(from: checklist.id, at: offsets)
                    }
                    .onMove { indices, newOffset in
                        viewModel.moveItems(in: checklist.id, from: indices, to: newOffset)
                    }
                }
            } header: {
                Text("Items")
            } footer: {
                if !checklist.items.isEmpty {
                    Button(action: addItem) {
                        Label("Add item", systemImage: "plus")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle(checklist.title.isEmpty ? "Checklist" : checklist.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("Duplicate", action: duplicate)
                    Button("Reset Progress", action: reset)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            if checklist.items.isEmpty {
                addItem()
            }
        }
    }

    private func addItem() {
        withAnimation {
            viewModel.addItem(to: checklist.id)
            focusedItemID = checklist.items.last?.id
        }
    }

    private func duplicate() {
        withAnimation {
            viewModel.duplicateChecklist(id: checklist.id)
        }
    }

    private func reset() {
        withAnimation {
            viewModel.resetChecklist(id: checklist.id)
        }
    }
}

#Preview {
    ChecklistsView(viewModel: ChecklistsViewModel(checklists: Checklist.sampleData,
                                                  householdMembers: HouseholdMember.sampleMembers,
                                                  autoLoad: false))
}
