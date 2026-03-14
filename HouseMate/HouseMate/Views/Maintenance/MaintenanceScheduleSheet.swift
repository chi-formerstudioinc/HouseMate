// HouseMate/Views/Maintenance/MaintenanceScheduleSheet.swift
import SwiftUI

struct MaintenanceScheduleSheet: View {
    let item: MaintenanceItem
    let onSchedule: (Date, String?, Decimal?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scheduledDate = Date()
    @State private var contractor = ""
    @State private var estimatedCostText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    datePicker("Date", selection: $scheduledDate)
                }
                Section("Contractor (optional)") {
                    TextField("Name or company", text: $contractor)
                }
                Section("Estimated cost (optional)") {
                    HStack(spacing: 4) {
                        Text("$")
                            .foregroundStyle(.secondary)
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
            }
            .navigationTitle("Schedule: \(item.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cost = Double(estimatedCostText).map { Decimal($0) }
                        onSchedule(scheduledDate, contractor.isEmpty ? nil : contractor, cost)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
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
}
