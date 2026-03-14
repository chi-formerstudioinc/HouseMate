// HouseMate/Views/Maintenance/MaintenanceCompletionSheet.swift
import SwiftUI

struct MaintenanceCompletionSheet: View {
    let item: MaintenanceItem
    let onComplete: (Decimal?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var actualCostText: String

    init(item: MaintenanceItem, onComplete: @escaping (Decimal?) -> Void) {
        self.item = item
        self.onComplete = onComplete
        _actualCostText = State(initialValue: item.estimatedCost.map { "\(NSDecimalNumber(decimal: $0).intValue)" } ?? "")
    }

    private var showsCostField: Bool {
        item.itemType == .repair || item.itemType == .chore ||
        (item.itemType == .maintenance && item.requiresScheduling)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Mark Complete")
                        .font(.title2.weight(.semibold))
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                if showsCostField {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Actual cost (optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField(item.estimatedCost != nil ? "pre-filled from estimate" : "0", text: $actualCostText)
                                .keyboardType(.numberPad)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Button {
                    let cost = Int(actualCostText).map { Decimal($0) }
                    onComplete(cost)
                    dismiss()
                } label: {
                    Text("Mark Complete")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
