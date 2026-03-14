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
    // Shared scheduling
    @State private var requiresScheduling = false
    @State private var scheduledDate = Date()
    @State private var contractor = ""
    @State private var estimatedCostText = ""
    // Repair / Chore
    @State private var repairDescription = ""
    @State private var completeBy: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
    // Chore repeat
    @State private var choreFrequency: MaintenanceFrequency? = nil
    // Maintenance
    @State private var frequency: MaintenanceFrequency = .monthly
    @State private var startDate = Date()
    // Asset
    @State private var installedDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    @State private var expectedLifeYears = "10"
    @State private var brand = ""
    @State private var model = ""

    private let editingItem: MaintenanceItem?
    private var isEditing: Bool { editingItem != nil }

    private let taskTypes: [MaintenanceItemType] = [.chore, .repair, .maintenance]

    private let maintenanceCategorySuggestions: [MaintenanceCategory: [String]] = [
        .aroundTheHouse: ["Change Bed Sheets", "Clean Bathrooms", "Dust the House", "Deep Vacuum", "Return Items"],
        .hvac: ["Change HVAC Filter", "HVAC Tune-up", "Inspect Ducts", "Clean Vents"],
        .exterior: ["Clean Gutters", "Inspect Roof", "Power Wash Driveway", "Check Caulking"],
        .electrical: ["Check GFCIs", "Test Smoke Detectors", "Inspect Panel"],
        .plumbing: ["Check Water Heater", "Snake Drain", "Inspect Supply Lines"],
        .vehicle: ["Oil Change", "Tire Rotation", "Check Brakes", "Annual Service"],
    ]
    private let repairSuggestions = ["Fix Leaking Pipe", "Repair Broken Window", "Replace Damaged Tile",
                                      "Patch Drywall Hole", "Fix Stuck Door"]
    private let choreSuggestions: [MaintenanceCategory: [String]] = [
        .aroundTheHouse: ["Return Items", "Deep Vacuum", "Organize Pantry", "Clear Junk Mail", "Donate Old Clothes"],
        .exterior: ["Mow Lawn", "Weed Garden", "Clean Garage"],
        .vehicle: ["Clean Car Interior", "Wash Car"],
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
            _requiresScheduling = State(initialValue: item.requiresScheduling)
            _choreFrequency = State(initialValue: item.itemType == .chore ? item.frequency : nil)
            _frequency = State(initialValue: item.frequency ?? .monthly)
            _startDate = State(initialValue: item.startDate ?? Date())
            _repairDescription = State(initialValue: item.description ?? "")
            _estimatedCostText = State(initialValue: item.estimatedCost.map {
                let val = NSDecimalNumber(decimal: $0).doubleValue
                return val.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(val)) : String(format: "%.2f", val)
            } ?? "")
            _completeBy = State(initialValue: item.completeBy ?? Calendar.current.date(byAdding: .day, value: 14, to: Date())!)
            _contractor = State(initialValue: item.contractor ?? "")
            _scheduledDate = State(initialValue: item.scheduledDate ?? Date())
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
                // Type selector (create only, task types)
                if !isEditing && itemType != .asset {
                    Section {
                        typeSelectorCards
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Title
                Section {
                    TextField(titlePlaceholder, text: $title)
                        .onChange(of: title) { _, new in
                            if new.count > 40 { title = String(new.prefix(40)) }
                        }
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
                } header: { Text(taskFieldLabel) }

                // Category
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(MaintenanceCategory.allCases, id: \.self) {
                            Label($0.displayName, systemImage: $0.iconName).tag($0)
                        }
                    }
                }

                // Assign To (not for assets)
                if itemType != .asset {
                    Section {
                        Picker("Assign to", selection: $assignedTo) {
                            Text("Unassigned").tag(Optional<UUID>.none)
                            ForEach(members) { m in
                                Text(m.displayName).tag(Optional(m.id))
                            }
                        }
                    } header: { optionalHeader("Assign To") }
                }

                // Type-specific fields
                switch itemType {
                case .chore:    choreFields
                case .repair:   repairFields
                case .maintenance: maintenanceFields
                case .asset:    assetFields
                }
            }
            .navigationTitle(isEditing ? "Edit" : "Add")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Chore fields

    @ViewBuilder
    private var choreFields: some View {
        Section {
            Picker("Repeat", selection: $choreFrequency) {
                Text("Never").tag(Optional<MaintenanceFrequency>.none)
                ForEach(MaintenanceFrequency.allCases, id: \.self) {
                    Text($0.displayName).tag(Optional($0))
                }
            }
        } header: { optionalHeader("Repeat") }

        Section {
            datePicker("Complete by", selection: $completeBy)
        } header: { optionalHeader("Due Date") }

        Section {
            Toggle("Requires scheduling", isOn: $requiresScheduling)
            if requiresScheduling {
                TextField("Contractor", text: $contractor)
                costField
                datePicker("Scheduled date", selection: $scheduledDate)
            }
        } header: { optionalHeader("Schedule") }

        Section {
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: false)
        } header: { optionalHeader("Notes") }
    }

    // MARK: - Repair fields

    @ViewBuilder
    private var repairFields: some View {
        Section("Details") {
            TextField("Description", text: $repairDescription, axis: .vertical)
                .lineLimit(3, reservesSpace: false)
            costField
        }

        Section {
            datePicker("Complete by", selection: $completeBy)
            Toggle("Requires scheduling", isOn: $requiresScheduling)
            if requiresScheduling {
                TextField("Contractor", text: $contractor)
                datePicker("Scheduled date", selection: $scheduledDate)
            }
        } header: { optionalHeader("Schedule") }
    }

    // MARK: - Maintenance fields

    @ViewBuilder
    private var maintenanceFields: some View {
        Section("Schedule") {
            Picker("Repeat", selection: $frequency) {
                ForEach(MaintenanceFrequency.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            datePicker("Start date", selection: $startDate)
            Toggle("Requires scheduling", isOn: $requiresScheduling)
            if requiresScheduling {
                TextField("Contractor", text: $contractor)
                costField
                datePicker("Scheduled date", selection: $scheduledDate)
            }
        }
        Section {
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: false)
        } header: { optionalHeader("Notes") }
    }

    // MARK: - Asset fields

    @ViewBuilder
    private var assetFields: some View {
        Section("Appliance Details") {
            datePicker("Installation date", selection: $installedDate)
            TextField("Expected life (years)", text: $expectedLifeYears)
                .keyboardType(.numberPad)
            TextField("Brand", text: $brand)
            TextField("Model", text: $model)
        }
        Section {
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: false)
        } header: { optionalHeader("Notes") }
    }

    // MARK: - Helpers

    private func optionalHeader(_ label: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
            Text("· optional")
                .foregroundStyle(.secondary)
                .fontWeight(.regular)
        }
    }

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

    private var costField: some View {
        HStack(spacing: 4) {
            Text("$").foregroundStyle(.secondary)
            TextField("0", text: $estimatedCostText)
                .keyboardType(.decimalPad)
                .onChange(of: estimatedCostText) { _, newVal in
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

    private var typeSelectorCards: some View {
        HStack(spacing: 8) {
            ForEach(taskTypes, id: \.self) { type in
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

    private var taskFieldLabel: String {
        switch itemType {
        case .chore: return "Chore"
        case .repair: return "Repair Task"
        case .maintenance: return "Recurring Task"
        case .asset: return "Appliance"
        }
    }

    private var titlePlaceholder: String {
        switch itemType {
        case .chore: return "e.g. Return library books"
        case .repair: return "e.g. Fix leaking pipe"
        case .maintenance: return "e.g. Change HVAC filter"
        case .asset: return "e.g. Furnace"
        }
    }

    private var currentSuggestions: [String] {
        switch itemType {
        case .chore: return choreSuggestions[category] ?? []
        case .repair: return repairSuggestions
        case .maintenance: return maintenanceCategorySuggestions[category] ?? []
        case .asset: return []
        }
    }

    private func typeIcon(_ type: MaintenanceItemType) -> String {
        switch type {
        case .chore: return "checkmark.circle"
        case .repair: return "wrench.fill"
        case .maintenance: return "arrow.clockwise"
        case .asset: return "clock.fill"
        }
    }

    private func typeSubtitle(_ type: MaintenanceItemType) -> String {
        switch type {
        case .chore: return "Tasks & to-dos"
        case .repair: return "Issues & fixes"
        case .maintenance: return "Regular schedules"
        case .asset: return "Track appliances"
        }
    }

    // MARK: - Save

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        var item = editingItem ?? MaintenanceItem(
            id: UUID(), householdId: UUID(),
            itemType: itemType, title: trimmed, category: category,
            notes: nil, assignedTo: nil,
            createdAt: Date(), updatedAt: Date(),
            frequency: nil, startDate: nil, lastCompletedAt: nil,
            requiresScheduling: false, scheduledDate: nil, contractor: nil,
            repairStatus: (itemType == .repair || itemType == .chore) ? .open : nil,
            description: nil, estimatedCost: nil, actualCost: nil, completeBy: nil,
            installedDate: nil, expectedLifeYears: nil, brand: nil, model: nil
        )
        item.title = trimmed
        item.category = category
        item.notes = notes.isEmpty ? nil : notes
        item.assignedTo = itemType == .asset ? nil : assignedTo

        switch itemType {
        case .chore:
            item.repairStatus = editingItem?.repairStatus ?? .open
            item.frequency = choreFrequency
            item.startDate = choreFrequency != nil ? startDate : nil
            item.completeBy = choreFrequency == nil ? completeBy : nil
            item.requiresScheduling = requiresScheduling
            item.contractor = requiresScheduling && !contractor.isEmpty ? contractor : nil
            item.estimatedCost = requiresScheduling ? Double(estimatedCostText).map { Decimal($0) } : nil
            item.scheduledDate = requiresScheduling ? scheduledDate : nil

        case .repair:
            item.description = repairDescription.isEmpty ? nil : repairDescription
            item.estimatedCost = Double(estimatedCostText).map { Decimal($0) }
            item.completeBy = completeBy
            item.requiresScheduling = requiresScheduling
            item.contractor = requiresScheduling && !contractor.isEmpty ? contractor : nil
            item.scheduledDate = requiresScheduling ? scheduledDate : nil
            if editingItem == nil { item.repairStatus = .open }

        case .maintenance:
            item.frequency = frequency
            item.startDate = startDate
            item.requiresScheduling = requiresScheduling
            item.contractor = requiresScheduling && !contractor.isEmpty ? contractor : nil
            item.estimatedCost = requiresScheduling ? Double(estimatedCostText).map { Decimal($0) } : nil
            item.scheduledDate = requiresScheduling ? scheduledDate : nil

        case .asset:
            item.installedDate = installedDate
            item.expectedLifeYears = Int(expectedLifeYears)
            item.brand = brand.isEmpty ? nil : brand
            item.model = model.isEmpty ? nil : model
        }

        onSaved(item)
        dismiss()
    }
}
