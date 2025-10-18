import SwiftUI

@MainActor
struct ChecklistsView: View {
    @ObservedObject var viewModel: ChecklistsViewModel

    private let backgroundGradient = LinearGradient(
        colors: [Color(red: 0.96, green: 0.97, blue: 0.99), Color(red: 0.99, green: 0.95, blue: 0.90)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        List {
            Section {
                overviewHeader
            }
            .textCase(nil)
            .listRowBackground(Color.clear)

            if let message = viewModel.dailyErrorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("We couldn't load today's checklist", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.orange)
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            Task { await viewModel.refresh() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                }
                .textCase(nil)
                .listRowBackground(Color.clear)
            }

            if viewModel.isLoading && viewModel.dailyChecklists.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading checklists…")
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
            } else if viewModel.dailyChecklists.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 44))
                            .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                        Text("No Checklist today!")
                            .font(.headline)
                        Text("We'll surface travel-day tasks when it's time to get rolling.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .listRowBackground(Color.clear)
            } else {
                Section(header: Text("Today's Tasks")) {
                    ForEach(viewModel.dailyChecklists) { run in
                        DailyChecklistCard(run: run) { itemID in
                            viewModel.toggleDailyItem(runID: run.id, itemID: itemID)
                        }
                        .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .textCase(nil)
            }
        }
        .listStyle(.plain)
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("Checklists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ChecklistManagementView(viewModel: viewModel)
                } label: {
                    Label("Edit Checklists", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("edit-checklists-button")
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let relative = viewModel.dailyRelativeDay {
                Text(relative.displayName)
                    .font(.headline)
            } else {
                Text("Today's Checklist")
                    .font(.headline)
            }

            if let date = viewModel.dailyTargetDate {
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("We gathered the travel-day assignments for your crew. Check them off as you go.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DailyChecklistCard: View {
    let run: ChecklistRun
    let toggleAction: (Checklist.Item.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(run.checklist.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                if !run.checklist.description.isEmpty {
                    Text(run.checklist.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !run.checklist.assignedMembers.isEmpty {
                    Text(run.checklist.assignedMembers.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 12) {
                ForEach(run.checklist.items) { item in
                    DailyChecklistItemRow(item: item) {
                        toggleAction(item.id)
                    }
                    .accessibilityIdentifier("daily-checklist-item-\(item.id)")
                }
            }

            HStack {
                ProgressView(value: run.completionFraction)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                Text(run.completionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DailyChecklistItemRow: View {
    let item: Checklist.Item
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isComplete ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(item.isComplete ? .secondary : .primary)
                    if !item.notes.isEmpty {
                        Text(item.notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ChecklistManagementView: View {
    @ObservedObject var viewModel: ChecklistsViewModel

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("checklists-error-message")
                }
            }

            if viewModel.isLoading && viewModel.checklists.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }

            if viewModel.checklists.isEmpty && !viewModel.isLoading {
                Section {
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
                }
                .listRowBackground(Color.clear)
            } else {
                Section(header: Text("Checklists")) {
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Checklists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: addChecklist) {
                    Label("Add Checklist", systemImage: "plus")
                }
                .accessibilityIdentifier("add-checklist-button")
            }
            ToolbarItem(placement: .topBarLeading) {
                if !viewModel.checklists.isEmpty {
                    EditButton()
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func addChecklist() {
        Task {
            await viewModel.createChecklist()
        }
    }

    private func binding(for checklist: Checklist) -> Binding<Checklist>? {
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

            Section("Schedule") {
                Picker("Relative Day", selection: $checklist.relativeDay) {
                    ForEach(Checklist.RelativeDay.allCases) { relativeDay in
                        Text(relativeDay.displayName).tag(relativeDay)
                    }
                }
                .pickerStyle(.menu)
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
    NavigationStack {
        ChecklistsView(viewModel: ChecklistsViewModel(checklists: Checklist.sampleData,
                                                      householdMembers: HouseholdMember.sampleMembers,
                                                      autoLoad: false))
    }
}
