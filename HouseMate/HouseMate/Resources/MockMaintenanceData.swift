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
        frequency: MaintenanceFrequency? = nil,
        startDate: Date? = nil,
        lastCompletedAt: Date? = nil,
        requiresScheduling: Bool = false,
        scheduledDate: Date? = nil,
        contractor: String? = nil,
        repairStatus: RepairStatus? = nil,
        description: String? = nil,
        estimatedCost: Decimal? = nil,
        actualCost: Decimal? = nil,
        completeBy: Date? = nil,
        installedDate: Date? = nil,
        expectedLifeYears: Int? = nil,
        brand: String? = nil,
        model: String? = nil
    ) -> MaintenanceItem {
        MaintenanceItem(
            id: id, householdId: householdId, itemType: itemType,
            title: title, category: category, notes: notes, assignedTo: assignedTo,
            createdAt: Date(), updatedAt: Date(),
            frequency: frequency, startDate: startDate, lastCompletedAt: lastCompletedAt,
            requiresScheduling: requiresScheduling, scheduledDate: scheduledDate, contractor: contractor,
            repairStatus: repairStatus, description: description,
            estimatedCost: estimatedCost, actualCost: actualCost, completeBy: completeBy,
            installedDate: installedDate, expectedLifeYears: expectedLifeYears,
            brand: brand, model: model
        )
    }
    // swiftlint:enable function_parameter_count

    static let items: [MaintenanceItem] = {
        let cal = Calendar.current
        let today = Date()
        let daysAgo: (Int) -> Date = { cal.date(byAdding: .day, value: -$0, to: today)! }
        let daysFromNow: (Int) -> Date = { cal.date(byAdding: .day, value: $0, to: today)! }

        return [
            // REPAIRS
            make(itemType: .repair, title: "Garage Door Spring", category: .aroundTheHouse,
                 assignedTo: memberId1, repairStatus: .open,
                 description: "Spring worn, door slow to open",
                 estimatedCost: 250, completeBy: daysAgo(5)),
            make(itemType: .repair, title: "Cracked Caulk Around Tub", category: .plumbing,
                 repairStatus: .open,
                 description: "Hairline cracks in caulk seal, risk of water intrusion",
                 estimatedCost: 40, completeBy: daysFromNow(14)),
            make(itemType: .repair, title: "Leaking Kitchen Faucet", category: .plumbing,
                 assignedTo: memberId1, scheduledDate: daysFromNow(5), contractor: "Mike's Plumbing",
                 repairStatus: .scheduled, description: "Slow drip from base, getting worse",
                 estimatedCost: 180, completeBy: daysFromNow(10)),
            make(itemType: .repair, title: "Replace Porch Light Fixture", category: .electrical,
                 lastCompletedAt: daysAgo(8), repairStatus: .completed,
                 description: "Old fixture corroded", estimatedCost: 65, actualCost: 72),

            // CHORES — overdue
            make(itemType: .chore, title: "Return Library Books", category: .aroundTheHouse,
                 assignedTo: memberId2, repairStatus: .open, completeBy: daysAgo(3)),

            // CHORES — coming up with deadline
            make(itemType: .chore, title: "Deep Vacuum All Rooms", category: .aroundTheHouse,
                 assignedTo: memberId1, repairStatus: .open, completeBy: daysFromNow(7)),

            // CHORES — repeating
            make(itemType: .chore, title: "Change Bed Sheets", category: .aroundTheHouse,
                 frequency: .biWeekly, startDate: daysAgo(10),
                 lastCompletedAt: daysAgo(10), repairStatus: .open),

            // CHORES — no date
            make(itemType: .chore, title: "Organize Garage", category: .aroundTheHouse,
                 repairStatus: .open),

            // CHORES — completed last 30 days
            make(itemType: .chore, title: "Clean Oven", category: .aroundTheHouse,
                 lastCompletedAt: daysAgo(5), repairStatus: .completed),

            // MAINTENANCE — overdue
            make(itemType: .maintenance, title: "Check GFCIs & Breakers", category: .electrical,
                 assignedTo: memberId2, frequency: .biAnnual, startDate: daysAgo(200),
                 lastCompletedAt: daysAgo(195), requiresScheduling: false),
            make(itemType: .maintenance, title: "Deep Clean Patio", category: .exterior,
                 frequency: .quarterly, startDate: daysAgo(110),
                 lastCompletedAt: daysAgo(105), requiresScheduling: false),

            // MAINTENANCE — upcoming
            make(itemType: .maintenance, title: "Change HVAC Filter", category: .hvac,
                 notes: "20×25×1 MERV-8 filter", assignedTo: memberId1,
                 frequency: .quarterly, startDate: daysAgo(85),
                 lastCompletedAt: daysAgo(80), requiresScheduling: false),
            make(itemType: .maintenance, title: "HVAC Tune-up", category: .hvac,
                 assignedTo: memberId2, frequency: .annual, startDate: daysAgo(350),
                 lastCompletedAt: daysAgo(340), requiresScheduling: true,
                 scheduledDate: daysFromNow(14), contractor: "Cool Air HVAC"),

            // MAINTENANCE — later this year
            make(itemType: .maintenance, title: "Inspect Roof & Flashing", category: .exterior,
                 frequency: .annual, startDate: daysAgo(30),
                 lastCompletedAt: daysAgo(25), requiresScheduling: false),
            make(itemType: .maintenance, title: "Flush Outdoor Drains", category: .plumbing,
                 frequency: .biAnnual, startDate: daysAgo(20),
                 lastCompletedAt: daysAgo(15), requiresScheduling: false),
            make(itemType: .maintenance, title: "Vehicle Oil Change", category: .vehicle,
                 assignedTo: memberId1, frequency: .quarterly, startDate: daysAgo(10),
                 lastCompletedAt: daysAgo(5), requiresScheduling: false),

            // MAINTENANCE — completed last 30 days
            make(itemType: .maintenance, title: "Replace Smoke Detector Batteries", category: .electrical,
                 frequency: .annual, startDate: daysAgo(60),
                 lastCompletedAt: daysAgo(3), requiresScheduling: false),

            // ASSETS
            make(itemType: .asset, title: "Furnace", category: .hvac,
                 installedDate: cal.date(from: DateComponents(year: 2013, month: 1, day: 1))!,
                 expectedLifeYears: 15, brand: "Carrier", model: "58STA"),
            make(itemType: .asset, title: "Central AC Unit", category: .hvac,
                 installedDate: cal.date(from: DateComponents(year: 2015, month: 6, day: 1))!,
                 expectedLifeYears: 15, brand: "Lennox"),
            make(itemType: .asset, title: "Roof", category: .exterior,
                 notes: "Asphalt shingles",
                 installedDate: cal.date(from: DateComponents(year: 2012, month: 8, day: 1))!,
                 expectedLifeYears: 20),
            make(itemType: .asset, title: "Water Heater", category: .plumbing,
                 installedDate: cal.date(from: DateComponents(year: 2018, month: 3, day: 1))!,
                 expectedLifeYears: 10, brand: "Rheem"),
        ]
    }()
}
#endif
