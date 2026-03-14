// HouseMate/Resources/MockMaintenanceData.swift
import Foundation

#if DEBUG
enum MockMaintenanceData {
    static let memberId1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let memberId2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let householdId = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!

    static let members: [Member] = [
        Member(id: memberId1, householdId: householdId, userId: memberId1, displayName: "Alex", createdAt: Date()),
        Member(id: memberId2, householdId: householdId, userId: memberId2, displayName: "Jordan", createdAt: Date()),
    ]

    // swiftlint:disable function_parameter_count
    static func make(
        id: UUID = UUID(),
        itemType: MaintenanceItemType,
        title: String,
        category: MaintenanceCategory,
        notes: String? = nil,
        assignedTo: UUID? = nil,
        // Recurring
        frequency: MaintenanceFrequency? = nil,
        startDate: Date? = nil,
        lastCompletedAt: Date? = nil,
        requiresScheduling: Bool = false,
        scheduledDate: Date? = nil,
        contractor: String? = nil,
        // Repair
        repairStatus: RepairStatus? = nil,
        description: String? = nil,
        estimatedCost: Decimal? = nil,
        actualCost: Decimal? = nil,
        // Lifecycle
        installedDate: Date? = nil,
        expectedLifeYears: Int? = nil,
        brand: String? = nil,
        model: String? = nil
    ) -> MaintenanceItem {
        MaintenanceItem(
            id: id,
            householdId: householdId,
            itemType: itemType,
            title: title,
            category: category,
            notes: notes,
            assignedTo: assignedTo,
            createdAt: Date(),
            updatedAt: Date(),
            frequency: frequency,
            startDate: startDate,
            lastCompletedAt: lastCompletedAt,
            requiresScheduling: requiresScheduling,
            scheduledDate: scheduledDate,
            contractor: contractor,
            repairStatus: repairStatus,
            description: description,
            estimatedCost: estimatedCost,
            actualCost: actualCost,
            installedDate: installedDate,
            expectedLifeYears: expectedLifeYears,
            brand: brand,
            model: model
        )
    }
    // swiftlint:enable function_parameter_count

    static let items: [MaintenanceItem] = {
        let cal = Calendar.current
        let today = Date()
        let daysAgo: (Int) -> Date = { cal.date(byAdding: .day, value: -$0, to: today)! }
        let daysFromNow: (Int) -> Date = { cal.date(byAdding: .day, value: $0, to: today)! }

        return [
            // REPAIRS — open
            make(itemType: .repair, title: "Garage Door Spring", category: .structural,
                 assignedTo: memberId1,
                 repairStatus: .open, description: "Spring worn, door slow to open",
                 estimatedCost: 250),
            make(itemType: .repair, title: "Leaking Kitchen Faucet", category: .plumbing,
                 assignedTo: memberId1,
                 scheduledDate: daysFromNow(5), contractor: "Mike's Plumbing",
                 repairStatus: .scheduled, description: "Slow drip from base, getting worse",
                 estimatedCost: 180),
            make(itemType: .repair, title: "Cracked Caulk Around Tub", category: .structural,
                 repairStatus: .open,
                 description: "Hairline cracks in caulk seal, risk of water intrusion",
                 estimatedCost: 40),

            // RECURRING — overdue
            make(itemType: .recurring, title: "Check GFCIs & Breakers", category: .electrical,
                 assignedTo: memberId2,
                 frequency: .biAnnual, startDate: daysAgo(200),
                 lastCompletedAt: daysAgo(195), requiresScheduling: false),
            make(itemType: .recurring, title: "Deep Clean Patio", category: .exterior,
                 frequency: .quarterly, startDate: daysAgo(110),
                 lastCompletedAt: daysAgo(105), requiresScheduling: false),

            // RECURRING — upcoming (next 30 days)
            make(itemType: .recurring, title: "Change HVAC Filter", category: .hvac,
                 notes: "20×25×1 MERV-8 filter", assignedTo: memberId1,
                 frequency: .quarterly, startDate: daysAgo(85),
                 lastCompletedAt: daysAgo(80), requiresScheduling: false),
            make(itemType: .recurring, title: "HVAC Tune-up", category: .hvac,
                 assignedTo: memberId2,
                 frequency: .annual, startDate: daysAgo(350),
                 lastCompletedAt: daysAgo(340), requiresScheduling: true,
                 scheduledDate: daysFromNow(14), contractor: "Cool Air HVAC"),

            // RECURRING — later this year
            make(itemType: .recurring, title: "Inspect Roof & Flashing", category: .exterior,
                 frequency: .annual, startDate: daysAgo(30),
                 lastCompletedAt: daysAgo(25), requiresScheduling: false),
            make(itemType: .recurring, title: "Flush Outdoor Drains", category: .plumbing,
                 frequency: .biAnnual, startDate: daysAgo(20),
                 lastCompletedAt: daysAgo(15), requiresScheduling: false),
            make(itemType: .recurring, title: "Vehicle Oil Change", category: .vehicle,
                 assignedTo: memberId1,
                 frequency: .quarterly, startDate: daysAgo(10),
                 lastCompletedAt: daysAgo(5), requiresScheduling: false),

            // LIFECYCLE
            make(itemType: .lifecycle, title: "Furnace", category: .hvac,
                 installedDate: cal.date(from: DateComponents(year: 2013, month: 1, day: 1))!,
                 expectedLifeYears: 15, brand: "Carrier", model: "58STA"),
            make(itemType: .lifecycle, title: "Central AC Unit", category: .hvac,
                 installedDate: cal.date(from: DateComponents(year: 2015, month: 6, day: 1))!,
                 expectedLifeYears: 15, brand: "Lennox"),
            make(itemType: .lifecycle, title: "Roof", category: .exterior,
                 notes: "Asphalt shingles",
                 installedDate: cal.date(from: DateComponents(year: 2012, month: 8, day: 1))!,
                 expectedLifeYears: 20),
            make(itemType: .lifecycle, title: "Water Heater", category: .plumbing,
                 installedDate: cal.date(from: DateComponents(year: 2018, month: 3, day: 1))!,
                 expectedLifeYears: 10, brand: "Rheem"),
        ]
    }()
}
#endif
