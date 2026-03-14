// HouseMate/Views/Maintenance/MaintenanceListView.swift
// HomeCareView — renamed from MaintenanceListView
import SwiftUI

// MARK: - Tab types (AppStorage-compatible)

enum HomeCareTab: String { case tasks, assets }
enum HomeCareTaskType: String {
    case all, chore, repair, maintenance
    var displayName: String {
        switch self {
        case .all: return "All"
        case .chore: return "Chores"
        case .repair: return "Repairs"
        case .maintenance: return "Maintenance"
        }
    }
    var itemType: MaintenanceItemType? {
        switch self {
        case .all: return nil
        case .chore: return .chore
        case .repair: return .repair
        case .maintenance: return .maintenance
        }
    }
}

struct MaintenanceListView: View {
    @Environment(AppState.self) private var appState

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

    // Persistent tab state
    @AppStorage("homeCareTab") private var activeTabRaw: String = HomeCareTab.tasks.rawValue
    @AppStorage("homeCareTaskType") private var taskTypeRaw: String = HomeCareTaskType.all.rawValue

    private var activeTab: HomeCareTab {
        get { HomeCareTab(rawValue: activeTabRaw) ?? .tasks }
        set { activeTabRaw = newValue.rawValue }
    }
    private var taskType: HomeCareTaskType {
        get { HomeCareTaskType(rawValue: taskTypeRaw) ?? .all }
        set { taskTypeRaw = newValue.rawValue }
    }

    @State private var showCompleted = false
    @State private var showLaterSection = false
    @State private var showAddForm = false
    @State private var itemToEdit: MaintenanceItem? = nil
    @State private var itemToSchedule: MaintenanceItem? = nil
    @State private var itemToComplete: MaintenanceItem? = nil
    @State private var recentlyDeleted: MaintenanceItem? = nil
    @State private var showUndoToast = false

    private let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

    // MARK: - Filtered items

    private var filteredTasks: [MaintenanceItem] {
        if taskType == .all {
            return items.filter { $0.itemType == .chore || $0.itemType == .repair || $0.itemType == .maintenance }
        }
        guard let type = taskType.itemType else { return [] }
        return items.filter { $0.itemType == type }
    }

    private var filteredAssets: [MaintenanceItem] {
        items.filter { $0.itemType == .asset }
    }

    // Chore sections
    private var overdueChores: [MaintenanceItem] {
        filteredTasks.filter { $0.isChoreOverdue }
            .sorted { ($0.choreDueDate ?? .distantFuture) < ($1.choreDueDate ?? .distantFuture) }
    }
    private var comingUpChores: [MaintenanceItem] {
        filteredTasks.filter { !$0.isChoreOverdue && $0.repairStatus != .completed }
            .sorted {
                let a = $0.choreDueDate ?? .distantFuture
                let b = $1.choreDueDate ?? .distantFuture
                return a < b
            }
    }
    private var completedChoresLast30: [MaintenanceItem] {
        filteredTasks.filter {
            $0.repairStatus == .completed &&
            ($0.lastCompletedAt ?? .distantPast) >= thirtyDaysAgo
        }
        .sorted { ($0.lastCompletedAt ?? .distantPast) > ($1.lastCompletedAt ?? .distantPast) }
    }

    // Repair sections
    private var overdueRepairs: [MaintenanceItem] {
        filteredTasks.filter { $0.repairStatus != .completed && $0.isRepairOverdue }
            .sorted { ($0.completeBy ?? .distantPast) < ($1.completeBy ?? .distantPast) }
    }
    private var openRepairs: [MaintenanceItem] {
        filteredTasks.filter { $0.repairStatus == .open && !$0.isRepairOverdue }
    }
    private var scheduledRepairs: [MaintenanceItem] {
        filteredTasks.filter { $0.repairStatus == .scheduled && !$0.isRepairOverdue }
    }
    private var completedRepairsLast30: [MaintenanceItem] {
        filteredTasks.filter {
            $0.repairStatus == .completed &&
            ($0.lastCompletedAt ?? .distantPast) >= thirtyDaysAgo
        }
        .sorted { ($0.lastCompletedAt ?? .distantPast) > ($1.lastCompletedAt ?? .distantPast) }
    }

    // Maintenance sections
    private var overdueRecurring: [MaintenanceItem] {
        filteredTasks.filter { $0.isOverdue }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }
    private var upcomingRecurring: [MaintenanceItem] {
        filteredTasks.filter { $0.isUpcoming }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }
    private var laterRecurring: [MaintenanceItem] {
        filteredTasks.filter { !$0.isOverdue && !$0.isUpcoming }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }
    private var completedMaintenanceLast30: [MaintenanceItem] {
        items.filter {
            $0.itemType == .maintenance &&
            ($0.lastCompletedAt ?? .distantPast) >= thirtyDaysAgo
        }
        .sorted { ($0.lastCompletedAt ?? .distantPast) > ($1.lastCompletedAt ?? .distantPast) }
    }

    // Combined "All" view sections
    private var allOverdueItems: [MaintenanceItem] {
        filteredTasks.filter { item in
            switch item.itemType {
            case .chore: return item.isChoreOverdue
            case .repair: return item.repairStatus != .completed && item.isRepairOverdue
            case .maintenance: return item.isOverdue
            default: return false
            }
        }
    }
    private var allActiveItems: [MaintenanceItem] {
        filteredTasks.filter { item in
            switch item.itemType {
            case .chore: return !item.isChoreOverdue && item.repairStatus != .completed
            case .repair: return item.repairStatus == .open || item.repairStatus == .scheduled
            case .maintenance: return !item.isOverdue
            default: return false
            }
        }
    }
    private var allCompletedLast30: [MaintenanceItem] {
        filteredTasks.filter { item in
            let wasCompleted = (item.repairStatus == .completed) || (item.itemType == .maintenance && item.lastCompletedAt != nil)
            return wasCompleted && (item.lastCompletedAt ?? .distantPast) >= thirtyDaysAgo
        }
        .sorted { ($0.lastCompletedAt ?? .distantPast) > ($1.lastCompletedAt ?? .distantPast) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Underline Tasks | Assets tab switcher
                underlineTabBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Divider()

                // Task sub-tabs (only in Tasks view)
                if activeTab == .tasks {
                    taskTypeChips
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                }

                // Content
                List {
                    switch activeTab {
                    case .tasks:
                        switch taskType {
                        case .all:         allTasksSection
                        case .chore:       choresSection
                        case .repair:      repairsSection
                        case .maintenance: maintenanceSection
                        }
                    case .assets:
                        assetsSection
                    }
                }
                .listStyle(.plain)
                .contentMargins(.top, 0)
            }
            .navigationTitle("Home Care")
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
            let initialType: MaintenanceItemType = (taskType.itemType ?? .chore)
            MaintenanceFormView(members: members, initialType: initialType) { newItem in
                items.append(newItem)
                switch newItem.itemType {
                case .chore:       taskTypeRaw = HomeCareTaskType.chore.rawValue
                case .repair:      taskTypeRaw = HomeCareTaskType.repair.rawValue
                case .maintenance: taskTypeRaw = HomeCareTaskType.maintenance.rawValue
                case .asset:       activeTabRaw = HomeCareTab.assets.rawValue
                }
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
                    if item.itemType == .repair || item.itemType == .chore {
                        items[idx].repairStatus = .completed
                    } else {
                        items[idx].scheduledDate = nil
                    }
                    if let cost = actualCost { items[idx].actualCost = cost }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            undoToast
        }
    }

    // MARK: - Underline tab bar

    private var underlineTabBar: some View {
        HStack(spacing: 0) {
            ForEach([HomeCareTab.tasks, .assets], id: \.rawValue) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { activeTabRaw = tab.rawValue }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab == .tasks ? "Tasks" : "Assets")
                            .font(.body.weight(activeTab == tab ? .semibold : .regular))
                            .foregroundStyle(activeTab == tab ? Color.primary : Color.secondary)
                        Rectangle()
                            .fill(activeTab == tab ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Task type chips

    private var taskTypeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([HomeCareTaskType.all, .chore, .repair, .maintenance], id: \.rawValue) { type in
                    Button {
                        withAnimation { taskTypeRaw = type.rawValue }
                        showCompleted = false
                    } label: {
                        Text(chipLabel(type))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(taskType == type ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(taskType == type ? .white : Color.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chipLabel(_ type: HomeCareTaskType) -> String {
        switch type {
        case .all:
            let active = items.filter {
                ($0.itemType == .chore || $0.itemType == .repair) && $0.repairStatus != .completed ||
                $0.itemType == .maintenance
            }.count
            return active > 0 ? "All \(active)" : "All"
        case .chore:
            let count = items.filter { $0.itemType == .chore && $0.repairStatus != .completed }.count
            return "\(type.displayName) \(count)"
        case .repair:
            let count = items.filter { $0.itemType == .repair && $0.repairStatus != .completed }.count
            return "\(type.displayName) \(count)"
        case .maintenance:
            let count = items.filter { $0.itemType == .maintenance }.count
            return "\(type.displayName) \(count)"
        }
    }

    // MARK: - All Tasks section (combined)

    @ViewBuilder
    private var allTasksSection: some View {
        if !allOverdueItems.isEmpty {
            Section(header: sectionHeader("OVERDUE", count: allOverdueItems.count, color: .red)) {
                ForEach(allOverdueItems) { item in rowView(item) }
            }
        }
        if !allActiveItems.isEmpty {
            Section(header: sectionHeader("OPEN & COMING UP", count: allActiveItems.count, color: .blue)) {
                ForEach(allActiveItems) { item in rowView(item) }
            }
        }
        if !allCompletedLast30.isEmpty || showCompleted {
            Section(header: completedSectionHeader(count: allCompletedLast30.count)) {
                if showCompleted {
                    ForEach(allCompletedLast30) { item in rowView(item) }
                }
            }
        }
        if allOverdueItems.isEmpty && allActiveItems.isEmpty {
            emptyState("No tasks", icon: "checkmark.circle")
        }
    }

    // MARK: - Chores section

    @ViewBuilder
    private var choresSection: some View {
        if !overdueChores.isEmpty {
            Section(header: sectionHeader("OVERDUE", count: overdueChores.count, color: .red)) {
                ForEach(overdueChores) { item in rowView(item) }
            }
        }
        if !comingUpChores.isEmpty {
            Section(header: sectionHeader("COMING UP", count: comingUpChores.count, color: .blue)) {
                ForEach(comingUpChores) { item in rowView(item) }
            }
        }
        if !completedChoresLast30.isEmpty || showCompleted {
            Section(header: completedSectionHeader(count: completedChoresLast30.count)) {
                if showCompleted {
                    ForEach(completedChoresLast30) { item in rowView(item) }
                }
            }
        }
        if overdueChores.isEmpty && comingUpChores.isEmpty {
            emptyState("No chores", icon: "checkmark.circle")
        }
    }

    // MARK: - Repairs section

    @ViewBuilder
    private var repairsSection: some View {
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

    // MARK: - Maintenance section

    @ViewBuilder
    private var maintenanceSection: some View {
        if !overdueRecurring.isEmpty {
            Section(header: sectionHeader("OVERDUE", count: overdueRecurring.count, color: .red)) {
                ForEach(overdueRecurring) { item in rowView(item) }
            }
        }
        if !upcomingRecurring.isEmpty {
            Section(header: sectionHeader("UPCOMING", count: upcomingRecurring.count, color: .green, subtitle: "Next 30 days")) {
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
        if !completedMaintenanceLast30.isEmpty || showCompleted {
            Section(header: completedSectionHeader(count: completedMaintenanceLast30.count)) {
                if showCompleted {
                    ForEach(completedMaintenanceLast30) { item in rowView(item) }
                }
            }
        }
        if overdueRecurring.isEmpty && upcomingRecurring.isEmpty && laterRecurring.isEmpty {
            emptyState("No maintenance items", icon: "arrow.clockwise")
        }
    }

    // MARK: - Assets section

    @ViewBuilder
    private var assetsSection: some View {
        if filteredAssets.isEmpty {
            emptyState("No assets", icon: "clock")
        } else {
            Section {
                ForEach(filteredAssets) { item in rowView(item) }
            }
        }
    }

    // MARK: - Row

    private func rowView(_ item: MaintenanceItem) -> some View {
        MaintenanceItemRowView(
            item: item,
            members: members,
            onComplete: { itemToComplete = item },
            onReopen: { reopenItem(item) },
            onSchedule: { itemToSchedule = item },
            onEdit: { itemToEdit = item },
            onDelete: { deleteItem(item) }
        )
    }

    // MARK: - Actions

    private func deleteItem(_ item: MaintenanceItem) {
        recentlyDeleted = item
        items.removeAll { $0.id == item.id }
        withAnimation(.spring()) { showUndoToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation { showUndoToast = false; recentlyDeleted = nil }
        }
    }

    private func reopenItem(_ item: MaintenanceItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            if item.itemType == .repair || item.itemType == .chore {
                items[idx].repairStatus = .open
                items[idx].lastCompletedAt = nil
            } else if item.itemType == .maintenance {
                items[idx].lastCompletedAt = nil
            }
        }
    }

    // MARK: - Undo toast

    private var undoToast: some View {
        Group {
            if showUndoToast, let item = recentlyDeleted {
                HStack {
                    Text("\"\(item.title)\" deleted")
                        .font(.footnote)
                        .lineLimit(1)
                    Spacer()
                    Button("Undo") {
                        items.append(item)
                        withAnimation { showUndoToast = false; recentlyDeleted = nil }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, count: Int, color: Color, subtitle: String? = nil) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(color)
            if let subtitle {
                Text("·").font(.caption).foregroundStyle(.secondary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Text("·").font(.caption).foregroundStyle(.secondary)
            Text("\(count)").font(.caption.weight(.bold)).foregroundStyle(.primary)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color(UIColor.systemBackground)
                .padding(.horizontal, -20)
                .padding(.top, -8)
        }
        .textCase(nil)
    }

    private func completedSectionHeader(count: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color.green).frame(width: 8, height: 8)
            Text("COMPLETED").font(.caption.weight(.semibold)).foregroundStyle(.green)
            Text("·").font(.caption).foregroundStyle(.secondary)
            Text("Last 30 days").font(.caption).foregroundStyle(.secondary)
            Text("·").font(.caption).foregroundStyle(.secondary)
            Text("\(count)").font(.caption.weight(.bold)).foregroundStyle(.primary)
            Spacer()
            Button {
                withAnimation { showCompleted.toggle() }
            } label: {
                Text(showCompleted ? "Hide" : "Show")
                    .font(.caption.weight(.medium)).foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color(UIColor.systemBackground)
                .padding(.horizontal, -20)
                .padding(.top, -8)
        }
        .textCase(nil)
    }

    private var laterSectionHeader: some View {
        Button {
            withAnimation { showLaterSection.toggle() }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(Color.secondary).frame(width: 8, height: 8)
                Text("LATER THIS YEAR").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("·").font(.caption).foregroundStyle(.secondary)
                Text("\(laterRecurring.count)").font(.caption.weight(.bold)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: showLaterSection ? "chevron.up" : "chevron.down")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Color(UIColor.systemBackground)
                    .padding(.horizontal, -20)
                    .padding(.top, -8)
            }
        }
        .textCase(nil)
    }

    private func emptyState(_ message: String, icon: String) -> some View {
        Section {
            ContentUnavailableView(message, systemImage: icon)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
        }
    }
}
