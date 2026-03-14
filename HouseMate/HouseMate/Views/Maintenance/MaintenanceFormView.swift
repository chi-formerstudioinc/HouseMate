// HouseMate/Views/Maintenance/MaintenanceFormView.swift
import SwiftUI

struct MaintenanceFormView: View {
    @Environment(\.dismiss) private var dismiss

    let members: [Member]
    let onSaved: (MaintenanceItem) -> Void

    @State private var itemType: MaintenanceItemType
    @State private var title = ""
    @State private var category: MaintenanceCategory = .aroundTheHouse
    @State private var notes = ""
    @State private var assignedTo: UUID? = nil
    // Recurring
    @State private var frequency: MaintenanceFrequency = .monthly
    @State private var startDate = Date()
    @State private var requiresScheduling = false
    // Repair
    @State private var repairDescription = ""
    @State private var estimatedCostText = ""
    @State private var completeBy: Date? = nil
    @State private var showCompleteByPicker = false
    @State private var repairRequiresScheduling = false
    // Lifecycle
    @State private var installedDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    @State private var expectedLifeYears = "10"
    @State private var brand = ""
    @State private var model = ""

    private let editingItem: MaintenanceItem?
    private var isEditing: Bool { editingItem != nil }

    // Suggestions per category — for recurring tasks
    private let recurringCategorySuggestions: [MaintenanceCategory: [String]] = [
        .aroundTheHouse: ["Change Bed Sheets", "Clean Bathrooms", "Dust the House", "Deep Vacuum", "Return Items"],
        .hvac: ["Change HVAC Filter", "HVAC Tune-up", "Inspect Ducts", "Clean Vents"],
        .exterior: ["Clean Gutters", "Inspect Roof", "Power Wash Driveway", "Check Caulking"],
        .electrical: ["Check GFCIs", "Test Smoke Detectors", "Inspect Panel"],
        .plumbing: ["Check Water Heater", "Snake Drain", "Inspect Supply Lines"],
        .vehicle: ["Oil Change", "Tire Rotation", "Check Brakes", "Annual Service"],
    ]

    // Suggestions for repair tasks
    private let repairSuggestions: [String] = [
        "Fix Leaking Pipe", "Repair Broken Window", "Replace Damaged Tile",
        "Patch Drywall Hole", "Fix Stuck Door"
    ]

    init(members: [Member], initialType: MaintenanceItemType = .repair,
         editingItem: MaintenanceItem? = nil, onSaved: @escaping (MaintenanceItem) -> Void) {
        self.members = members
        self.editingItem = editingItem
        self.onSaved = onSaved
        _itemType = State(initialValue: editingItem?.itemType ?? initialType)
        if let item = editingItem {
            _title = State(initialValue: item.title)
            _category = State(initialValue: item.category)
            _notes = State(initialValue: item.notes ?? "")
            _assignedTo = State(initialValue: item.assignedTo)
            _frequency = State(initialValue: item.frequency ?? .monthly)
            _startDate = State(initialValue: item.startDate ?? Date())
            _requiresScheduling = State(initialValue: item.requiresScheduling)
            _repairDescription = State(initialValue: item.description ?? "")
            _estimatedCostText = State(initialValue: item.estimatedCost.map {
                let val = NSDecimalNumber(decimal: $0).doubleValue
                return val.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(val)) : String(format: "%.2f", val)
            } ?? "")
            _completeBy = State(initialValue: item.completeBy)
            _showCompleteByPicker = State(initialValue: item.completeBy != nil)
            _repairRequiresScheduling = State(initialValue: item.requiresScheduling)
            _installedDate = State(initialValue: item.installedDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())!)
            _expectedLifeYears = State(initialValue: item.expectedLifeYears.map { "\($0)" } ?? "10")
            _brand = State(initialValue: item.brand ?? "")
            _model = State(initialValue: item.model ?? "")
        }
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                // Type selector (only on create)
                if !isEditing {
                    Section {
                        typeSelectorCards
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Task title
                Section {
                    TextField(titlePlaceholder, text: $title)
                    // Suggestions
                    if !isEditing {
                        let suggestions = currentSuggestions
                        if !suggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions, id: \.self) { s in
                                        Button(s) { title = s }
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.accentColor.opacity(0.1))
                                            .foregroundStyle(Color.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } header: {
                    Text("Task")
                }

                // Category
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(MaintenanceCategory.allCases, id: \.self) {
                            Label($0.displayName, systemImage: $0.iconName).tag($0)
                        }
                    }
                }

                // Assign To (repair + recurring only)
                if itemType != .lifecycle {
                    Section("Assign To") {
                        Picker("Assign to", selection: $assignedTo) {
                            Text("Unassigned").tag(Optional<UUID>.none)
                            ForEach(members) { member in
                                Text(member.displayName).tag(Optional(member.id))
                            }
                        }
                    }
                }

                // Type-specific fields
                switch itemType {
                case .repair:
                    Section("Details") {
                        TextField("Description (optional)", text: $repairDescription, axis: .vertical)
                            .lineLimit(3, reservesSpace: false)
                        costField
                    }

                    Section("Scheduling") {
                        Toggle("Requires scheduling", isOn: $repairRequiresScheduling)

                        // Complete By date
                        Toggle("Set complete by date", isOn: Binding(
                            get: { showCompleteByPicker },
                            set: {
                                showCompleteByPicker = $0
                                if !$0 { completeBy = nil }
                                else if completeBy == nil { completeBy = Calendar.current.date(byAdding: .day, value: 14, to: Date()) }
                            }
                        ))
                        if showCompleteByPicker {
                            datePicker("Complete by", selection: Binding(
                                get: { completeBy ?? Date() },
                                set: { completeBy = $0 }
                            ))
                        }
                    }

                case .recurring:
                    Section("Schedule") {
                        Picker("Frequency", selection: $frequency) {
                            ForEach(MaintenanceFrequency.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        datePicker("Start date", selection: $startDate)
                        Toggle("Requires scheduling", isOn: $requiresScheduling)
                    }
                    Section("Notes") {
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: false)
                    }

                case .lifecycle:
                    Section("Appliance Details") {
                        datePicker("Installation date", selection: $installedDate)
                        TextField("Expected life (years)", text: $expectedLifeYears)
                            .keyboardType(.numberPad)
                        TextField("Brand (optional)", text: $brand)
                        TextField("Model (optional)", text: $model)
                    }
                    Section("Notes") {
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: false)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit" : "Add")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Reusable date picker with Today shortcut

    private func datePicker(_ label: String, selection: Binding<Date>) -> some View {
        HStack {
            DatePicker(label, selection: selection, displayedComponents: .date)
            if !Calendar.current.isDateInToday(selection.wrappedValue) {
                Button("Today") { selection.wrappedValue = Date() }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Currency cost field

    private var costField: some View {
        HStack(spacing: 4) {
            Text("$")
                .foregroundStyle(.secondary)
            TextField("0", text: $estimatedCostText)
                .keyboardType(.decimalPad)
                .onChange(of: estimatedCostText) { _, newVal in
                    // Allow only digits and one decimal point
                    let filtered = newVal.filter { $0.isNumber || $0 == "." }
                    let parts = filtered.components(separatedBy: ".")
                    if parts.count > 2 {
                        estimatedCostText = parts[0] + "." + parts[1]
                    } else if filtered != newVal {
                        estimatedCostText = filtered
                    }
                }
        }
    }

    // MARK: - Type selector cards

    private var typeSelectorCards: some View {
        HStack(spacing: 8) {
            ForEach(MaintenanceItemType.allCases, id: \.self) { type in
                Button { itemType = type } label: {
                    VStack(spacing: 6) {
                        Image(systemName: typeIcon(type))
                            .font(.title2)
                            .foregroundStyle(itemType == type ? .white : Color.accentColor)
                        Text(type.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(itemType == type ? .white : .primary)
                        Text(typeSubtitle(type))
                            .font(.caption2)
                            .foregroundStyle(itemType == type ? .white.opacity(0.8) : .secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(itemType == type ? Color.accentColor : Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var titlePlaceholder: String {
        switch itemType {
        case .repair: return "e.g. Fix leaking pipe"
        case .recurring: return "e.g. Change bed sheets"
        case .lifecycle: return "e.g. Furnace"
        }
    }

    private var currentSuggestions: [String] {
        switch itemType {
        case .repair: return repairSuggestions
        case .recurring: return recurringCategorySuggestions[category] ?? []
        case .lifecycle: return []
        }
    }

    private func typeIcon(_ type: MaintenanceItemType) -> String {
        switch type {
        case .repair: return "wrench.fill"
        case .recurring: return "arrow.clockwise"
        case .lifecycle: return "clock.fill"
        }
    }

    private func typeSubtitle(_ type: MaintenanceItemType) -> String {
        switch type {
        case .repair: return "Issues & fixes"
        case .recurring: return "Regular schedules"
        case .lifecycle: return "Track appliance age"
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        var item = editingItem ?? MaintenanceItem(
            id: UUID(), householdId: UUID(),
            itemType: itemType, title: trimmed, category: category,
            notes: nil, assignedTo: nil,
            createdAt: Date(), updatedAt: Date(),
            frequency: nil, startDate: nil, lastCompletedAt: nil,
            requiresScheduling: false, scheduledDate: nil, contractor: nil,
            repairStatus: itemType == .repair ? .open : nil,
            description: nil, estimatedCost: nil, actualCost: nil, completeBy: nil,
            installedDate: nil, expectedLifeYears: nil, brand: nil, model: nil
        )
        item.title = trimmed
        item.category = category
        item.assignedTo = itemType == .lifecycle ? nil : assignedTo
        item.notes = notes.isEmpty ? nil : notes

        switch itemType {
        case .repair:
            item.description = repairDescription.isEmpty ? nil : repairDescription
            item.requiresScheduling = repairRequiresScheduling
            item.completeBy = completeBy
            item.estimatedCost = Double(estimatedCostText).map { Decimal($0) }
            if editingItem == nil { item.repairStatus = .open }
        case .recurring:
            item.frequency = frequency
            item.startDate = startDate
            item.requiresScheduling = requiresScheduling
        case .lifecycle:
            item.installedDate = installedDate
            item.expectedLifeYears = Int(expectedLifeYears)
            item.brand = brand.isEmpty ? nil : brand
            item.model = model.isEmpty ? nil : model
        }

        onSaved(item)
        dismiss()
    }
}
