// HouseMate/Views/Maintenance/MaintenanceItemRowView.swift
import SwiftUI

struct MaintenanceItemRowView: View {
    let item: MaintenanceItem
    let members: [Member]
    let onComplete: () -> Void
    let onReopen: () -> Void
    let onSchedule: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
                )
            switch item.itemType {
            case .chore:      choreRow.padding(12)
            case .repair:     repairRow.padding(12)
            case .maintenance: recurringRow.padding(12)
            case .asset:      assetRow.padding(12)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
    }

    // MARK: - Chore Row

    private var choreRow: some View {
        HStack(alignment: .top, spacing: 10) {
            // Status indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(choreStatusColor)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    memberAvatar
                    editButton
                    if item.repairStatus != .completed { deleteButton }
                }

                categoryChip

                HStack(spacing: 6) {
                    if let due = item.choreDueDate, item.repairStatus != .completed {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar").font(.caption2)
                            if item.isChoreOverdue {
                                Text("\(item.choreDaysOverdue)d overdue")
                                    .font(.caption).foregroundStyle(.red)
                            } else {
                                Text("By \(due.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(item.isChoreOverdue ? .red : .secondary)
                    }
                    if let cost = item.estimatedCost {
                        Text("Est: $\(NSDecimalNumber(decimal: cost).intValue)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if item.repairStatus != .completed {
                        Button("Done", action: onComplete)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                    }
                }

                if let last = item.lastCompletedAt, item.repairStatus == .completed {
                    Text("Completed \(relativeDate(last))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if item.repairStatus == .completed {
                Button(action: onReopen) {
                    Label("Reopen", systemImage: "arrow.uturn.left")
                }
                .tint(.orange)
            } else {
                Button(action: onComplete) {
                    Label("Done", systemImage: "checkmark")
                }
                .tint(.green)
            }
        }
    }

    private var choreStatusColor: Color {
        if item.repairStatus == .completed { return .green }
        if item.isChoreOverdue { return .red }
        return .blue
    }

    // MARK: - Repair Row

    private var repairRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(repairStatusColor)
                    .frame(width: 3)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        memberAvatar
                        editButton
                        if item.repairStatus != .completed { deleteButton }
                    }

                    if let desc = item.description {
                        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }

                    categoryChip

                    HStack(spacing: 8) {
                        if let deadline = item.completeBy, item.repairStatus != .completed {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar").font(.caption2)
                                if item.isRepairOverdue {
                                    Text("\(item.repairDaysOverdue)d overdue")
                                        .font(.caption).foregroundStyle(.red)
                                } else {
                                    Text("By \(deadline.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(item.isRepairOverdue ? .red : .secondary)
                        }
                        if let cost = item.estimatedCost {
                            Text("Est: $\(NSDecimalNumber(decimal: cost).intValue)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.repairStatus != .completed {
                            scheduleOrCompleteButton
                        }
                    }

                    // Scheduled indicator
                    if item.repairStatus == .scheduled {
                        if let contractor = item.contractor, let date = item.scheduledDate {
                            scheduledIndicator(contractor: contractor, date: date)
                        } else if let date = item.scheduledDate {
                            scheduledIndicator(contractor: nil, date: date)
                        }
                    }

                    if let last = item.lastCompletedAt, item.repairStatus == .completed {
                        Text("Completed \(relativeDate(last))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if item.repairStatus == .completed {
                Button(action: onReopen) {
                    Label("Reopen", systemImage: "arrow.uturn.left")
                }
                .tint(.orange)
            } else {
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark")
                }
                .tint(.green)
            }
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
                Button("Schedule It", action: onSchedule)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            } else if item.repairStatus == .scheduled {
                Button("Mark Complete", action: onComplete)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private func scheduledIndicator(contractor: String?, date: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar.badge.checkmark").font(.caption2)
            if let c = contractor {
                Text("\(c) · \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption)
            } else {
                Text("Scheduled \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption)
            }
        }
        .foregroundStyle(.orange)
    }

    // MARK: - Recurring (Maintenance) Row

    private var recurringRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: item.category.iconName)
                    .font(.system(size: 16)).foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title).font(.body.weight(.medium)).lineLimit(1)
                    Spacer()
                    memberAvatar
                    editButton
                }

                HStack(spacing: 6) {
                    categoryChip
                    if let freq = item.frequency { frequencyChip(freq) }
                }

                if let next = item.nextDueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.caption2)
                        if item.isOverdue {
                            let days = Calendar.current.dateComponents([.day], from: next, to: Date()).day ?? 0
                            Text("\(days) days overdue").font(.caption).foregroundStyle(.red)
                        } else {
                            Text("Due \(next.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(.green)
                        }
                    }
                    .foregroundStyle(item.isOverdue ? .red : .green)
                }

                HStack {
                    if let last = item.lastCompletedAt {
                        Text("Last: \(relativeDate(last))").font(.caption).foregroundStyle(.secondary)
                    }
                    if let notes = item.notes {
                        Text("· \(notes)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if item.requiresScheduling && item.scheduledDate == nil {
                        Button("Schedule It", action: onSchedule)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.accentColor).foregroundStyle(.white)
                            .clipShape(Capsule()).buttonStyle(.plain)
                    }
                }

                if item.requiresScheduling, let contractor = item.contractor, let date = item.scheduledDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark").font(.caption2)
                        Text("\(contractor) · \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let last = item.lastCompletedAt,
               Calendar.current.isDateInToday(last) {
                Button(action: onReopen) {
                    Label("Reopen", systemImage: "arrow.uturn.left")
                }
                .tint(.orange)
            } else {
                Button(action: onComplete) {
                    Label("Complete", systemImage: "checkmark")
                }
                .tint(.green)
            }
        }
    }

    // MARK: - Asset Row

    private var assetRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(lifecycleColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: item.category.iconName)
                    .font(.system(size: 16)).foregroundStyle(lifecycleColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title).font(.body.weight(.medium)).lineLimit(1)
                        if let brand = item.brand {
                            let modelStr = item.model.map { " · \($0)" } ?? ""
                            Text("\(brand)\(modelStr)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let status = item.ageStatus {
                        Text(status.displayName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(lifecycleColor.opacity(0.15))
                            .foregroundStyle(lifecycleColor)
                            .clipShape(Capsule())
                    }
                    editButton
                    deleteButton
                }

                HStack(spacing: 6) {
                    categoryChip
                    if let installed = item.installedDate {
                        Text("Installed \(installed.formatted(.dateTime.year()))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let progress = item.ageProgress, let yearsOld = item.yearsOld {
                    VStack(alignment: .leading, spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.2)).frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(lifecycleColor)
                                    .frame(width: geo.size.width * progress, height: 6)
                            }
                        }
                        .frame(height: 6)
                        HStack {
                            Text(String(format: "%.1f yrs old", yearsOld))
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if let rem = item.yearsRemaining {
                                Text(String(format: "~%.0f yr left", max(rem, 0)))
                                    .font(.caption).foregroundStyle(lifecycleColor)
                            }
                        }
                    }
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
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

    // MARK: - Shared components

    private var categoryChip: some View {
        HStack(spacing: 4) {
            Image(systemName: item.category.iconName).font(.system(size: 9, weight: .medium))
            Text(item.category.displayName).font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Color.secondary.opacity(0.12)).foregroundStyle(.secondary)
        .clipShape(Capsule())
    }

    private func frequencyChip(_ freq: MaintenanceFrequency) -> some View {
        Text(freq.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.orange.opacity(0.15)).foregroundStyle(Color.orange)
            .clipShape(Capsule())
    }

    private var memberAvatar: some View {
        Group {
            if item.itemType != .asset,
               let assigneeId = item.assignedTo,
               let member = members.first(where: { $0.id == assigneeId }) {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(member.displayName.prefix(1)))
                            .font(.caption2.bold()).foregroundStyle(Color.accentColor)
                    )
            }
        }
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash").font(.caption).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Relative date helper

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 1 { return "today" }
        if days < 7 { return "this week" }
        if days < 14 { return "1 week ago" }
        let weeks = days / 7
        if weeks < 8 { return "\(weeks) weeks ago" }
        let months = (days + 15) / 30
        return "\(months) month\(months == 1 ? "" : "s") ago"
    }
}
