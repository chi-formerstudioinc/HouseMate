// HouseMate/Views/Maintenance/MaintenanceItemRowView.swift
import SwiftUI

struct MaintenanceItemRowView: View {
    let item: MaintenanceItem
    let members: [Member]
    let onComplete: () -> Void
    let onSchedule: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        switch item.itemType {
        case .repair: repairRow
        case .recurring: recurringRow
        case .lifecycle: lifecycleRow
        }
    }

    // MARK: - Repair Row

    private var repairRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                // Status indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(repairStatusColor)
                    .frame(width: 3)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(.body.weight(.medium))
                        Spacer()
                        memberAvatar
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if let desc = item.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    // Category chip only (no status chip — section header already shows status)
                    categoryChip

                    // Due date + cost row
                    HStack(spacing: 8) {
                        if let deadline = item.completeBy, item.repairStatus != .completed {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                if item.isRepairOverdue {
                                    Text("\(item.repairDaysOverdue)d overdue")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                } else {
                                    Text("By \(deadline.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(item.isRepairOverdue ? .red : .secondary)
                        }
                        if let cost = item.estimatedCost {
                            Text("Est: $\(NSDecimalNumber(decimal: cost).intValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.repairStatus != .completed {
                            scheduleOrCompleteButton
                        }
                    }

                    // Scheduled info indicator
                    if item.repairStatus == .scheduled,
                       let contractor = item.contractor,
                       let date = item.scheduledDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.caption2)
                            Text("\(contractor) · \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                    } else if item.repairStatus == .scheduled, let date = item.scheduledDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.caption2)
                            Text("Scheduled \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onComplete) {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }

    private var repairStatusColor: Color {
        switch item.repairStatus {
        case .open: return item.isRepairOverdue ? .red : .orange
        case .scheduled: return .blue
        case .completed: return .green
        case nil: return .gray
        }
    }

    private var scheduleOrCompleteButton: some View {
        Group {
            if item.repairStatus == .open {
                if item.requiresScheduling || item.scheduledDate == nil {
                    Button("Schedule It", action: onSchedule)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            } else if item.repairStatus == .scheduled {
                Button("Mark Complete", action: onComplete)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recurring Row

    private var recurringRow: some View {
        HStack(alignment: .top, spacing: 10) {
            // Category icon circle
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: item.category.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.body.weight(.medium))
                    Spacer()
                    memberAvatar
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 6) {
                    categoryChip
                    if let freq = item.frequency {
                        frequencyChip(freq)
                    }
                }

                if let next = item.nextDueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        if item.isOverdue {
                            let days = Calendar.current.dateComponents([.day], from: next, to: Date()).day ?? 0
                            Text("\(days) days overdue")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("Due \(next.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .foregroundStyle(item.isOverdue ? .red : .green)
                }

                HStack {
                    if let last = item.lastCompletedAt {
                        Text("Last: \(last.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let notes = item.notes {
                        Text("· \(notes)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if item.requiresScheduling && item.scheduledDate == nil {
                        Button("Schedule It", action: onSchedule)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                    }
                }

                // Scheduled info for recurring
                if item.requiresScheduling,
                   let contractor = item.contractor,
                   let date = item.scheduledDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.caption2)
                        Text("\(contractor) · \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onComplete) {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }

    // MARK: - Lifecycle Row

    private var lifecycleRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(lifecycleColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: item.category.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(lifecycleColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.body.weight(.medium))
                        if let brand = item.brand {
                            let modelStr = item.model.map { " · \($0)" } ?? ""
                            Text("\(brand)\(modelStr)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let status = item.ageStatus {
                        Text(status.displayName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(lifecycleColor.opacity(0.15))
                            .foregroundStyle(lifecycleColor)
                            .clipShape(Capsule())
                    }
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 6) {
                    categoryChip
                    if let installed = item.installedDate {
                        Text("Installed \(installed.formatted(.dateTime.year()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let progress = item.ageProgress, let yearsOld = item.yearsOld {
                    VStack(alignment: .leading, spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(lifecycleColor)
                                    .frame(width: geo.size.width * progress, height: 6)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Text(String(format: "%.1f yrs old", yearsOld))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let rem = item.yearsRemaining {
                                Text(String(format: "~%.0f yr left", max(rem, 0)))
                                    .font(.caption)
                                    .foregroundStyle(lifecycleColor)
                            }
                        }
                    }
                }

                if let expected = item.expectedLifeYears {
                    Text("Expected life: \(expected) years")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Shared

    /// Category chip using explicit HStack to avoid Label's unpredictable icon spacing
    private var categoryChip: some View {
        HStack(spacing: 4) {
            Image(systemName: item.category.iconName)
                .font(.system(size: 9, weight: .medium))
            Text(item.category.displayName)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.12))
        .foregroundStyle(.secondary)
        .clipShape(Capsule())
    }

    private func frequencyChip(_ freq: MaintenanceFrequency) -> some View {
        Text(freq.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.15))
            .foregroundStyle(Color.orange)
            .clipShape(Capsule())
    }

    private var memberAvatar: some View {
        Group {
            if item.itemType != .lifecycle,
               let assigneeId = item.assignedTo,
               let member = members.first(where: { $0.id == assigneeId }) {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(member.displayName.prefix(1)))
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                    )
            }
        }
    }

    private var lifecycleColor: Color {
        switch item.ageStatus {
        case .good: return .green
        case .watch: return .yellow
        case .replaceSoon: return .red
        case nil: return .green
        }
    }
}
