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
                    DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                }
                Section("Contractor (optional)") {
                    TextField("Name or company", text: $contractor)
                }
                Section("Estimated cost (optional)") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0", text: $estimatedCostText)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Schedule: \(item.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cost = Int(estimatedCostText).map { Decimal($0) }
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
}
