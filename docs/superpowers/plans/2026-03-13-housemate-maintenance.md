# HouseMate Maintenance Feature Implementation Plan (Supabase)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Maintenance tab — a home maintenance tracker with three item types (Repairs, Recurring, Lifecycle), smart temporal grouping for recurring items, swipe-to-complete with optional cost capture, category-matched contractor suggestions, adaptive add/edit form, and assign-to functionality with member avatars for repair and recurring items.

**Architecture:** `AppState` (`@Observable`) holds household/member context and is injected via SwiftUI `.environment`. `MaintenanceViewModel` and `MaintenanceFormViewModel` (`@Observable`) are owned as `@State` in their views. They call `MaintenanceService` for all data operations. `MaintenanceViewModel` observes `NotificationCenter` for `RealtimeService.maintenanceChangedNotification` to refresh the list when another member makes changes. Grouping/filtering logic is pure computed properties on `MaintenanceViewModel` and is fully unit-tested.

**Tech Stack:** Swift 5.9+, SwiftUI (`@Observable`), Supabase (via `MaintenanceService`), XCTest, iOS 17.0+

**Prerequisite:** Foundation plan complete — `HouseMate/Models/`, `HouseMate/Services/MaintenanceService.swift`, `HouseMate/State/AppState.swift`, `HouseMate/Services/RealtimeService.swift`, and the 4-tab navigation skeleton must all be in place.

**Spec:** `docs/superpowers/specs/2026-03-12-housemate-design.md`

---

## File Structure

**New files:**
- `HouseMate/ViewModels/MaintenanceViewModel.swift` — list state: fetch, filter by type/category, group recurring, complete, schedule, delete; observes RealtimeService notifications
- `HouseMate/ViewModels/MaintenanceFormViewModel.swift` — adaptive add/edit form state for all 3 item types, smart defaults, title suggestions, contractor suggestions, validation, save
- `HouseMate/Views/Maintenance/MaintenanceListView.swift` — full maintenance list: header subtitle, category filter bar, type tabs, FAB
- `HouseMate/Views/Maintenance/MaintenanceItemRowView.swift` — single list row, handles all 3 item types with swipe actions
- `HouseMate/Views/Maintenance/MaintenanceFormView.swift` — adaptive add/edit form sheet
- `HouseMate/Views/Maintenance/MaintenanceCompletionSheet.swift` — completion sheet with actual cost capture
- `HouseMate/Views/Maintenance/MaintenanceScheduleSheet.swift` — schedule sheet with date, contractor, estimated cost
- `HouseMateTests/ViewModels/MaintenanceViewModelTests.swift` — tests for grouping, filtering, showCompleted toggle
- `HouseMateTests/ViewModels/MaintenanceFormViewModelTests.swift` — tests for smart defaults, title suggestions, canSave

**Modified files:**
- `HouseMate/Models/MaintenanceItem.swift` — replace with full model supporting all 3 item types, new enums, computed properties
- `HouseMate/Models/MaintenanceLog.swift` — replace with `MaintenanceCompletionLog` model
- `HouseMate/Services/MaintenanceService.swift` — add new methods for completion, scheduling, contractor suggestions
- `HouseMate/Views/Main/MainTabView.swift` — replace `Text("Maintenance")` placeholder with `MaintenanceListView()`

---

## Chunk 1: Model + DB Migration

### Task 1: Update Models and Enums

**Files:**
- Modify: `HouseMate/HouseMate/Models/MaintenanceItem.swift`
- Modify: `HouseMate/HouseMate/Models/MaintenanceLog.swift`

- [ ] **Step 1: Replace MaintenanceItem.swift with full model**

  Replace the entire contents of `HouseMate/HouseMate/Models/MaintenanceItem.swift`:

  ```swift
  // HouseMate/Models/MaintenanceItem.swift
  import Foundation

  // MARK: - Enums

  enum MaintenanceItemType: String, Codable, CaseIterable, Identifiable {
      case repair, recurring, lifecycle
      var id: String { rawValue }
      var displayName: String { rawValue.capitalized }
  }

  enum MaintenanceCategory: String, Codable, CaseIterable, Identifiable {
      case exterior, hvac, electrical, plumbing, structural, vehicle
      var id: String { rawValue }

      var displayName: String {
          switch self {
          case .hvac: return "HVAC"
          default: return rawValue.capitalized
          }
      }

      var iconName: String {
          switch self {
          case .exterior: return "house.fill"
          case .hvac: return "wind"
          case .electrical: return "bolt.fill"
          case .plumbing: return "drop.fill"
          case .structural: return "building.2.fill"
          case .vehicle: return "car.fill"
          }
      }
  }

  enum MaintenanceFrequency: String, Codable, CaseIterable, Identifiable {
      case weekly, monthly, quarterly, biAnnual = "bi_annual", annual
      var id: String { rawValue }

      var displayName: String {
          switch self {
          case .weekly: return "Weekly"
          case .monthly: return "Monthly"
          case .quarterly: return "Quarterly"
          case .biAnnual: return "Bi-Annual"
          case .annual: return "Annual"
          }
      }

      var intervalDays: Int {
          switch self {
          case .weekly: return 7
          case .monthly: return 30
          case .quarterly: return 90
          case .biAnnual: return 182
          case .annual: return 365
          }
      }
  }

  enum RepairStatus: String, Codable, CaseIterable {
      case open, scheduled, completed
      var displayName: String { rawValue.capitalized }
  }

  enum MaintenanceAgeStatus: String {
      case good, watch, replaceSoon

      var displayName: String {
          switch self {
          case .good: return "Good"
          case .watch: return "Watch"
          case .replaceSoon: return "Replace Soon"
          }
      }
  }

  // MARK: - MaintenanceItem

  struct MaintenanceItem: Codable, Identifiable {
      let id: UUID
      let householdId: UUID
      var name: String
      var category: MaintenanceCategory
      var itemType: MaintenanceItemType

      // Recurring fields
      var frequency: MaintenanceFrequency?
      var startDate: Date?
      var requiresScheduling: Bool?
      var lastCompletedDate: Date?
      var notes: String?

      // Repair fields
      var description: String?
      var repairStatus: RepairStatus?
      var scheduledDate: Date?
      var contractor: String?
      var estimatedCost: Decimal?
      var actualCost: Decimal?

      // Lifecycle fields
      var installedDate: Date?
      var expectedLifeYears: Int?
      var brand: String?
      var model: String?

      // Assign-to (repair and recurring only; lifecycle does NOT have assignee)
      var assignedTo: UUID?

      // Legacy — kept for backward compat, derived from frequency
      var intervalDays: Int?

      let templateId: UUID?
      let createdAt: Date
      var updatedAt: Date

      enum CodingKeys: String, CodingKey {
          case id, name, category, notes, description, contractor, brand, model, frequency
          case householdId = "household_id"
          case itemType = "item_type"
          case startDate = "start_date"
          case requiresScheduling = "requires_scheduling"
          case lastCompletedDate = "last_completed_date"
          case repairStatus = "repair_status"
          case scheduledDate = "scheduled_date"
          case estimatedCost = "estimated_cost"
          case actualCost = "actual_cost"
          case installedDate = "installed_date"
          case expectedLifeYears = "expected_life_years"
          case assignedTo = "assigned_to"
          case intervalDays = "interval_days"
          case templateId = "template_id"
          case createdAt = "created_at"
          case updatedAt = "updated_at"
      }

      // MARK: - Computed Properties

      /// Next due date for recurring items. Uses startDate + frequency + lastCompletedDate.
      var nextDueDate: Date? {
          guard itemType == .recurring, let freq = frequency else { return nil }
          let baseDate = lastCompletedDate ?? startDate ?? createdAt
          return Calendar.current.date(byAdding: .day, value: freq.intervalDays, to: baseDate)
      }

      /// Whether a recurring item is overdue (past its nextDueDate).
      var isOverdue: Bool {
          guard let next = nextDueDate else { return false }
          return next < Calendar.current.startOfDay(for: Date())
      }

      /// Traffic-light status for recurring items.
      var status: MaintenanceStatus {
          guard let next = nextDueDate else { return .red }
          let today = Calendar.current.startOfDay(for: Date())
          let daysUntil = Calendar.current.dateComponents([.day], from: today, to: next).day ?? 0
          if daysUntil > 14 { return .green }
          if daysUntil >= 0 { return .yellow }
          return .red
      }

      // MARK: - Lifecycle computed properties

      /// Years since installation (lifecycle items).
      var yearsOld: Double {
          guard let installed = installedDate else { return 0 }
          let days = Calendar.current.dateComponents([.day], from: installed, to: Date()).day ?? 0
          return Double(days) / 365.25
      }

      /// Estimated years remaining (lifecycle items).
      var yearsRemaining: Double {
          guard let expected = expectedLifeYears else { return 0 }
          return max(0, Double(expected) - yearsOld)
      }

      /// Age-based status for lifecycle items.
      var ageStatus: MaintenanceAgeStatus {
          guard let expected = expectedLifeYears, expected > 0 else { return .good }
          let ratio = yearsOld / Double(expected)
          if ratio < 0.7 { return .good }
          if ratio < 0.9 { return .watch }
          return .replaceSoon
      }

      /// Progress through expected life (0.0 to 1.0+) for lifecycle items.
      var ageProgress: Double {
          guard let expected = expectedLifeYears, expected > 0 else { return 0 }
          return min(1.0, yearsOld / Double(expected))
      }
  }

  enum MaintenanceStatus: Equatable { case green, yellow, red }

  // MARK: - Test helper

  #if DEBUG
  extension MaintenanceItem {
      static func makeTest(
          id: UUID = UUID(),
          householdId: UUID = UUID(),
          name: String = "Test Item",
          category: MaintenanceCategory = .hvac,
          itemType: MaintenanceItemType = .recurring,
          frequency: MaintenanceFrequency? = .monthly,
          startDate: Date? = nil,
          requiresScheduling: Bool? = false,
          lastCompletedDate: Date? = nil,
          notes: String? = nil,
          description: String? = nil,
          repairStatus: RepairStatus? = nil,
          scheduledDate: Date? = nil,
          contractor: String? = nil,
          estimatedCost: Decimal? = nil,
          actualCost: Decimal? = nil,
          installedDate: Date? = nil,
          expectedLifeYears: Int? = nil,
          brand: String? = nil,
          model: String? = nil,
          intervalDays: Int? = nil,
          templateId: UUID? = nil,
          createdAt: Date = Date(),
          updatedAt: Date = Date()
      ) -> MaintenanceItem {
          MaintenanceItem(
              id: id,
              householdId: householdId,
              name: name,
              category: category,
              itemType: itemType,
              frequency: frequency,
              startDate: startDate,
              requiresScheduling: requiresScheduling,
              lastCompletedDate: lastCompletedDate,
              notes: notes,
              description: description,
              repairStatus: repairStatus,
              scheduledDate: scheduledDate,
              contractor: contractor,
              estimatedCost: estimatedCost,
              actualCost: actualCost,
              installedDate: installedDate,
              expectedLifeYears: expectedLifeYears,
              brand: brand,
              model: model,
              intervalDays: intervalDays,
              templateId: templateId,
              createdAt: createdAt,
              updatedAt: updatedAt
          )
      }
  }
  #endif
  ```

- [ ] **Step 2: Replace MaintenanceLog.swift with MaintenanceCompletionLog**

  Replace the entire contents of `HouseMate/HouseMate/Models/MaintenanceLog.swift`:

  ```swift
  // HouseMate/Models/MaintenanceLog.swift
  import Foundation

  struct MaintenanceCompletionLog: Codable, Identifiable {
      let id: UUID
      let itemId: UUID
      let completedBy: UUID
      var completedAt: Date
      var actualCost: Decimal?
      let householdId: UUID

      enum CodingKeys: String, CodingKey {
          case id
          case itemId = "item_id"
          case completedBy = "completed_by"
          case completedAt = "completed_at"
          case actualCost = "actual_cost"
          case householdId = "household_id"
      }
  }

  // Keep legacy alias for any existing references during migration
  typealias MaintenanceLog = MaintenanceCompletionLog
  ```

- [ ] **Step 3: Build to verify models compile**

  ```bash
  xcodebuild build -scheme HouseMate -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
  ```

  Fix any compilation errors before proceeding.

- [ ] **Step 4: Commit**

  ```bash
  git add HouseMate/HouseMate/Models/MaintenanceItem.swift HouseMate/HouseMate/Models/MaintenanceLog.swift
  git commit -m "feat(maintenance): update models with item types, enums, and computed properties"
  ```

---

### Task 2: Supabase Migration

**Files:** None (SQL executed via Supabase MCP)

- [ ] **Step 1: Run migration to extend maintenance_items table and create maintenance_completion_logs**

  Use the Supabase MCP `apply_migration` tool. The migration name should be `extend_maintenance_items_add_completion_logs`.

  SQL:

  ```sql
  -- Add new columns to maintenance_items
  ALTER TABLE maintenance_items
    ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'recurring',
    ADD COLUMN IF NOT EXISTS frequency TEXT,
    ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS requires_scheduling BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS repair_status TEXT,
    ADD COLUMN IF NOT EXISTS scheduled_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS contractor TEXT,
    ADD COLUMN IF NOT EXISTS estimated_cost NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS actual_cost NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS installed_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS expected_life_years INTEGER,
    ADD COLUMN IF NOT EXISTS brand TEXT,
    ADD COLUMN IF NOT EXISTS model TEXT,
    ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES members(id) NULL;

  -- Backfill frequency from interval_days for existing rows
  UPDATE maintenance_items SET frequency = 'weekly' WHERE interval_days <= 7 AND frequency IS NULL;
  UPDATE maintenance_items SET frequency = 'monthly' WHERE interval_days > 7 AND interval_days <= 31 AND frequency IS NULL;
  UPDATE maintenance_items SET frequency = 'quarterly' WHERE interval_days > 31 AND interval_days <= 91 AND frequency IS NULL;
  UPDATE maintenance_items SET frequency = 'bi_annual' WHERE interval_days > 91 AND interval_days <= 183 AND frequency IS NULL;
  UPDATE maintenance_items SET frequency = 'annual' WHERE interval_days > 183 AND frequency IS NULL;

  -- Create maintenance_completion_logs table
  CREATE TABLE IF NOT EXISTS maintenance_completion_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES maintenance_items(id) ON DELETE CASCADE,
    completed_by UUID NOT NULL REFERENCES members(id),
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    actual_cost NUMERIC(10,2),
    household_id UUID NOT NULL REFERENCES households(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- RLS for maintenance_completion_logs
  ALTER TABLE maintenance_completion_logs ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "Members can view their household completion logs"
    ON maintenance_completion_logs FOR SELECT
    USING (
      household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    );

  CREATE POLICY "Members can insert completion logs for their household"
    ON maintenance_completion_logs FOR INSERT
    WITH CHECK (
      household_id IN (
        SELECT household_id FROM members WHERE user_id = auth.uid()
      )
    );

  CREATE POLICY "Members can delete their own completion logs"
    ON maintenance_completion_logs FOR DELETE
    USING (
      completed_by IN (
        SELECT id FROM members WHERE user_id = auth.uid()
      )
    );

  -- Index for querying logs by item
  CREATE INDEX IF NOT EXISTS idx_maintenance_completion_logs_item_id
    ON maintenance_completion_logs(item_id);

  -- Index for querying items by type
  CREATE INDEX IF NOT EXISTS idx_maintenance_items_item_type
    ON maintenance_items(item_type);
  ```

- [ ] **Step 2: Verify migration applied**

  Use the Supabase MCP `list_tables` tool to confirm `maintenance_completion_logs` table exists.
  Use the Supabase MCP `execute_sql` tool to run:
  ```sql
  SELECT column_name, data_type FROM information_schema.columns
  WHERE table_name = 'maintenance_items' ORDER BY ordinal_position;
  ```
  Confirm all new columns are present.

- [ ] **Step 3: Update RealtimeService to listen for maintenance_completion_logs**

  The existing `RealtimeService.swift` already listens on `maintenance_logs`. We need to add a listener for the new `maintenance_completion_logs` table. Open `HouseMate/HouseMate/Services/RealtimeService.swift` and add after the existing `maintenance_logs` listener block (around line 63):

  ```swift
  ch.onPostgresChange(AnyAction.self, schema: "public", table: "maintenance_completion_logs") { [weak self] _ in
      Task { @MainActor in
          NotificationCenter.default.post(name: RealtimeService.maintenanceChangedNotification.name, object: nil)
      }
  }
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add HouseMate/HouseMate/Services/RealtimeService.swift
  git commit -m "feat(maintenance): add Supabase migration and realtime listener for completion logs"
  ```

---

## Chunk 2: Service Layer

### Task 3: Update MaintenanceService

**Files:**
- Modify: `HouseMate/HouseMate/Services/MaintenanceService.swift`

- [ ] **Step 1: Replace MaintenanceService.swift with full implementation**

  Replace the entire contents of `HouseMate/HouseMate/Services/MaintenanceService.swift`:

  ```swift
  // HouseMate/Services/MaintenanceService.swift
  import Supabase
  import Foundation

  @MainActor
  final class MaintenanceService {

      // MARK: - Items CRUD

      func fetchItems(householdId: UUID) async throws -> [MaintenanceItem] {
          try await supabase
              .from("maintenance_items")
              .select()
              .eq("household_id", value: householdId.uuidString)
              .order("updated_at", ascending: false)
              .execute()
              .value
      }

      func createItem(_ item: MaintenanceItem) async throws -> MaintenanceItem {
          try await supabase
              .from("maintenance_items")
              .insert(item)
              .select()
              .single()
              .execute()
              .value
      }

      func updateItem(_ item: MaintenanceItem) async throws {
          try await supabase
              .from("maintenance_items")
              .update(item)
              .eq("id", value: item.id.uuidString)
              .execute()
      }

      func deleteItem(id: UUID) async throws {
          try await supabase
              .from("maintenance_items")
              .delete()
              .eq("id", value: id.uuidString)
              .execute()
      }

      // MARK: - Completion

      /// Completes an item: inserts a completion log, updates the item's lastCompletedDate,
      /// and for repairs sets repairStatus to .completed.
      /// For recurring items, advances lastCompletedDate so nextDueDate recalculates.
      func completeItem(
          _ item: MaintenanceItem,
          memberId: UUID,
          householdId: UUID,
          actualCost: Decimal?
      ) async throws -> MaintenanceItem {
          // Insert completion log
          let log = MaintenanceCompletionLog(
              id: UUID(),
              itemId: item.id,
              completedBy: memberId,
              completedAt: Date(),
              actualCost: actualCost,
              householdId: householdId
          )
          try await supabase
              .from("maintenance_completion_logs")
              .insert(log)
              .execute()

          // Update the item
          var updated = item
          updated.lastCompletedDate = Date()
          if item.itemType == .repair {
              updated.repairStatus = .completed
              if let cost = actualCost {
                  updated.actualCost = cost
              }
          }
          if item.itemType == .recurring, let cost = actualCost {
              updated.actualCost = cost
          }
          updated.updatedAt = Date()
          try await updateItem(updated)
          return updated
      }

      // MARK: - Scheduling

      /// Sets scheduledDate, contractor, estimatedCost, and for repairs sets repairStatus to .scheduled.
      func scheduleItem(
          _ item: MaintenanceItem,
          date: Date,
          contractor: String?,
          estimatedCost: Decimal?
      ) async throws -> MaintenanceItem {
          var updated = item
          updated.scheduledDate = date
          if let c = contractor, !c.isEmpty {
              updated.contractor = c
          }
          if let cost = estimatedCost {
              updated.estimatedCost = cost
          }
          if item.itemType == .repair {
              updated.repairStatus = .scheduled
          }
          updated.updatedAt = Date()
          try await updateItem(updated)
          return updated
      }

      // MARK: - Completion Logs

      func fetchCompletionLogs(itemId: UUID, limit: Int = 20) async throws -> [MaintenanceCompletionLog] {
          try await supabase
              .from("maintenance_completion_logs")
              .select()
              .eq("item_id", value: itemId.uuidString)
              .order("completed_at", ascending: false)
              .limit(limit)
              .execute()
              .value
      }

      // MARK: - Contractor Suggestions

      /// Returns up to 3 distinct contractor names used for items in the same category,
      /// ordered by most recently updated.
      func fetchContractorSuggestions(householdId: UUID, category: MaintenanceCategory) async throws -> [String] {
          let items: [MaintenanceItem] = try await supabase
              .from("maintenance_items")
              .select()
              .eq("household_id", value: householdId.uuidString)
              .eq("category", value: category.rawValue)
              .not("contractor", operator: .is, value: "null")
              .order("updated_at", ascending: false)
              .limit(10)
              .execute()
              .value

          // Deduplicate and take first 3
          var seen = Set<String>()
          var result: [String] = []
          for item in items {
              if let c = item.contractor, !c.isEmpty, !seen.contains(c.lowercased()) {
                  seen.insert(c.lowercased())
                  result.append(c)
                  if result.count >= 3 { break }
              }
          }
          return result
      }
  }
  ```

- [ ] **Step 2: Build to verify service compiles**

  ```bash
  xcodebuild build -scheme HouseMate -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
  ```

  Fix any compilation errors. Common issues:
  - If the old `MaintenanceLog` type was referenced elsewhere (e.g. `MaintenanceTemplate.swift`), the `typealias` should handle it. If not, update references.
  - If `logCompletion` or `fetchLogs` are called from other files, update those call sites.

- [ ] **Step 3: Commit**

  ```bash
  git add HouseMate/HouseMate/Services/MaintenanceService.swift
  git commit -m "feat(maintenance): update MaintenanceService with completion, scheduling, and contractor suggestions"
  ```

---

## Chunk 3: ViewModels (TDD)

### Task 4: MaintenanceViewModel + Tests

**Files:**
- Create: `HouseMate/HouseMate/ViewModels/MaintenanceViewModel.swift`
- Create: `HouseMate/HouseMateTests/ViewModels/MaintenanceViewModelTests.swift`

- [ ] **Step 1: Create ViewModels directory if needed**

  ```bash
  mkdir -p HouseMate/HouseMate/ViewModels
  mkdir -p HouseMate/HouseMateTests/ViewModels
  ```

- [ ] **Step 2: Write failing tests**

  Create `HouseMate/HouseMateTests/ViewModels/MaintenanceViewModelTests.swift`:

  ```swift
  // HouseMateTests/ViewModels/MaintenanceViewModelTests.swift
  import XCTest
  @testable import HouseMate

  @MainActor
  final class MaintenanceViewModelTests: XCTestCase {
      let householdId = UUID()
      var memberId: UUID!

      override func setUp() {
          super.setUp()
          memberId = UUID()
      }

      // MARK: - Helpers

      func makeRepair(
          name: String = "Fix Leak",
          category: MaintenanceCategory = .plumbing,
          status: RepairStatus = .open,
          scheduledDate: Date? = nil,
          contractor: String? = nil
      ) -> MaintenanceItem {
          MaintenanceItem.makeTest(
              householdId: householdId,
              name: name,
              category: category,
              itemType: .repair,
              frequency: nil,
              repairStatus: status,
              scheduledDate: scheduledDate,
              contractor: contractor
          )
      }

      func makeRecurring(
          name: String = "Change Filter",
          category: MaintenanceCategory = .hvac,
          frequency: MaintenanceFrequency = .monthly,
          startDate: Date? = nil,
          lastCompletedDate: Date? = nil,
          requiresScheduling: Bool = false
      ) -> MaintenanceItem {
          MaintenanceItem.makeTest(
              householdId: householdId,
              name: name,
              category: category,
              itemType: .recurring,
              frequency: frequency,
              startDate: startDate ?? Calendar.current.date(byAdding: .day, value: -60, to: Date()),
              requiresScheduling: requiresScheduling,
              lastCompletedDate: lastCompletedDate
          )
      }

      func makeLifecycle(
          name: String = "Furnace",
          category: MaintenanceCategory = .hvac,
          installedDate: Date? = nil,
          expectedLifeYears: Int = 15,
          brand: String? = "Lennox",
          model: String? = "SL280"
      ) -> MaintenanceItem {
          MaintenanceItem.makeTest(
              householdId: householdId,
              name: name,
              category: category,
              itemType: .lifecycle,
              frequency: nil,
              installedDate: installedDate ?? Calendar.current.date(byAdding: .year, value: -5, to: Date()),
              expectedLifeYears: expectedLifeYears,
              brand: brand,
              model: model
          )
      }

      // MARK: - Type filtering

      func test_repairs_filtersOnlyRepairItems() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          vm.items = [makeRepair(), makeRecurring(), makeLifecycle()]
          vm.selectedType = .repair
          XCTAssertEqual(vm.repairs.count, 1)
          XCTAssertTrue(vm.repairs.allSatisfy { $0.itemType == .repair })
      }

      func test_recurringItems_filtersOnlyRecurringItems() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          vm.items = [makeRepair(), makeRecurring(), makeLifecycle()]
          vm.selectedType = .recurring
          XCTAssertEqual(vm.recurringItems.count, 1)
          XCTAssertTrue(vm.recurringItems.allSatisfy { $0.itemType == .recurring })
      }

      func test_lifecycleItems_filtersOnlyLifecycleItems() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          vm.items = [makeRepair(), makeRecurring(), makeLifecycle()]
          vm.selectedType = .lifecycle
          XCTAssertEqual(vm.lifecycleItems.count, 1)
          XCTAssertTrue(vm.lifecycleItems.allSatisfy { $0.itemType == .lifecycle })
      }

      // MARK: - Category filtering

      func test_categoryFilter_filtersItemsByCategory() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          vm.items = [
              makeRepair(name: "Fix Pipe", category: .plumbing),
              makeRepair(name: "Fix Wiring", category: .electrical),
          ]
          vm.selectedType = .repair
          vm.selectedCategory = .plumbing
          XCTAssertEqual(vm.repairs.count, 1)
          XCTAssertEqual(vm.repairs.first?.name, "Fix Pipe")
      }

      func test_categoryFilter_nil_showsAll() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          vm.items = [
              makeRepair(name: "Fix Pipe", category: .plumbing),
              makeRepair(name: "Fix Wiring", category: .electrical),
          ]
          vm.selectedType = .repair
          vm.selectedCategory = nil
          XCTAssertEqual(vm.repairs.count, 2)
      }

      // MARK: - Show completed toggle

      func test_showCompleted_false_hidesCompletedRepairs() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          vm.items = [
              makeRepair(name: "Open", status: .open),
              makeRepair(name: "Done", status: .completed),
          ]
          vm.selectedType = .repair
          vm.showCompleted = false
          XCTAssertEqual(vm.repairs.count, 1)
          XCTAssertEqual(vm.repairs.first?.name, "Open")
      }

      func test_showCompleted_true_includesCompletedRepairs() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          vm.items = [
              makeRepair(name: "Open", status: .open),
              makeRepair(name: "Done", status: .completed),
          ]
          vm.selectedType = .repair
          vm.showCompleted = true
          XCTAssertEqual(vm.repairs.count, 2)
      }

      // MARK: - Recurring grouping

      func test_overdueRecurring_containsOverdueItems() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          // Start 60 days ago, monthly frequency, never completed → due 30 days ago → overdue
          let overdue = makeRecurring(
              name: "Overdue Filter",
              startDate: Calendar.current.date(byAdding: .day, value: -60, to: Date()),
              lastCompletedDate: nil
          )
          vm.items = [overdue]
          XCTAssertEqual(vm.overdueRecurring.count, 1)
          XCTAssertEqual(vm.overdueRecurring.first?.name, "Overdue Filter")
      }

      func test_upcomingRecurring_containsItemsDueWithin30Days() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          // Completed yesterday, monthly → due in ~29 days → upcoming
          let upcoming = makeRecurring(
              name: "Upcoming Filter",
              lastCompletedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
          )
          vm.items = [upcoming]
          XCTAssertEqual(vm.upcomingRecurring.count, 1)
          XCTAssertEqual(vm.upcomingRecurring.first?.name, "Upcoming Filter")
      }

      func test_laterRecurring_containsItemsDueBeyond30Days() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          // Completed today, quarterly → due in ~90 days → later
          let later = makeRecurring(
              name: "Later Filter",
              frequency: .quarterly,
              lastCompletedDate: Date()
          )
          vm.items = [later]
          XCTAssertEqual(vm.laterRecurring.count, 1)
          XCTAssertEqual(vm.laterRecurring.first?.name, "Later Filter")
      }

      // MARK: - Header counts

      func test_overdueCount_countsOverdueRecurring() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          vm.items = [
              makeRecurring(
                  name: "Overdue",
                  startDate: Calendar.current.date(byAdding: .day, value: -60, to: Date()),
                  lastCompletedDate: nil
              ),
              makeRecurring(
                  name: "Not overdue",
                  lastCompletedDate: Date()
              ),
          ]
          XCTAssertEqual(vm.overdueCount, 1)
      }

      func test_openRepairsCount_countsOpenRepairs() {
          let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
          vm.items = [
              makeRepair(name: "Open1", status: .open),
              makeRepair(name: "Open2", status: .open),
              makeRepair(name: "Scheduled", status: .scheduled),
              makeRepair(name: "Done", status: .completed),
          ]
          XCTAssertEqual(vm.openRepairsCount, 2)
      }
  }
  ```

- [ ] **Step 3: Run tests to verify they fail**

  ```bash
  xcodebuild test \
    -scheme HouseMate \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing HouseMateTests/MaintenanceViewModelTests \
    2>&1 | tail -30
  ```

  Expected: FAIL — `MaintenanceViewModel` not defined.

- [ ] **Step 4: Implement MaintenanceViewModel.swift**

  Create `HouseMate/HouseMate/ViewModels/MaintenanceViewModel.swift`:

  ```swift
  // HouseMate/ViewModels/MaintenanceViewModel.swift
  import Observation
  import Foundation

  @Observable
  @MainActor
  final class MaintenanceViewModel {
      var items: [MaintenanceItem] = []
      var selectedType: MaintenanceItemType = .repair
      var selectedCategory: MaintenanceCategory? = nil
      var showCompleted: Bool = false
      var showLaterSection: Bool = false
      var isLoading = false
      var error: Error?

      private let householdId: UUID
      private let memberId: UUID
      private let service = MaintenanceService()
      private var realtimeObserver: NSObjectProtocol?

      init(householdId: UUID, memberId: UUID) {
          self.householdId = householdId
          self.memberId = memberId
      }

      // MARK: - Filtered lists

      private func applyFilters(_ items: [MaintenanceItem], type: MaintenanceItemType) -> [MaintenanceItem] {
          var filtered = items.filter { $0.itemType == type }
          if let cat = selectedCategory {
              filtered = filtered.filter { $0.category == cat }
          }
          return filtered
      }

      var repairs: [MaintenanceItem] {
          var result = applyFilters(items, type: .repair)
          if !showCompleted {
              result = result.filter { $0.repairStatus != .completed }
          }
          return result.sorted { a, b in
              // Open before scheduled before completed
              let order: [RepairStatus: Int] = [.open: 0, .scheduled: 1, .completed: 2]
              let aOrder = order[a.repairStatus ?? .open] ?? 0
              let bOrder = order[b.repairStatus ?? .open] ?? 0
              if aOrder != bOrder { return aOrder < bOrder }
              return a.updatedAt > b.updatedAt
          }
      }

      var recurringItems: [MaintenanceItem] {
          applyFilters(items, type: .recurring)
      }

      var lifecycleItems: [MaintenanceItem] {
          applyFilters(items, type: .lifecycle).sorted { a, b in
              // Replace Soon first, then Watch, then Good
              let order: [MaintenanceAgeStatus: Int] = [.replaceSoon: 0, .watch: 1, .good: 2]
              let aOrder = order[a.ageStatus] ?? 2
              let bOrder = order[b.ageStatus] ?? 2
              if aOrder != bOrder { return aOrder < bOrder }
              return a.yearsRemaining < b.yearsRemaining
          }
      }

      // MARK: - Recurring grouping

      var overdueRecurring: [MaintenanceItem] {
          recurringItems.filter { $0.isOverdue }
              .sorted { ($0.nextDueDate ?? .distantPast) < ($1.nextDueDate ?? .distantPast) }
      }

      var upcomingRecurring: [MaintenanceItem] {
          let today = Calendar.current.startOfDay(for: Date())
          let thirtyDaysOut = Calendar.current.date(byAdding: .day, value: 30, to: today)!
          return recurringItems.filter { item in
              guard let next = item.nextDueDate else { return false }
              return next >= today && next <= thirtyDaysOut
          }.sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
      }

      var laterRecurring: [MaintenanceItem] {
          let today = Calendar.current.startOfDay(for: Date())
          let thirtyDaysOut = Calendar.current.date(byAdding: .day, value: 30, to: today)!
          return recurringItems.filter { item in
              guard let next = item.nextDueDate else { return false }
              return next > thirtyDaysOut
          }.sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
      }

      // MARK: - Header counts

      var overdueCount: Int {
          items.filter { $0.itemType == .recurring && $0.isOverdue }.count
      }

      var openRepairsCount: Int {
          items.filter { $0.itemType == .repair && $0.repairStatus == .open }.count
      }

      var headerSubtitle: String {
          var parts: [String] = []
          if overdueCount > 0 { parts.append("\(overdueCount) overdue") }
          if openRepairsCount > 0 { parts.append("\(openRepairsCount) open repairs") }
          return parts.isEmpty ? "All good" : parts.joined(separator: " · ")
      }

      // MARK: - Data operations

      func load() async {
          isLoading = true
          error = nil
          do {
              items = try await service.fetchItems(householdId: householdId)
          } catch {
              self.error = error
          }
          isLoading = false
      }

      func completeItem(_ item: MaintenanceItem, actualCost: Decimal?) async {
          do {
              let updated = try await service.completeItem(
                  item,
                  memberId: memberId,
                  householdId: householdId,
                  actualCost: actualCost
              )
              if let index = items.firstIndex(where: { $0.id == item.id }) {
                  items[index] = updated
              }
          } catch {
              self.error = error
          }
      }

      func scheduleItem(_ item: MaintenanceItem, date: Date, contractor: String?, estimatedCost: Decimal?) async {
          do {
              let updated = try await service.scheduleItem(
                  item,
                  date: date,
                  contractor: contractor,
                  estimatedCost: estimatedCost
              )
              if let index = items.firstIndex(where: { $0.id == item.id }) {
                  items[index] = updated
              }
          } catch {
              self.error = error
          }
      }

      func deleteItem(_ item: MaintenanceItem) async {
          do {
              try await service.deleteItem(id: item.id)
              items.removeAll { $0.id == item.id }
          } catch {
              self.error = error
          }
      }

      func itemAdded(_ item: MaintenanceItem) {
          items.insert(item, at: 0)
      }

      func itemUpdated(_ item: MaintenanceItem) {
          if let index = items.firstIndex(where: { $0.id == item.id }) {
              items[index] = item
          }
      }

      // MARK: - Realtime

      func subscribeToRealtime() {
          realtimeObserver = NotificationCenter.default.addObserver(
              forName: RealtimeService.maintenanceChangedNotification.name,
              object: nil, queue: .main
          ) { [weak self] _ in
              Task { @MainActor [weak self] in await self?.load() }
          }
      }

      func unsubscribeFromRealtime() {
          if let observer = realtimeObserver {
              NotificationCenter.default.removeObserver(observer)
              realtimeObserver = nil
          }
      }
  }
  ```

- [ ] **Step 5: Add both files to the Xcode project**

  Open the Xcode project and add:
  - `HouseMate/HouseMate/ViewModels/MaintenanceViewModel.swift` to the HouseMate target
  - `HouseMate/HouseMateTests/ViewModels/MaintenanceViewModelTests.swift` to the HouseMateTests target

  Alternatively, if the project uses folder references, the files may be auto-discovered. Verify by building.

- [ ] **Step 6: Run tests to verify they pass**

  ```bash
  xcodebuild test \
    -scheme HouseMate \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing HouseMateTests/MaintenanceViewModelTests \
    2>&1 | tail -30
  ```

  All tests should pass. Fix any failures before proceeding.

- [ ] **Step 7: Commit**

  ```bash
  git add HouseMate/HouseMate/ViewModels/MaintenanceViewModel.swift HouseMateTests/ViewModels/MaintenanceViewModelTests.swift
  git commit -m "feat(maintenance): add MaintenanceViewModel with filtering, grouping, and Realtime integration"
  ```

---

### Task 5: MaintenanceFormViewModel + Tests

**Files:**
- Create: `HouseMate/HouseMate/ViewModels/MaintenanceFormViewModel.swift`
- Create: `HouseMate/HouseMateTests/ViewModels/MaintenanceFormViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `HouseMate/HouseMateTests/ViewModels/MaintenanceFormViewModelTests.swift`:

  ```swift
  // HouseMateTests/ViewModels/MaintenanceFormViewModelTests.swift
  import XCTest
  @testable import HouseMate

  @MainActor
  final class MaintenanceFormViewModelTests: XCTestCase {
      let householdId = UUID()
      var memberId: UUID!

      override func setUp() {
          super.setUp()
          memberId = UUID()
      }

      // MARK: - Defaults

      func test_newForm_defaultsToRepairType() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          XCTAssertEqual(vm.itemType, .repair)
      }

      func test_newForm_hasEmptyTitle() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          XCTAssertEqual(vm.name, "")
      }

      func test_newRecurring_defaultsToMonthlyFrequency() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.itemType = .recurring
          XCTAssertEqual(vm.frequency, .monthly)
      }

      func test_newRecurring_defaultsStartDateToToday() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.itemType = .recurring
          let today = Calendar.current.startOfDay(for: Date())
          let startDay = Calendar.current.startOfDay(for: vm.startDate)
          XCTAssertEqual(startDay, today)
      }

      // MARK: - Smart defaults for lifecycle

      func test_lifecycleSmartDefault_furnace() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.itemType = .lifecycle
          vm.name = "Furnace"
          XCTAssertEqual(vm.smartExpectedLifeYears, 15)
      }

      func test_lifecycleSmartDefault_roof() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.itemType = .lifecycle
          vm.name = "Roof"
          XCTAssertEqual(vm.smartExpectedLifeYears, 20)
      }

      func test_lifecycleSmartDefault_waterHeater() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.itemType = .lifecycle
          vm.name = "Water Heater"
          XCTAssertEqual(vm.smartExpectedLifeYears, 10)
      }

      func test_lifecycleSmartDefault_acUnit() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.itemType = .lifecycle
          vm.name = "AC Unit"
          XCTAssertEqual(vm.smartExpectedLifeYears, 15)
      }

      func test_lifecycleSmartDefault_unknown() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.itemType = .lifecycle
          vm.name = "Something Else"
          XCTAssertEqual(vm.smartExpectedLifeYears, 10)
      }

      // MARK: - Title suggestions

      func test_titleSuggestions_hvac() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.category = .hvac
          XCTAssertTrue(vm.titleSuggestions.contains("Change Filter"))
          XCTAssertTrue(vm.titleSuggestions.contains("HVAC Tune-up"))
      }

      func test_titleSuggestions_exterior() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.category = .exterior
          XCTAssertTrue(vm.titleSuggestions.contains("Clean Gutters"))
          XCTAssertTrue(vm.titleSuggestions.contains("Inspect Roof"))
      }

      func test_titleSuggestions_vehicle() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.category = .vehicle
          XCTAssertTrue(vm.titleSuggestions.contains("Oil Change"))
          XCTAssertTrue(vm.titleSuggestions.contains("Tire Rotation"))
      }

      // MARK: - canSave

      func test_canSave_requiresNonEmptyName() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          XCTAssertFalse(vm.canSave)
          vm.name = "  "
          XCTAssertFalse(vm.canSave)
          vm.name = "Fix Leak"
          XCTAssertTrue(vm.canSave)
      }

      func test_canSave_lifecycleRequiresExpectedLife() {
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId)
          vm.itemType = .lifecycle
          vm.name = "Furnace"
          vm.expectedLifeYears = 0
          XCTAssertFalse(vm.canSave)
          vm.expectedLifeYears = 15
          XCTAssertTrue(vm.canSave)
      }

      // MARK: - Edit mode

      func test_editForm_populatesFromRepair() {
          let repair = MaintenanceItem.makeTest(
              name: "Fix Pipe",
              category: .plumbing,
              itemType: .repair,
              frequency: nil,
              repairStatus: .open,
              contractor: "Joe's Plumbing",
              estimatedCost: 150.00
          )
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId, editingItem: repair)
          XCTAssertEqual(vm.name, "Fix Pipe")
          XCTAssertEqual(vm.category, .plumbing)
          XCTAssertEqual(vm.itemType, .repair)
          XCTAssertEqual(vm.contractor, "Joe's Plumbing")
          XCTAssertEqual(vm.estimatedCost, 150.00)
          XCTAssertTrue(vm.isEditing)
      }

      func test_editForm_populatesFromRecurring() {
          let recurring = MaintenanceItem.makeTest(
              name: "Change Filter",
              category: .hvac,
              itemType: .recurring,
              frequency: .quarterly,
              requiresScheduling: true
          )
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId, editingItem: recurring)
          XCTAssertEqual(vm.name, "Change Filter")
          XCTAssertEqual(vm.frequency, .quarterly)
          XCTAssertEqual(vm.requiresScheduling, true)
      }

      func test_editForm_typeCannotChange() {
          let repair = MaintenanceItem.makeTest(itemType: .repair, frequency: nil, repairStatus: .open)
          let vm = MaintenanceFormViewModel(householdId: householdId, memberId: memberId, editingItem: repair)
          XCTAssertTrue(vm.isEditing)
          // Type is locked in edit mode — the view should disable the picker
          XCTAssertEqual(vm.itemType, .repair)
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

  ```bash
  xcodebuild test \
    -scheme HouseMate \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing HouseMateTests/MaintenanceFormViewModelTests \
    2>&1 | tail -30
  ```

  Expected: FAIL — `MaintenanceFormViewModel` not defined.

- [ ] **Step 3: Implement MaintenanceFormViewModel.swift**

  Create `HouseMate/HouseMate/ViewModels/MaintenanceFormViewModel.swift`:

  ```swift
  // HouseMate/ViewModels/MaintenanceFormViewModel.swift
  import Observation
  import Foundation

  @Observable
  @MainActor
  final class MaintenanceFormViewModel {
      // MARK: - Form fields

      var itemType: MaintenanceItemType = .repair
      var name: String = ""
      var category: MaintenanceCategory = .hvac
      var notes: String = ""

      // Recurring fields
      var frequency: MaintenanceFrequency = .monthly
      var startDate: Date = Date()
      var requiresScheduling: Bool = false

      // Assign-to (repair and recurring only)
      var assignedTo: UUID? = nil

      // Repair fields
      var description: String = ""
      var contractor: String = ""
      var estimatedCost: Decimal? = nil
      var estimatedCostString: String = ""

      // Lifecycle fields
      var installedDate: Date = Date()
      var expectedLifeYears: Int = 10
      var brand: String = ""
      var model: String = ""

      // State
      var contractorSuggestions: [String] = []
      var isSaving = false
      var saveError: Error?

      // Private
      private let householdId: UUID
      private let memberId: UUID
      private let editingItem: MaintenanceItem?
      private let service = MaintenanceService()

      var isEditing: Bool { editingItem != nil }

      // MARK: - Init

      init(householdId: UUID, memberId: UUID, editingItem: MaintenanceItem? = nil, lastUsedCategory: MaintenanceCategory? = nil) {
          self.householdId = householdId
          self.memberId = memberId
          self.editingItem = editingItem

          if let item = editingItem {
              itemType = item.itemType
              name = item.name
              category = item.category
              notes = item.notes ?? ""

              // Recurring
              frequency = item.frequency ?? .monthly
              startDate = item.startDate ?? Date()
              requiresScheduling = item.requiresScheduling ?? false

              // Assign-to
              assignedTo = item.assignedTo

              // Repair
              description = item.description ?? ""
              contractor = item.contractor ?? ""
              estimatedCost = item.estimatedCost
              if let cost = item.estimatedCost {
                  estimatedCostString = "\(cost)"
              }

              // Lifecycle
              installedDate = item.installedDate ?? Date()
              expectedLifeYears = item.expectedLifeYears ?? 10
              brand = item.brand ?? ""
              model = item.model ?? ""
          } else if let lastCat = lastUsedCategory {
              category = lastCat
          }
      }

      // MARK: - Smart defaults

      var smartExpectedLifeYears: Int {
          let lowered = name.lowercased()
          if lowered.contains("furnace") || lowered.contains("boiler") { return 15 }
          if lowered.contains("roof") { return 20 }
          if lowered.contains("water heater") { return 10 }
          if lowered.contains("ac unit") || lowered.contains("air condition") { return 15 }
          return 10
      }

      // MARK: - Title suggestions

      var titleSuggestions: [String] {
          switch category {
          case .hvac:
              return ["Change Filter", "HVAC Tune-up", "Inspect Ducts", "Clean Vents"]
          case .exterior:
              return ["Clean Gutters", "Inspect Roof", "Power Wash", "Check Caulking"]
          case .electrical:
              return ["Check GFCIs", "Test Smoke Detectors", "Inspect Panel"]
          case .plumbing:
              return ["Check Water Heater", "Snake Drain", "Inspect Supply Lines"]
          case .structural:
              return ["Inspect Foundation", "Check Attic Insulation"]
          case .vehicle:
              return ["Oil Change", "Tire Rotation", "Check Brakes", "Annual Service"]
          }
      }

      // MARK: - Validation

      var canSave: Bool {
          let trimmed = name.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else { return false }
          if itemType == .lifecycle && expectedLifeYears <= 0 { return false }
          return true
      }

      // MARK: - Load contractor suggestions

      func loadContractorSuggestions() async {
          do {
              contractorSuggestions = try await service.fetchContractorSuggestions(
                  householdId: householdId,
                  category: category
              )
          } catch {
              contractorSuggestions = []
          }
      }

      // MARK: - Save

      /// Creates or updates the item. Returns the saved item on success, nil on failure.
      func save() async -> MaintenanceItem? {
          guard canSave else { return nil }
          isSaving = true
          saveError = nil

          // Parse estimated cost from string
          let parsedCost: Decimal? = Decimal(string: estimatedCostString)

          do {
              let result: MaintenanceItem
              if let existing = editingItem {
                  var updated = existing
                  updated.name = name.trimmingCharacters(in: .whitespaces)
                  updated.category = category
                  updated.notes = notes.isEmpty ? nil : notes
                  updated.updatedAt = Date()

                  switch itemType {
                  case .repair:
                      updated.description = description.isEmpty ? nil : description
                      updated.contractor = contractor.isEmpty ? nil : contractor
                      updated.estimatedCost = parsedCost ?? estimatedCost
                  case .recurring:
                      updated.frequency = frequency
                      updated.startDate = startDate
                      updated.requiresScheduling = requiresScheduling
                      updated.intervalDays = frequency.intervalDays
                  case .lifecycle:
                      updated.installedDate = installedDate
                      updated.expectedLifeYears = expectedLifeYears
                      updated.brand = brand.isEmpty ? nil : brand
                      updated.model = model.isEmpty ? nil : model
                  }

                  try await service.updateItem(updated)
                  result = updated
              } else {
                  let newItem = MaintenanceItem(
                      id: UUID(),
                      householdId: householdId,
                      name: name.trimmingCharacters(in: .whitespaces),
                      category: category,
                      itemType: itemType,
                      frequency: itemType == .recurring ? frequency : nil,
                      startDate: itemType == .recurring ? startDate : nil,
                      requiresScheduling: itemType == .recurring ? requiresScheduling : nil,
                      lastCompletedDate: nil,
                      notes: notes.isEmpty ? nil : notes,
                      description: itemType == .repair ? (description.isEmpty ? nil : description) : nil,
                      repairStatus: itemType == .repair ? .open : nil,
                      scheduledDate: nil,
                      contractor: (itemType == .repair || itemType == .recurring) ? (contractor.isEmpty ? nil : contractor) : nil,
                      estimatedCost: itemType == .repair ? (parsedCost ?? estimatedCost) : nil,
                      actualCost: nil,
                      installedDate: itemType == .lifecycle ? installedDate : nil,
                      expectedLifeYears: itemType == .lifecycle ? expectedLifeYears : nil,
                      brand: itemType == .lifecycle ? (brand.isEmpty ? nil : brand) : nil,
                      model: itemType == .lifecycle ? (model.isEmpty ? nil : model) : nil,
                      intervalDays: itemType == .recurring ? frequency.intervalDays : nil,
                      templateId: nil,
                      createdAt: Date(),
                      updatedAt: Date()
                  )
                  result = try await service.createItem(newItem)
              }
              isSaving = false
              return result
          } catch {
              saveError = error
              isSaving = false
              return nil
          }
      }
  }
  ```

- [ ] **Step 4: Add file to Xcode project and run tests**

  ```bash
  xcodebuild test \
    -scheme HouseMate \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing HouseMateTests/MaintenanceFormViewModelTests \
    2>&1 | tail -30
  ```

  All tests should pass.

- [ ] **Step 5: Run all ViewModel tests together**

  ```bash
  xcodebuild test \
    -scheme HouseMate \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing HouseMateTests/MaintenanceViewModelTests \
    -only-testing HouseMateTests/MaintenanceFormViewModelTests \
    2>&1 | tail -30
  ```

- [ ] **Step 6: Commit**

  ```bash
  git add HouseMate/HouseMate/ViewModels/MaintenanceFormViewModel.swift HouseMateTests/ViewModels/MaintenanceFormViewModelTests.swift
  git commit -m "feat(maintenance): add MaintenanceFormViewModel with smart defaults, suggestions, and validation"
  ```

---

## Chunk 4: Views

### Task 6: MaintenanceItemRowView

**Files:**
- Create: `HouseMate/HouseMate/Views/Maintenance/MaintenanceItemRowView.swift`

- [ ] **Step 1: Create Maintenance views directory**

  ```bash
  mkdir -p HouseMate/HouseMate/Views/Maintenance
  ```

- [ ] **Step 2: Create MaintenanceItemRowView.swift**

  ```swift
  // HouseMate/Views/Maintenance/MaintenanceItemRowView.swift
  import SwiftUI

  struct MaintenanceItemRowView: View {
      let item: MaintenanceItem
      let members: [Member]
      let onEdit: () -> Void
      let onComplete: (() -> Void)?
      let onSchedule: (() -> Void)?
      let onDelete: () -> Void

      var body: some View {
          Group {
              switch item.itemType {
              case .repair:
                  repairRow
              case .recurring:
                  recurringRow
              case .lifecycle:
                  lifecycleRow
              }
          }
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(role: .destructive) {
                  onDelete()
              } label: {
                  Label("Delete", systemImage: "trash")
              }
          }
          .swipeActions(edge: .leading, allowsFullSwipe: true) {
              if item.itemType != .lifecycle, let onComplete {
                  Button {
                      onComplete()
                  } label: {
                      Label("Complete", systemImage: "checkmark.circle.fill")
                  }
                  .tint(.green)
              }
          }
      }

      // MARK: - Repair Row

      private var repairRow: some View {
          HStack(spacing: 12) {
              Image(systemName: item.category.iconName)
                  .font(.title3)
                  .foregroundStyle(repairStatusColor)
                  .frame(width: 32)

              VStack(alignment: .leading, spacing: 4) {
                  Text(item.name)
                      .font(.body.weight(.medium))

                  HStack(spacing: 6) {
                      categoryChip
                      statusChip
                  }

                  if let contractor = item.contractor, !contractor.isEmpty {
                      Text(contractor)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                  }

                  if let desc = item.description, !desc.isEmpty {
                      Text(desc)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                          .lineLimit(2)
                  }

                  if let cost = item.estimatedCost {
                      Text("Est. $\(cost as NSDecimalNumber)")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                  }
              }

              Spacer()

              VStack(alignment: .trailing, spacing: 4) {
                  if item.repairStatus == .open || item.repairStatus == .scheduled {
                      if let onSchedule, item.repairStatus == .open {
                          Button("Schedule It") {
                              onSchedule()
                          }
                          .font(.caption.weight(.semibold))
                          .buttonStyle(.bordered)
                          .controlSize(.small)
                      }
                  }

                  // Small member avatar (repair and recurring only)
                  if let assigneeId = item.assignedTo,
                     let member = members.first(where: { $0.id == assigneeId }) {
                      Circle()
                          .fill(Color.accentColor.opacity(0.2))
                          .frame(width: 24, height: 24)
                          .overlay(
                              Text(String(member.displayName.prefix(1)))
                                  .font(.caption2.bold())
                                  .foregroundStyle(.accentColor)
                          )
                  }

                  Button { onEdit() } label: {
                      Image(systemName: "pencil")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                  }
                  .buttonStyle(.plain)
              }
          }
          .padding(.vertical, 4)
      }

      private var repairStatusColor: Color {
          switch item.repairStatus {
          case .open: return .orange
          case .scheduled: return .blue
          case .completed: return .green
          case .none: return .gray
          }
      }

      private var statusChip: some View {
          Text(item.repairStatus?.displayName ?? "Open")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(repairStatusColor.opacity(0.15))
              .foregroundStyle(repairStatusColor)
              .clipShape(Capsule())
      }

      // MARK: - Recurring Row

      private var recurringRow: some View {
          HStack(spacing: 12) {
              Image(systemName: item.category.iconName)
                  .font(.title3)
                  .foregroundStyle(recurringDueDateColor)
                  .frame(width: 32)

              VStack(alignment: .leading, spacing: 4) {
                  Text(item.name)
                      .font(.body.weight(.medium))

                  HStack(spacing: 6) {
                      categoryChip
                      frequencyChip
                  }

                  if let next = item.nextDueDate {
                      Text(dueDateText(next))
                          .font(.caption)
                          .foregroundStyle(recurringDueDateColor)
                  }

                  if let last = item.lastCompletedDate {
                      Text("Last: \(last.formatted(date: .abbreviated, time: .omitted))")
                          .font(.caption2)
                          .foregroundStyle(.secondary)
                  }

                  if let notes = item.notes, !notes.isEmpty {
                      Text(notes)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                          .lineLimit(1)
                  }
              }

              Spacer()

              VStack(alignment: .trailing, spacing: 4) {
                  if item.requiresScheduling == true, item.scheduledDate == nil, let onSchedule {
                      Button("Schedule It") {
                          onSchedule()
                      }
                      .font(.caption.weight(.semibold))
                      .buttonStyle(.bordered)
                      .controlSize(.small)
                  }

                  // Small member avatar (repair and recurring only)
                  if let assigneeId = item.assignedTo,
                     let member = members.first(where: { $0.id == assigneeId }) {
                      Circle()
                          .fill(Color.accentColor.opacity(0.2))
                          .frame(width: 24, height: 24)
                          .overlay(
                              Text(String(member.displayName.prefix(1)))
                                  .font(.caption2.bold())
                                  .foregroundStyle(.accentColor)
                          )
                  }

                  Button { onEdit() } label: {
                      Image(systemName: "pencil")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                  }
                  .buttonStyle(.plain)
              }
          }
          .padding(.vertical, 4)
      }

      private var recurringDueDateColor: Color {
          guard let next = item.nextDueDate else { return .red }
          let today = Calendar.current.startOfDay(for: Date())
          if next < today { return .red }
          return .green
      }

      private func dueDateText(_ date: Date) -> String {
          let today = Calendar.current.startOfDay(for: Date())
          let days = Calendar.current.dateComponents([.day], from: today, to: date).day ?? 0
          if days < 0 { return "\(abs(days))d overdue" }
          if days == 0 { return "Due today" }
          if days == 1 { return "Due tomorrow" }
          return "Due in \(days) days"
      }

      private var frequencyChip: some View {
          Text(item.frequency?.displayName ?? "")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.purple.opacity(0.12))
              .foregroundStyle(.purple)
              .clipShape(Capsule())
      }

      // MARK: - Lifecycle Row

      private var lifecycleRow: some View {
          HStack(spacing: 12) {
              Image(systemName: item.category.iconName)
                  .font(.title3)
                  .foregroundStyle(ageStatusColor)
                  .frame(width: 32)

              VStack(alignment: .leading, spacing: 4) {
                  HStack {
                      Text(item.name)
                          .font(.body.weight(.medium))
                      if let b = item.brand, !b.isEmpty {
                          Text(b)
                              .font(.caption)
                              .foregroundStyle(.secondary)
                      }
                      if let m = item.model, !m.isEmpty {
                          Text(m)
                              .font(.caption)
                              .foregroundStyle(.secondary)
                      }
                  }

                  HStack(spacing: 6) {
                      categoryChip
                      ageStatusBadge
                  }

                  if let installed = item.installedDate {
                      Text("Installed \(installed.formatted(.dateTime.year()))")
                          .font(.caption2)
                          .foregroundStyle(.secondary)
                  }

                  ProgressView(value: item.ageProgress)
                      .tint(ageStatusColor)

                  Text("\(String(format: "%.0f", item.yearsOld)) yrs old · ~\(String(format: "%.0f", item.yearsRemaining)) yr left")
                      .font(.caption2)
                      .foregroundStyle(.secondary)

                  if let notes = item.notes, !notes.isEmpty {
                      Text(notes)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                          .lineLimit(1)
                  }
              }

              Spacer()

              Button { onEdit() } label: {
                  Image(systemName: "pencil")
                      .font(.caption)
                      .foregroundStyle(.secondary)
              }
              .buttonStyle(.plain)
          }
          .padding(.vertical, 4)
      }

      private var ageStatusColor: Color {
          switch item.ageStatus {
          case .good: return .green
          case .watch: return .orange
          case .replaceSoon: return .red
          }
      }

      private var ageStatusBadge: some View {
          Text(item.ageStatus.displayName)
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(ageStatusColor.opacity(0.15))
              .foregroundStyle(ageStatusColor)
              .clipShape(Capsule())
      }

      // MARK: - Shared

      private var categoryChip: some View {
          Label(item.category.displayName, systemImage: item.category.iconName)
              .font(.caption2)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.gray.opacity(0.12))
              .clipShape(Capsule())
      }
  }
  ```

- [ ] **Step 3: Build to verify it compiles**

  ```bash
  xcodebuild build -scheme HouseMate -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add HouseMate/HouseMate/Views/Maintenance/MaintenanceItemRowView.swift
  git commit -m "feat(maintenance): add MaintenanceItemRowView supporting all 3 item types"
  ```

---

### Task 7: MaintenanceListView + Wire MainTabView

**Files:**
- Create: `HouseMate/HouseMate/Views/Maintenance/MaintenanceListView.swift`
- Modify: `HouseMate/HouseMate/Views/Main/MainTabView.swift`

- [ ] **Step 1: Create MaintenanceListView.swift**

  ```swift
  // HouseMate/Views/Maintenance/MaintenanceListView.swift
  import SwiftUI

  struct MaintenanceListView: View {
      @Environment(AppState.self) private var appState
      @State private var viewModel: MaintenanceViewModel?
      @State private var showingForm = false
      @State private var editingItem: MaintenanceItem?
      @State private var completingItem: MaintenanceItem?
      @State private var schedulingItem: MaintenanceItem?
      @State private var deletingItem: MaintenanceItem?
      @State private var showDeleteConfirmation = false

      private var vm: MaintenanceViewModel? { viewModel }

      var body: some View {
          NavigationStack {
              Group {
                  if let vm {
                      mainContent(vm: vm)
                  } else {
                      ProgressView("Loading…")
                  }
              }
              .navigationTitle("Maintenance")
              .toolbar {
                  ToolbarItem(placement: .topBarTrailing) {
                      Button {
                          showingForm = true
                      } label: {
                          Image(systemName: "plus")
                      }
                  }
              }
          }
          .task {
              guard let householdId = appState.household?.id,
                    let memberId = appState.currentMember?.id else { return }
              let vm = MaintenanceViewModel(householdId: householdId, memberId: memberId)
              self.viewModel = vm
              await vm.load()
              vm.subscribeToRealtime()
          }
          .sheet(isPresented: $showingForm) {
              if let householdId = appState.household?.id,
                 let memberId = appState.currentMember?.id {
                  MaintenanceFormView(
                      householdId: householdId,
                      memberId: memberId,
                      editingItem: nil,
                      members: appState.members
                  ) { newItem in
                      viewModel?.itemAdded(newItem)
                  }
              }
          }
          .sheet(item: $editingItem) { item in
              if let householdId = appState.household?.id,
                 let memberId = appState.currentMember?.id {
                  MaintenanceFormView(
                      householdId: householdId,
                      memberId: memberId,
                      editingItem: item,
                      members: appState.members
                  ) { updated in
                      viewModel?.itemUpdated(updated)
                  }
              }
          }
          .sheet(item: $completingItem) { item in
              MaintenanceCompletionSheet(item: item) { actualCost in
                  Task {
                      await viewModel?.completeItem(item, actualCost: actualCost)
                  }
              }
          }
          .sheet(item: $schedulingItem) { item in
              if let householdId = appState.household?.id {
                  MaintenanceScheduleSheet(
                      item: item,
                      householdId: householdId
                  ) { date, contractor, estimatedCost in
                      Task {
                          await viewModel?.scheduleItem(item, date: date, contractor: contractor, estimatedCost: estimatedCost)
                      }
                  }
              }
          }
          .alert("Delete Item?", isPresented: $showDeleteConfirmation, presenting: deletingItem) { item in
              Button("Delete", role: .destructive) {
                  Task { await viewModel?.deleteItem(item) }
              }
              Button("Cancel", role: .cancel) { }
          } message: { item in
              Text("Are you sure you want to delete \"\(item.name)\"? This cannot be undone.")
          }
      }

      @ViewBuilder
      private func mainContent(vm: MaintenanceViewModel) -> some View {
          VStack(spacing: 0) {
              // Header subtitle
              Text(vm.headerSubtitle)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal)
                  .padding(.top, 4)

              // Category filter bar
              categoryFilterBar(vm: vm)

              // Type tabs
              typeTabs(vm: vm)

              // List
              List {
                  switch vm.selectedType {
                  case .repair:
                      repairSection(vm: vm)
                  case .recurring:
                      recurringSection(vm: vm)
                  case .lifecycle:
                      lifecycleSection(vm: vm)
                  }
              }
              .listStyle(.plain)
              .refreshable {
                  await vm.load()
              }
          }
      }

      // MARK: - Category Filter Bar

      private func categoryFilterBar(vm: MaintenanceViewModel) -> some View {
          ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                  // "All" chip
                  filterChip(title: "All", isSelected: vm.selectedCategory == nil) {
                      vm.selectedCategory = nil
                  }

                  ForEach(MaintenanceCategory.allCases) { cat in
                      filterChip(
                          title: cat.displayName,
                          icon: cat.iconName,
                          isSelected: vm.selectedCategory == cat
                      ) {
                          vm.selectedCategory = cat
                      }
                  }

                  // Show completed toggle
                  filterChip(
                      title: vm.showCompleted ? "Hide Done" : "Show Done",
                      icon: "checkmark.circle",
                      isSelected: vm.showCompleted
                  ) {
                      vm.showCompleted.toggle()
                  }
              }
              .padding(.horizontal)
              .padding(.vertical, 8)
          }
      }

      private func filterChip(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
          Button(action: action) {
              HStack(spacing: 4) {
                  if let icon {
                      Image(systemName: icon)
                          .font(.caption2)
                  }
                  Text(title)
                      .font(.caption.weight(.medium))
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
              .foregroundStyle(isSelected ? Color.accentColor : .primary)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
      }

      // MARK: - Type Tabs

      private func typeTabs(vm: MaintenanceViewModel) -> some View {
          HStack(spacing: 0) {
              typeTab(vm: vm, type: .repair, count: vm.repairs.count)
              typeTab(vm: vm, type: .recurring, count: vm.recurringItems.count)
              typeTab(vm: vm, type: .lifecycle, count: vm.lifecycleItems.count)
          }
          .padding(.horizontal)
      }

      private func typeTab(vm: MaintenanceViewModel, type: MaintenanceItemType, count: Int) -> some View {
          Button {
              vm.selectedType = type
          } label: {
              VStack(spacing: 4) {
                  Text("\(type.displayName) (\(count))")
                      .font(.subheadline.weight(vm.selectedType == type ? .semibold : .regular))
                      .foregroundStyle(vm.selectedType == type ? .primary : .secondary)
                  Rectangle()
                      .fill(vm.selectedType == type ? Color.accentColor : Color.clear)
                      .frame(height: 2)
              }
          }
          .buttonStyle(.plain)
          .frame(maxWidth: .infinity)
      }

      // MARK: - Sections

      @ViewBuilder
      private func repairSection(vm: MaintenanceViewModel) -> some View {
          if vm.repairs.isEmpty {
              ContentUnavailableView("No Repairs", systemImage: "wrench.and.screwdriver", description: Text("Tap + to add a repair item"))
          } else {
              ForEach(vm.repairs) { item in
                  MaintenanceItemRowView(
                      item: item,
                      members: appState.members,
                      onEdit: { editingItem = item },
                      onComplete: item.repairStatus != .completed ? { handleComplete(item) } : nil,
                      onSchedule: item.repairStatus == .open ? { schedulingItem = item } : nil,
                      onDelete: { deletingItem = item; showDeleteConfirmation = true }
                  )
              }
          }
      }

      @ViewBuilder
      private func recurringSection(vm: MaintenanceViewModel) -> some View {
          if !vm.overdueRecurring.isEmpty {
              Section("Overdue") {
                  ForEach(vm.overdueRecurring) { item in
                      recurringRow(item)
                  }
              }
          }
          if !vm.upcomingRecurring.isEmpty {
              Section("Upcoming") {
                  ForEach(vm.upcomingRecurring) { item in
                      recurringRow(item)
                  }
              }
          }
          if !vm.laterRecurring.isEmpty {
              Section {
                  if vm.showLaterSection {
                      ForEach(vm.laterRecurring) { item in
                          recurringRow(item)
                      }
                  }
              } header: {
                  Button {
                      vm.showLaterSection.toggle()
                  } label: {
                      HStack {
                          Text("Later This Year")
                          Spacer()
                          Image(systemName: vm.showLaterSection ? "chevron.up" : "chevron.down")
                      }
                  }
              }
          }
          if vm.overdueRecurring.isEmpty && vm.upcomingRecurring.isEmpty && vm.laterRecurring.isEmpty {
              ContentUnavailableView("No Recurring Items", systemImage: "repeat", description: Text("Tap + to add a recurring maintenance item"))
          }
      }

      private func recurringRow(_ item: MaintenanceItem) -> some View {
          MaintenanceItemRowView(
              item: item,
              members: appState.members,
              onEdit: { editingItem = item },
              onComplete: {
                  handleComplete(item)
              },
              onSchedule: (item.requiresScheduling == true && item.scheduledDate == nil) ? { schedulingItem = item } : nil,
              onDelete: { deletingItem = item; showDeleteConfirmation = true }
          )
      }

      @ViewBuilder
      private func lifecycleSection(vm: MaintenanceViewModel) -> some View {
          if vm.lifecycleItems.isEmpty {
              ContentUnavailableView("No Lifecycle Items", systemImage: "clock.arrow.circlepath", description: Text("Tap + to track an appliance or system"))
          } else {
              ForEach(vm.lifecycleItems) { item in
                  MaintenanceItemRowView(
                      item: item,
                      members: appState.members,
                      onEdit: { editingItem = item },
                      onComplete: nil,
                      onSchedule: nil,
                      onDelete: { deletingItem = item; showDeleteConfirmation = true }
                  )
              }
          }
      }

      // MARK: - Complete logic

      private func handleComplete(_ item: MaintenanceItem) {
          // If requires scheduling with contractor, or is a repair → show completion sheet
          if item.itemType == .repair {
              completingItem = item
          } else if item.itemType == .recurring {
              if item.requiresScheduling == true && item.contractor != nil {
                  completingItem = item
              } else {
                  // Instant complete — no sheet
                  Task {
                      await viewModel?.completeItem(item, actualCost: nil)
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Update MainTabView to use MaintenanceListView**

  Replace the entire contents of `HouseMate/HouseMate/Views/Main/MainTabView.swift`:

  ```swift
  // HouseMate/Views/Main/MainTabView.swift
  import SwiftUI

  struct MainTabView: View {
      var body: some View {
          TabView {
              Text("Home")
                  .tabItem { Label("Home", systemImage: "house") }
              Text("Tasks")
                  .tabItem { Label("Tasks", systemImage: "checklist") }
              Text("Bins")
                  .tabItem { Label("Bins", systemImage: "trash") }
              MaintenanceListView()
                  .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver") }
          }
      }
  }
  ```

- [ ] **Step 3: Build to verify**

  ```bash
  xcodebuild build -scheme HouseMate -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
  ```

  This may fail if `MaintenanceFormView`, `MaintenanceCompletionSheet`, or `MaintenanceScheduleSheet` don't exist yet. If so, add temporary stubs:

  ```swift
  // Temporary stub — delete after Task 8 and Task 9
  // Add to MaintenanceListView.swift or create separate files

  struct MaintenanceFormView: View {
      let householdId: UUID
      let memberId: UUID
      let editingItem: MaintenanceItem?
      let members: [Member]
      let onSave: (MaintenanceItem) -> Void
      var body: some View { Text("Form placeholder") }
  }

  struct MaintenanceCompletionSheet: View {
      let item: MaintenanceItem
      let onComplete: (Decimal?) -> Void
      var body: some View { Text("Completion placeholder") }
  }

  struct MaintenanceScheduleSheet: View {
      let item: MaintenanceItem
      let householdId: UUID
      let onSchedule: (Date, String?, Decimal?) -> Void
      var body: some View { Text("Schedule placeholder") }
  }
  ```

  Remove the stubs once the real views are created in Tasks 8 and 9.

- [ ] **Step 4: Commit**

  ```bash
  git add HouseMate/HouseMate/Views/Maintenance/MaintenanceListView.swift HouseMate/HouseMate/Views/Main/MainTabView.swift
  git commit -m "feat(maintenance): add MaintenanceListView with type tabs, category filters, and grouping"
  ```

---

### Task 8: MaintenanceFormView

**Files:**
- Create: `HouseMate/HouseMate/Views/Maintenance/MaintenanceFormView.swift`

- [ ] **Step 1: Create MaintenanceFormView.swift**

  ```swift
  // HouseMate/Views/Maintenance/MaintenanceFormView.swift
  import SwiftUI

  struct MaintenanceFormView: View {
      @Environment(\.dismiss) private var dismiss
      @State private var viewModel: MaintenanceFormViewModel

      let members: [Member]
      let onSave: (MaintenanceItem) -> Void

      init(householdId: UUID, memberId: UUID, editingItem: MaintenanceItem?, members: [Member] = [], onSave: @escaping (MaintenanceItem) -> Void) {
          _viewModel = State(initialValue: MaintenanceFormViewModel(
              householdId: householdId,
              memberId: memberId,
              editingItem: editingItem
          ))
          self.members = members
          self.onSave = onSave
      }

      var body: some View {
          NavigationStack {
              Form {
                  // Type selector (only in create mode)
                  if !viewModel.isEditing {
                      typeSelector
                  }

                  // Category picker
                  Section("Category") {
                      Picker("Category", selection: $viewModel.category) {
                          ForEach(MaintenanceCategory.allCases) { cat in
                              Label(cat.displayName, systemImage: cat.iconName)
                                  .tag(cat)
                          }
                      }
                      .pickerStyle(.menu)
                      .onChange(of: viewModel.category) {
                          Task { await viewModel.loadContractorSuggestions() }
                      }
                  }

                  // Assign To (repair and recurring only — lifecycle does NOT have assignee)
                  if viewModel.itemType != .lifecycle {
                      Section("Assign To") {
                          Picker("Assign to", selection: $viewModel.assignedTo) {
                              Text("Unassigned").tag(Optional<UUID>.none)
                              ForEach(members) { member in
                                  Text(member.displayName).tag(Optional(member.id))
                              }
                          }
                      }
                  }

                  // Title with suggestions
                  Section("Title") {
                      TextField("What needs doing?", text: $viewModel.name)
                          .textInputAutocapitalization(.words)

                      if !viewModel.name.isEmpty == false {
                          ScrollView(.horizontal, showsIndicators: false) {
                              HStack(spacing: 8) {
                                  ForEach(viewModel.titleSuggestions, id: \.self) { suggestion in
                                      Button(suggestion) {
                                          viewModel.name = suggestion
                                      }
                                      .font(.caption)
                                      .buttonStyle(.bordered)
                                      .controlSize(.small)
                                  }
                              }
                          }
                      }
                  }

                  // Type-specific fields
                  switch viewModel.itemType {
                  case .repair:
                      repairFields
                  case .recurring:
                      recurringFields
                  case .lifecycle:
                      lifecycleFields
                  }

                  // Notes (shared by all types)
                  Section("Notes") {
                      TextField("Optional notes", text: $viewModel.notes, axis: .vertical)
                          .lineLimit(3...6)
                  }
              }
              .navigationTitle(viewModel.isEditing ? "Edit Item" : "New Item")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { dismiss() }
                  }
                  ToolbarItem(placement: .confirmationAction) {
                      Button("Save") {
                          Task {
                              if let item = await viewModel.save() {
                                  onSave(item)
                                  dismiss()
                              }
                          }
                      }
                      .disabled(!viewModel.canSave || viewModel.isSaving)
                  }
              }
              .task {
                  await viewModel.loadContractorSuggestions()
              }
              .alert("Save Failed", isPresented: .constant(viewModel.saveError != nil)) {
                  Button("OK") { viewModel.saveError = nil }
              } message: {
                  Text(viewModel.saveError?.localizedDescription ?? "Unknown error")
              }
          }
      }

      // MARK: - Type Selector

      private var typeSelector: some View {
          Section("Type") {
              HStack(spacing: 12) {
                  typeCard(type: .repair, icon: "wrench.fill", color: .orange)
                  typeCard(type: .recurring, icon: "repeat", color: .purple)
                  typeCard(type: .lifecycle, icon: "clock.arrow.circlepath", color: .blue)
              }
              .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          }
      }

      private func typeCard(type: MaintenanceItemType, icon: String, color: Color) -> some View {
          Button {
              viewModel.itemType = type
          } label: {
              VStack(spacing: 6) {
                  Image(systemName: icon)
                      .font(.title2)
                  Text(type.displayName)
                      .font(.caption.weight(.medium))
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(viewModel.itemType == type ? color.opacity(0.15) : Color.gray.opacity(0.08))
              .foregroundStyle(viewModel.itemType == type ? color : .secondary)
              .clipShape(RoundedRectangle(cornerRadius: 10))
              .overlay(
                  RoundedRectangle(cornerRadius: 10)
                      .stroke(viewModel.itemType == type ? color : Color.clear, lineWidth: 2)
              )
          }
          .buttonStyle(.plain)
      }

      // MARK: - Repair Fields

      private var repairFields: some View {
          Section("Repair Details") {
              TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                  .lineLimit(2...4)

              contractorField

              HStack {
                  Text("Estimated Cost")
                  Spacer()
                  TextField("$0.00", text: $viewModel.estimatedCostString)
                      .keyboardType(.decimalPad)
                      .multilineTextAlignment(.trailing)
                      .frame(width: 100)
              }
          }
      }

      // MARK: - Recurring Fields

      private var recurringFields: some View {
          Section("Schedule") {
              Picker("Frequency", selection: $viewModel.frequency) {
                  ForEach(MaintenanceFrequency.allCases) { freq in
                      Text(freq.displayName).tag(freq)
                  }
              }

              DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)

              Toggle("Requires Professional", isOn: $viewModel.requiresScheduling)

              if viewModel.requiresScheduling {
                  contractorField
              }
          }
      }

      // MARK: - Lifecycle Fields

      private var lifecycleFields: some View {
          Section("Appliance Details") {
              DatePicker("Installed Date", selection: $viewModel.installedDate, displayedComponents: .date)

              Stepper("Expected Life: \(viewModel.expectedLifeYears) years", value: $viewModel.expectedLifeYears, in: 1...50)
                  .onChange(of: viewModel.name) {
                      // Apply smart default when name changes and user hasn't manually set a value
                      if !viewModel.isEditing {
                          viewModel.expectedLifeYears = viewModel.smartExpectedLifeYears
                      }
                  }

              TextField("Brand (optional)", text: $viewModel.brand)
              TextField("Model (optional)", text: $viewModel.model)
          }
      }

      // MARK: - Contractor field

      private var contractorField: some View {
          VStack(alignment: .leading, spacing: 6) {
              TextField("Contractor (optional)", text: $viewModel.contractor)

              if !viewModel.contractorSuggestions.isEmpty {
                  ScrollView(.horizontal, showsIndicators: false) {
                      HStack(spacing: 8) {
                          ForEach(viewModel.contractorSuggestions, id: \.self) { name in
                              Button(name) {
                                  viewModel.contractor = name
                              }
                              .font(.caption)
                              .buttonStyle(.bordered)
                              .controlSize(.small)
                          }
                      }
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  ```bash
  xcodebuild build -scheme HouseMate -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add HouseMate/HouseMate/Views/Maintenance/MaintenanceFormView.swift
  git commit -m "feat(maintenance): add MaintenanceFormView with adaptive fields, suggestions, and smart defaults"
  ```

---

### Task 9: MaintenanceCompletionSheet + MaintenanceScheduleSheet

**Files:**
- Create: `HouseMate/HouseMate/Views/Maintenance/MaintenanceCompletionSheet.swift`
- Create: `HouseMate/HouseMate/Views/Maintenance/MaintenanceScheduleSheet.swift`

- [ ] **Step 1: Create MaintenanceCompletionSheet.swift**

  ```swift
  // HouseMate/Views/Maintenance/MaintenanceCompletionSheet.swift
  import SwiftUI

  struct MaintenanceCompletionSheet: View {
      @Environment(\.dismiss) private var dismiss

      let item: MaintenanceItem
      let onComplete: (Decimal?) -> Void

      @State private var costString: String = ""
      @State private var showCostField: Bool = false

      init(item: MaintenanceItem, onComplete: @escaping (Decimal?) -> Void) {
          self.item = item
          self.onComplete = onComplete
          // Pre-fill from estimated cost
          if let estimated = item.estimatedCost {
              _costString = State(initialValue: "\(estimated)")
              _showCostField = State(initialValue: true)
          }
      }

      var body: some View {
          NavigationStack {
              VStack(spacing: 24) {
                  Spacer()

                  Image(systemName: "checkmark.circle.fill")
                      .font(.system(size: 60))
                      .foregroundStyle(.green)

                  Text("Complete \"\(item.name)\"?")
                      .font(.title3.weight(.semibold))
                      .multilineTextAlignment(.center)

                  if showCostField {
                      VStack(spacing: 8) {
                          Text("Actual Cost")
                              .font(.subheadline)
                              .foregroundStyle(.secondary)
                          HStack {
                              Text("$")
                                  .foregroundStyle(.secondary)
                              TextField("0.00", text: $costString)
                                  .keyboardType(.decimalPad)
                                  .font(.title2)
                                  .multilineTextAlignment(.center)
                                  .frame(width: 150)
                          }
                          .padding()
                          .background(Color.gray.opacity(0.1))
                          .clipShape(RoundedRectangle(cornerRadius: 10))
                      }
                  }

                  Button {
                      let cost = Decimal(string: costString)
                      onComplete(cost)
                      dismiss()
                  } label: {
                      Text("Mark Complete")
                          .font(.headline)
                          .frame(maxWidth: .infinity)
                          .padding()
                          .background(.green)
                          .foregroundStyle(.white)
                          .clipShape(RoundedRectangle(cornerRadius: 12))
                  }
                  .padding(.horizontal)

                  if !showCostField && item.estimatedCost == nil {
                      Button("+ Log cost") {
                          showCostField = true
                      }
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
                  }

                  Spacer()
              }
              .padding()
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { dismiss() }
                  }
              }
          }
          .presentationDetents([.medium])
      }
  }
  ```

- [ ] **Step 2: Create MaintenanceScheduleSheet.swift**

  ```swift
  // HouseMate/Views/Maintenance/MaintenanceScheduleSheet.swift
  import SwiftUI

  struct MaintenanceScheduleSheet: View {
      @Environment(\.dismiss) private var dismiss

      let item: MaintenanceItem
      let householdId: UUID
      let onSchedule: (Date, String?, Decimal?) -> Void

      @State private var date: Date = Date()
      @State private var contractor: String = ""
      @State private var estimatedCostString: String = ""
      @State private var contractorSuggestions: [String] = []

      private let service = MaintenanceService()

      init(item: MaintenanceItem, householdId: UUID, onSchedule: @escaping (Date, String?, Decimal?) -> Void) {
          self.item = item
          self.householdId = householdId
          self.onSchedule = onSchedule
          // Pre-fill from item
          if let c = item.contractor {
              _contractor = State(initialValue: c)
          }
          if let cost = item.estimatedCost {
              _estimatedCostString = State(initialValue: "\(cost)")
          }
      }

      var body: some View {
          NavigationStack {
              Form {
                  Section("When") {
                      DatePicker("Date", selection: $date, displayedComponents: .date)
                  }

                  Section("Contractor") {
                      TextField("Contractor name", text: $contractor)

                      if !contractorSuggestions.isEmpty {
                          ScrollView(.horizontal, showsIndicators: false) {
                              HStack(spacing: 8) {
                                  ForEach(contractorSuggestions, id: \.self) { name in
                                      Button(name) {
                                          contractor = name
                                      }
                                      .font(.caption)
                                      .buttonStyle(.bordered)
                                      .controlSize(.small)
                                  }
                              }
                          }
                      }
                  }

                  Section("Estimated Cost") {
                      HStack {
                          Text("$")
                              .foregroundStyle(.secondary)
                          TextField("0.00", text: $estimatedCostString)
                              .keyboardType(.decimalPad)
                      }
                  }
              }
              .navigationTitle("Schedule")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { dismiss() }
                  }
                  ToolbarItem(placement: .confirmationAction) {
                      Button("Schedule") {
                          let cost = Decimal(string: estimatedCostString)
                          onSchedule(date, contractor.isEmpty ? nil : contractor, cost)
                          dismiss()
                      }
                  }
              }
              .task {
                  do {
                      contractorSuggestions = try await service.fetchContractorSuggestions(
                          householdId: householdId,
                          category: item.category
                      )
                  } catch {
                      contractorSuggestions = []
                  }
              }
          }
          .presentationDetents([.medium])
      }
  }
  ```

- [ ] **Step 3: Remove any temporary stubs from Task 7**

  If you added temporary stubs for `MaintenanceFormView`, `MaintenanceCompletionSheet`, or `MaintenanceScheduleSheet` in Task 7, delete them now.

- [ ] **Step 4: Build to verify everything compiles**

  ```bash
  xcodebuild build -scheme HouseMate -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
  ```

- [ ] **Step 5: Run all tests**

  ```bash
  xcodebuild test \
    -scheme HouseMate \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    2>&1 | tail -30
  ```

  All existing tests should still pass.

- [ ] **Step 6: Commit**

  ```bash
  git add HouseMate/HouseMate/Views/Maintenance/MaintenanceCompletionSheet.swift HouseMate/HouseMate/Views/Maintenance/MaintenanceScheduleSheet.swift
  git commit -m "feat(maintenance): add MaintenanceCompletionSheet and MaintenanceScheduleSheet"
  ```

---

## Chunk 5: Polish

### Task 10: Verify All Flows in Simulator

- [ ] **Step 1: Build and run in simulator**

  ```bash
  xcodebuild build -scheme HouseMate -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
  ```

- [ ] **Step 2: Run all tests**

  ```bash
  xcodebuild test \
    -scheme HouseMate \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    2>&1 | tail -30
  ```

- [ ] **Step 3: Manual verification checklist**

  Boot the simulator and verify each flow:

  - [ ] Maintenance tab loads and shows "All good" or correct header subtitle
  - [ ] Category filter bar scrolls horizontally, filtering works
  - [ ] Type tabs switch between Repairs / Recurring / Lifecycle with correct counts
  - [ ] **Repair flow:**
    - [ ] Tap + → type selector defaults to Repair → enter title → save → appears in list
    - [ ] "Schedule It" button opens schedule sheet → fill date/contractor → status changes to "Scheduled"
    - [ ] Swipe right → completion sheet with cost pre-fill → "Mark Complete" → status changes to "Completed"
    - [ ] Pencil icon opens edit form → save updates the row
    - [ ] Swipe left → delete confirmation → item removed
  - [ ] **Recurring flow:**
    - [ ] Tap + → select Recurring → enter title, frequency, start date → save
    - [ ] Items grouped into Overdue / Upcoming / Later This Year
    - [ ] "Later This Year" section starts collapsed, tap to expand
    - [ ] Swipe right on regular recurring → instant complete (no sheet)
    - [ ] Swipe right on requires_scheduling+contractor recurring → completion sheet appears
    - [ ] "Schedule It" button appears when requires_scheduling=true and not scheduled
  - [ ] **Lifecycle flow:**
    - [ ] Tap + → select Lifecycle → name triggers smart expected life default
    - [ ] Saved item shows age progress bar, "X yrs old · ~Y yr left", status badge
    - [ ] No swipe-to-complete (lifecycle is read-only for completion)
    - [ ] Edit and delete work correctly
  - [ ] **Show completed toggle:**
    - [ ] Toggle "Show Done" chip → completed repairs appear in list
    - [ ] Toggle off → completed repairs hidden again
  - [ ] **Contractor suggestions:**
    - [ ] In form and schedule sheet, contractor field shows last 3 category-matched names as chips
    - [ ] Tapping a chip fills the contractor field

- [ ] **Step 4: Fix any issues found during manual testing**

  Common issues to check:
  - Ensure `MaintenanceItem` conforms to `Hashable` if needed for `.sheet(item:)` — add `extension MaintenanceItem: Hashable { func hash(into hasher: inout Hasher) { hasher.combine(id) } }` if the compiler requires it.
  - Ensure `MaintenanceItem` conforms to `Equatable` if needed — `Codable` structs with all `Equatable` fields get it automatically, but if `Decimal` causes issues, add explicit conformance.
  - Check that the Supabase decoder handles all the new nullable columns correctly (nil for columns that don't exist in old rows).

- [ ] **Step 5: Final commit**

  ```bash
  git add -A
  git commit -m "feat(maintenance): complete Maintenance tab with all item types, forms, and completion flows"
  ```
