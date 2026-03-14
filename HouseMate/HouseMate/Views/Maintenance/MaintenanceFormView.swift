// HouseMate/Views/Maintenance/MaintenanceFormView.swift
import SwiftUI

struct MaintenanceFormView: View {
    @Environment(\.dismiss) private var dismiss

    let members: [Member]
    let onSaved: (MaintenanceItem) -> Void

    @State private var itemType: MaintenanceItemType
    @State private var title = ""
    @State private var category: MaintenanceCategory = .exterior
    @State private var notes = ""
    @State private var assignedTo: UUID? = nil
    // Recurring
    @State private var frequency: MaintenanceFrequency = .monthly
    @State private var startDate = Date()
    @State private var requiresScheduling = false
    // Repair
    @State private var repairDescription = ""
    @State private var estimatedCost = ""
    @State private var contractor = ""
    // Lifecycle
    @State private var installedDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    @State private var expectedLifeYears = "10"
    @State private var brand = ""
    @State private var model = ""

    private let editingItem: MaintenanceItem?
    private var isEditing: Bool { editingItem != nil }

    private let titleSuggestions: [MaintenanceCategory: [String]] = [
        .hvac: ["Change Filter", "HVAC Tune-up", "Inspect Ducts", "Clean Vents"],
        .exterior: ["Clean Gutters", "Inspect Roof", "Power Wash", "Check Caulking"],
        .electrical: ["Check GFCIs", "Test Smoke Detectors", "Inspect Panel"],
        .plumbing: ["Check Water Heater", "Snake Drain", "Inspect Supply Lines"],
        .structural: ["Inspect Foundation", "Check Attic Insulation"],
        .vehicle: ["Oil Change", "Tire Rotation", "Check Brakes", "Annual Service"],
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
            _estimatedCost = State(initialValue: item.estimatedCost.map { "\(NSDecimalNumber(decimal: $0).intValue)" } ?? "")
            _contractor = State(initialValue: item.contractor ?? "")
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

                // Title
                Section("Title") {
                    TextField("Title", text: $title)
                    // Suggestions
                    if !isEditing, let suggestions = titleSuggestions[category] {
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
                        TextField("Contractor (optional)", text: $contractor)
                        TextField("Estimated cost ($)", text: $estimatedCost)
                            .keyboardType(.numberPad)
                    }

                case .recurring:
                    Section("Schedule") {
                        Picker("Frequency", selection: $frequency) {
                            ForEach(MaintenanceFrequency.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                        Toggle("Requires scheduling", isOn: $requiresScheduling)
                    }
                    Section("Notes") {
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: false)
                    }

                case .lifecycle:
                    Section("Appliance Details") {
                        DatePicker("Installation date", selection: $installedDate, displayedComponents: .date)
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
            description: nil, estimatedCost: nil, actualCost: nil,
            installedDate: nil, expectedLifeYears: nil, brand: nil, model: nil
        )
        item.title = trimmed
        item.category = category
        item.assignedTo = itemType == .lifecycle ? nil : assignedTo
        item.notes = notes.isEmpty ? nil : notes

        switch itemType {
        case .repair:
            item.description = repairDescription.isEmpty ? nil : repairDescription
            item.contractor = contractor.isEmpty ? nil : contractor
            item.estimatedCost = Int(estimatedCost).map { Decimal($0) }
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
