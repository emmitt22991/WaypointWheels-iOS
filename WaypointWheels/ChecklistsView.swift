import SwiftUI

struct ChecklistsView: View {
    @ObservedObject var viewModel: ChecklistsViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.checklists.isEmpty {
                    emptyState
                } else {
                    ForEach($viewModel.checklists) { $checklist in
                        NavigationLink {
                            ChecklistDetailView(checklist: $checklist, viewModel: viewModel)
                        } label: {
                            ChecklistRowView(checklist: checklist.wrappedValue)
                        }
                    }
                    .onDelete(perform: viewModel.removeChecklists)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Checklists")
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
        withAnimation {
            _ = viewModel.addChecklist()
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
            Section("Details") {
                TextField("Title", text: $checklist.title)
                    .textInputAutocapitalization(.words)
                TextField("Description", text: $checklist.description, axis: .vertical)
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
    ChecklistsView(viewModel: ChecklistsViewModel())
}
