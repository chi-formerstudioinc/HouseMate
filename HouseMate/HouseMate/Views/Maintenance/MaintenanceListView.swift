// HouseMate/Views/Maintenance/MaintenanceListView.swift
import SwiftUI

struct MaintenanceListView: View {
    @Environment(AppState.self) private var appState

    // For mock UI — will be replaced with real ViewModel later
    @State private var items: [MaintenanceItem] = {
        #if DEBUG
        return MockMaintenanceData.items
        #else
        return []
        #endif
    }()
    @State private var members: [Member] = {
        #if DEBUG
        return MockMaintenanceData.members
        #else
        return []
        #endif
    }()

    @State private var selectedType: MaintenanceItemType = .repair
    @State private var selectedCategory: MaintenanceCategory? = nil
    @State private var showCompleted = false
    @State private var showLaterSection = false
    @State private var showAddForm = false
    @State private var itemToSchedule: MaintenanceItem? = nil
    @State private var itemToComplete: MaintenanceItem? = nil
    @State private var itemToEdit: MaintenanceItem? = nil
    @State private var itemToDelete: MaintenanceItem? = nil

    private let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

    // MARK: - Computed

    private var filteredItems: [MaintenanceItem] {
        items.filter { item in
            item.itemType == selectedType &&
            (selectedCategory == nil || item.category == selectedCategory)
        }
    }

    // Repair sections
    private var overdueRepairs: [MaintenanceItem] {
        filteredItems.filter { $0.repairStatus != .completed && $0.isRepairOverdue }
            .sorted { ($0.completeBy ?? .distantPast) < ($1.completeBy ?? .distantPast) }
    }
    private var openRepairs: [MaintenanceItem] {
        filteredItems.filter { $0.repairStatus == .open && !$0.isRepairOverdue }
    }
    private var scheduledRepairs: [MaintenanceItem] {
        filteredItems.filter { $0.repairStatus == .scheduled && !$0.isRepairOverdue }
    }
    private var completedRepairsLast30: [MaintenanceItem] {
        filteredItems.filter {
            $0.repairStatus == .completed &&
            ($0.lastCompletedAt ?? .distantPast) >= thirtyDaysAgo
        }
        .sorted { ($0.lastCompletedAt ?? .distantPast) > ($1.lastCompletedAt ?? .distantPast) }
    }

    // Recurring sections
    private var overdueRecurring: [MaintenanceItem] {
        filteredItems.filter { $0.isOverdue }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }
    private var upcomingRecurring: [MaintenanceItem] {
        filteredItems.filter { $0.isUpcoming }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }
    private var laterRecurring: [MaintenanceItem] {
        filteredItems.filter { !$0.isOverdue && !$0.isUpcoming && $0.repairStatus != .completed }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }
    private var completedRecurringLast30: [MaintenanceItem] {
        filteredItems.filter {
            ($0.lastCompletedAt ?? .distantPast) >= thirtyDaysAgo &&
            ($0.nextDueDate == nil || (!$0.isOverdue && !$0.isUpcoming))
        }
        .sorted { ($0.lastCompletedAt ?? .distantPast) > ($1.lastCompletedAt ?? .distantPast) }
    }

    private var categoriesWithItems: [MaintenanceCategory] {
        let used = Set(items.map(\.category))
        // Already ordered by MaintenanceCategory.allCases declaration
        return MaintenanceCategory.allCases.filter { used.contains($0) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter bar (no show/completed toggle here)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        categoryFilterChip(nil, label: "All")
                        ForEach(categoriesWithItems, id: \.self) { cat in
                            categoryFilterChip(cat, label: cat.displayName)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                .padding(.vertical, 6)

                // Type tabs
                Picker("Type", selection: $selectedType) {
                    ForEach(MaintenanceItemType.allCases, id: \.self) { type in
                        Text(tabLabel(type)).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // List content
                List {
                    switch selectedType {
                    case .repair:   repairSection
                    case .recurring: recurringSection
                    case .lifecycle: lifecycleSection
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Maintenance")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddForm = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddForm) {
            MaintenanceFormView(members: members, initialType: selectedType) { newItem in
                items.append(newItem)
            }
        }
        .sheet(item: $itemToEdit) { item in
            MaintenanceFormView(members: members, editingItem: item) { updated in
                if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                    items[idx] = updated
                }
            }
        }
        .sheet(item: $itemToSchedule) { item in
            MaintenanceScheduleSheet(item: item) { date, contractor, cost in
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].scheduledDate = date
                    items[idx].contractor = contractor
                    if item.itemType == .repair { items[idx].repairStatus = .scheduled }
                    if let cost { items[idx].estimatedCost = cost }
                }
            }
        }
        .sheet(item: $itemToComplete) { item in
            MaintenanceCompletionSheet(item: item) { actualCost in
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].lastCompletedAt = Date()
                    if item.itemType == .repair {
                        items[idx].repairStatus = .completed
                    } else {
                        items[idx].scheduledDate = nil
                    }
                    if let cost = actualCost { items[idx].actualCost = cost }
                }
            }
        }
        .alert("Delete?", isPresented: Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    items.removeAll { $0.id == item.id }
                    itemToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { itemToDelete = nil }
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Repair Section

    @ViewBuilder
    private var repairSection: some View {
        if !overdueRepairs.isEmpty {
            Section(header: sectionHeader("OVERDUE", count: overdueRepairs.count, color: .red)) {
                ForEach(overdueRepairs) { item in rowView(item) }
            }
        }
        if !openRepairs.isEmpty {
            Section(header: sectionHeader("OPEN", count: openRepairs.count, color: .orange)) {
                ForEach(openRepairs) { item in rowView(item) }
            }
        }
        if !scheduledRepairs.isEmpty {
            Section(header: sectionHeader("SCHEDULED", count: scheduledRepairs.count, color: .blue)) {
                ForEach(scheduledRepairs) { item in rowView(item) }
            }
        }
        // Completed (last 30 days) — with inline toggle
        if !completedRepairsLast30.isEmpty || showCompleted {
            Section(header: completedSectionHeader(count: completedRepairsLast30.count)) {
                if showCompleted {
                    ForEach(completedRepairsLast30) { item in rowView(item) }
                }
            }
        }
        if overdueRepairs.isEmpty && openRepairs.isEmpty && scheduledRepairs.isEmpty {
            emptyState("No repairs", icon: "wrench.and.screwdriver")
        }
    }

    // MARK: - Recurring Section

    @ViewBuilder
    private var recurringSection: some View {
        if !overdueRecurring.isEmpty {
            Section(header: sectionHeader("OVERDUE", count: overdueRecurring.count, color: .red)) {
                ForEach(overdueRecurring) { item in rowView(item) }
            }
        }
        if !upcomingRecurring.isEmpty {
            Section(header: sectionHeader("UPCOMING · Next 30 days", count: upcomingRecurring.count, color: .green)) {
                ForEach(upcomingRecurring) { item in rowView(item) }
            }
        }
        if !laterRecurring.isEmpty {
            Section(header: laterSectionHeader) {
                if showLaterSection {
                    ForEach(laterRecurring) { item in rowView(item) }
                }
            }
        }
        // Completed (last 30 days) — with inline toggle
        if !completedRecurringLast30.isEmpty || showCompleted {
            Section(header: completedSectionHeader(count: completedRecurringLast30.count)) {
                if showCompleted {
                    ForEach(completedRecurringLast30) { item in rowView(item) }
                }
            }
        }
        if overdueRecurring.isEmpty && upcomingRecurring.isEmpty && laterRecurring.isEmpty {
            emptyState("No recurring items", icon: "arrow.clockwise")
        }
    }

    // MARK: - Lifecycle Section

    @ViewBuilder
    private var lifecycleSection: some View {
        let lifecycle = filteredItems
        if lifecycle.isEmpty {
            emptyState("No lifecycle items", icon: "clock")
        } else {
            Section {
                ForEach(lifecycle) { item in rowView(item) }
            }
        }
    }

    // MARK: - Row

    private func rowView(_ item: MaintenanceItem) -> some View {
        MaintenanceItemRowView(
            item: item,
            members: members,
            onComplete: { itemToComplete = item },
            onSchedule: { itemToSchedule = item },
            onEdit: { itemToEdit = item },
            onDelete: { itemToDelete = item }
        )
        .listRowBackground(Color(.systemBackground))
    }

    // MARK: - Helpers

    private func categoryFilterChip(_ category: MaintenanceCategory?, label: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCategory == category ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundStyle(selectedCategory == category ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
    }

    private func tabLabel(_ type: MaintenanceItemType) -> String {
        let count: Int
        switch type {
        case .repair: count = items.filter { $0.itemType == .repair && $0.repairStatus != .completed }.count
        case .recurring: count = items.filter { $0.itemType == .recurring }.count
        case .lifecycle: count = items.filter { $0.itemType == .lifecycle }.count
        }
        return "\(type.displayName) \(count)"
    }

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text("·")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .textCase(nil)
    }

    /// Completed section header with inline show/hide toggle
    private func completedSectionHeader(count: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color.green).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("COMPLETED")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Text("last 30 days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                withAnimation { showCompleted.toggle() }
            } label: {
                Text(showCompleted ? "Hide" : "Show")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .textCase(nil)
    }

    private var laterSectionHeader: some View {
        Button {
            withAnimation { showLaterSection.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text("LATER THIS YEAR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(laterRecurring.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: showLaterSection ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .textCase(nil)
    }

    private func emptyState(_ message: String, icon: String) -> some View {
        Section {
            ContentUnavailableView(message, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
    }
}
