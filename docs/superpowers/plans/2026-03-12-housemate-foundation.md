# HouseMate Foundation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the HouseMate iOS Xcode project, implement all data models with business logic, create the CloudKit service layer, and wire up the navigation skeleton — the complete foundation before building any feature UIs.

**Architecture:** Pure Swift models carry all business logic (rotation calculation, due dates, recurring task advancement) and map to `CKRecord` via failable initializers and `toCKRecord()` methods. A thin CloudKit service layer (one `@MainActor` class per domain) owns all async database operations. SwiftUI views use `@Observable` ViewModels added in feature plans. No third-party dependencies.

**Tech Stack:** Swift 5.9+, SwiftUI, CloudKit (CKContainer / CKDatabase / CKRecord), XCTest, iOS 17.0+

**Spec:** `docs/superpowers/specs/2026-03-12-housemate-design.md`

---

## Chunk 1: Project Scaffold

### Task 1: Create Xcode Project

**Files:**
- Create: `HouseMate.xcodeproj` (via Xcode GUI)
- Create: `HouseMate/HouseMateApp.swift`
- Create: `HouseMate/ContentView.swift`

- [ ] **Step 1: Create project in Xcode**

  File > New > Project > iOS > App:
  - Product Name: `HouseMate`
  - Bundle Identifier: `com.housemate.app` *(update to your team prefix)*
  - Interface: SwiftUI
  - Language: Swift
  - Uncheck: Use Core Data
  - Check: Include Tests
  - Minimum Deployment: iOS 17.0
  - Save to: `/Users/chilee-old/Documents/Development/augment-projects/HouseMate/`

- [ ] **Step 2: Add iCloud + CloudKit capability**

  In Xcode: select the `HouseMate` target > Signing & Capabilities > + Capability > iCloud:
  - Check: CloudKit
  - Click "+" under Containers: `iCloud.com.housemate.app`
  - Check: Push Notifications (required for CloudKit subscriptions)

- [ ] **Step 3: Add Background Modes capability**

  Signing & Capabilities > + Capability > Background Modes:
  - Check: Remote notifications

- [ ] **Step 4: Initialize git**

  ```bash
  cd /Users/chilee-old/Documents/Development/augment-projects/HouseMate
  git init
  cat > .gitignore << 'EOF'
  # Xcode
  *.xcuserstate
  xcuserdata/
  DerivedData/
  .build/
  *.xcworkspace/xcuserdata/
  # macOS
  .DS_Store
  EOF
  git add .
  git commit -m "feat: initial Xcode project scaffold"
  ```

---

### Task 2: Folder Structure

**Files:**
- Create: `HouseMate/Models/` group
- Create: `HouseMate/Services/` group
- Create: `HouseMate/Views/Home/` group
- Create: `HouseMate/Views/Tasks/` group
- Create: `HouseMate/Views/Bins/` group
- Create: `HouseMate/Views/Maintenance/` group
- Create: `HouseMate/Views/Settings/` group
- Create: `HouseMate/Views/Onboarding/` group
- Create: `HouseMate/Views/Shared/` group
- Create: `HouseMate/Resources/` group

- [ ] **Step 1: Create filesystem folders**

  ```bash
  cd /Users/chilee-old/Documents/Development/augment-projects/HouseMate/HouseMate
  mkdir -p Models Services Views/Home Views/Tasks Views/Bins Views/Maintenance Views/Settings Views/Onboarding Views/Shared Resources
  ```

- [ ] **Step 2: Add folders as groups in Xcode**

  In Xcode: right-click the `HouseMate` group > New Group > name each to match the folders above. Files created in later tasks must be added inside their matching group.

---

### Task 3: Navigation Skeleton

**Files:**
- Modify: `HouseMate/HouseMateApp.swift`
- Modify: `HouseMate/ContentView.swift`
- Create: `HouseMate/Views/Home/HomeView.swift`
- Create: `HouseMate/Views/Tasks/TasksView.swift`
- Create: `HouseMate/Views/Bins/BinsView.swift`
- Create: `HouseMate/Views/Maintenance/MaintenanceView.swift`
- Create: `HouseMate/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Replace HouseMateApp.swift**

  ```swift
  import SwiftUI

  @main
  struct HouseMateApp: App {
      var body: some Scene {
          WindowGroup {
              ContentView()
          }
      }
  }
  ```

- [ ] **Step 2: Replace ContentView.swift with tab navigation**

  ```swift
  import SwiftUI

  struct ContentView: View {
      var body: some View {
          TabView {
              HomeView()
                  .tabItem { Label("Home", systemImage: "house.fill") }
              TasksView()
                  .tabItem { Label("Tasks", systemImage: "checklist") }
              BinsView()
                  .tabItem { Label("Bins", systemImage: "trash.fill") }
              MaintenanceView()
                  .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver.fill") }
          }
      }
  }
  ```

- [ ] **Step 3: Create HomeView.swift**

  ```swift
  import SwiftUI

  struct HomeView: View {
      var body: some View {
          NavigationStack {
              Text("Home")
                  .navigationTitle("Home")
          }
      }
  }
  ```

- [ ] **Step 4: Create TasksView.swift**

  ```swift
  import SwiftUI

  struct TasksView: View {
      var body: some View {
          NavigationStack {
              Text("Tasks")
                  .navigationTitle("Tasks")
          }
      }
  }
  ```

- [ ] **Step 5: Create BinsView.swift**

  ```swift
  import SwiftUI

  struct BinsView: View {
      var body: some View {
          NavigationStack {
              Text("Bins")
                  .navigationTitle("Bins")
          }
      }
  }
  ```

- [ ] **Step 6: Create MaintenanceView.swift**

  ```swift
  import SwiftUI

  struct MaintenanceView: View {
      var body: some View {
          NavigationStack {
              Text("Maintenance")
                  .navigationTitle("Maintenance")
          }
      }
  }
  ```

- [ ] **Step 7: Create SettingsView.swift**

  ```swift
  import SwiftUI

  struct SettingsView: View {
      var body: some View {
          NavigationStack {
              Text("Settings")
                  .navigationTitle("Settings")
          }
      }
  }
  ```

- [ ] **Step 8: Build and run on simulator**

  In Xcode: ⌘R. Verify 4 tabs appear with correct icons and labels. No crashes.

- [ ] **Step 9: Commit**

  ```bash
  git add HouseMate/
  git commit -m "feat: add tab navigation skeleton with placeholder views"
  ```

---

## Chunk 2: Shared Enums and Pure Business Logic

### Task 4: Shared Enums

**Files:**
- Create: `HouseMate/Models/HouseMateEnums.swift`

- [ ] **Step 1: Create HouseMateEnums.swift**

  ```swift
  import Foundation

  enum TaskCategory: String, CaseIterable, Codable {
      case kitchen = "Kitchen"
      case bathroom = "Bathroom"
      case outdoor = "Outdoor"
      case errands = "Errands"
      case other = "Other"
  }

  enum TaskPriority: String, CaseIterable, Codable {
      case high = "High"
      case medium = "Medium"
      case low = "Low"
  }

  enum RecurringInterval: String, CaseIterable, Codable {
      case daily = "Daily"
      case weekly = "Weekly"
      case monthly = "Monthly"

      func advance(from date: Date, calendar: Calendar = .current) -> Date {
          switch self {
          case .daily:   return calendar.date(byAdding: .day, value: 1, to: date) ?? date
          case .weekly:  return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
          case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
          }
      }
  }

  enum SeasonalCategory: String, CaseIterable, Codable {
      case spring = "Spring"
      case summer = "Summer"
      case fall = "Fall"
      case winter = "Winter"
      case yearRound = "Year-Round"
  }

  enum BinRotation: String, Codable, Equatable {
      case a = "A"
      case b = "B"

      var other: BinRotation { self == .a ? .b : .a }
  }
  ```

- [ ] **Step 2: Build to verify no compile errors**

  ⌘B (Product > Build).

- [ ] **Step 3: Commit**

  ```bash
  git add HouseMate/Models/HouseMateEnums.swift
  git commit -m "feat: add shared enums for task, maintenance, and bin schedule"
  ```

---

### Task 5: BinSchedule Model + Rotation Algorithm (TDD)

**Files:**
- Create: `HouseMate/Models/BinSchedule.swift`
- Create: `HouseMateTests/Models/BinScheduleTests.swift`

- [ ] **Step 1: Create test file — BinScheduleTests.swift**

  In Xcode, create `HouseMateTests/Models/` group, then add:

  ```swift
  import XCTest
  @testable import HouseMate

  final class BinScheduleTests: XCTestCase {

      private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
          var c = DateComponents()
          c.year = year; c.month = month; c.day = day
          return Calendar.current.date(from: c)!
      }

      private func makeSchedule(startingDate: Date, startingRotation: BinRotation = .a) -> BinSchedule {
          BinSchedule(
              pickupDayOfWeek: 5,          // Thursday
              rotationA: "Compost + Recycling",
              rotationB: "Compost + Garbage",
              startingRotation: startingRotation,
              startingDate: startingDate,
              notifyDayBefore: false,
              notifyMorningOf: false
          )
      }

      func test_rotation_sameWeekAsStarting_returnsStartingRotation() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5))
          XCTAssertEqual(schedule.rotation(for: date(2026, 3, 5)), .a)
      }

      func test_rotation_oneWeekLater_returnsOtherRotation() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5))
          XCTAssertEqual(schedule.rotation(for: date(2026, 3, 12)), .b)
      }

      func test_rotation_twoWeeksLater_returnsStartingRotation() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5))
          XCTAssertEqual(schedule.rotation(for: date(2026, 3, 19)), .a)
      }

      func test_rotation_startingRotationB_sameWeek_returnsB() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5), startingRotation: .b)
          XCTAssertEqual(schedule.rotation(for: date(2026, 3, 5)), .b)
      }

      func test_nextPickupDate_fromNonPickupDay_returnsNextPickupDay() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5))
          // From Monday March 9, next Thursday is March 12
          XCTAssertEqual(schedule.nextPickupDate(from: date(2026, 3, 9)), date(2026, 3, 12))
      }

      func test_nextPickupDate_fromPickupDay_returnsFollowingWeek() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5))
          // From Thursday March 12 (pickup day itself), next is March 19
          XCTAssertEqual(schedule.nextPickupDate(from: date(2026, 3, 12)), date(2026, 3, 19))
      }

      func test_upcomingPickups_returnsRequestedCount() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5))
          let pickups = schedule.upcomingPickups(from: date(2026, 3, 9), count: 8)
          XCTAssertEqual(pickups.count, 8)
      }

      func test_upcomingPickups_firstEntryIsNextThursdayWithCorrectRotation() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5))
          // From Monday March 9 → first pickup is Thursday March 12 (1 week after March 5 → rotation B)
          let pickups = schedule.upcomingPickups(from: date(2026, 3, 9), count: 8)
          XCTAssertEqual(pickups[0].date, date(2026, 3, 12))
          XCTAssertEqual(pickups[0].rotation, .b)
      }

      func test_upcomingPickups_alternatesRotation() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5))
          let pickups = schedule.upcomingPickups(from: date(2026, 3, 9), count: 4)
          XCTAssertEqual(pickups[0].rotation, .b)
          XCTAssertEqual(pickups[1].rotation, .a)
          XCTAssertEqual(pickups[2].rotation, .b)
          XCTAssertEqual(pickups[3].rotation, .a)
      }

      func test_daysUntilNextPickup_fromMondayBeforeThursday_returnsThree() {
          let schedule = makeSchedule(startingDate: date(2026, 3, 5))
          // Monday March 9 → Thursday March 12 = 3 days
          XCTAssertEqual(schedule.daysUntilNextPickup(from: date(2026, 3, 9)), 3)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect compile failure**

  ⌘U. Expected: compile error — `BinSchedule` not defined yet.

- [ ] **Step 3: Create BinSchedule.swift**

  ```swift
  import Foundation
  import CloudKit

  struct PickupEntry: Equatable {
      let date: Date
      let rotation: BinRotation
  }

  struct BinSchedule {
      var recordID: CKRecord.ID?
      var pickupDayOfWeek: Int       // 1=Sun…7=Sat (Calendar.weekday)
      var rotationA: String
      var rotationB: String
      var startingRotation: BinRotation
      var startingDate: Date
      var notifyDayBefore: Bool
      var notifyMorningOf: Bool

      // MARK: - Business Logic

      /// Returns the rotation label for the given pickup date.
      /// weeksDiff even → startingRotation; odd → other.
      func rotation(for pickupDate: Date) -> BinRotation {
          let cal = Calendar.current
          let startDay = cal.startOfDay(for: startingDate)
          let targetDay = cal.startOfDay(for: pickupDate)
          let days = cal.dateComponents([.day], from: startDay, to: targetDay).day ?? 0
          let weeksDiff = days / 7
          return weeksDiff.isMultiple(of: 2) ? startingRotation : startingRotation.other
      }

      /// Returns the display label string for a rotation value.
      func label(for rotation: BinRotation) -> String {
          rotation == .a ? rotationA : rotationB
      }

      /// Next pickup date strictly after `referenceDate`.
      /// If `referenceDate` is the pickup day, returns the following week.
      func nextPickupDate(from referenceDate: Date) -> Date {
          let cal = Calendar.current
          let today = cal.startOfDay(for: referenceDate)
          let todayWeekday = cal.component(.weekday, from: today)
          var daysUntil = pickupDayOfWeek - todayWeekday
          if daysUntil <= 0 { daysUntil += 7 }
          return cal.date(byAdding: .day, value: daysUntil, to: today)!
      }

      /// Returns `count` upcoming pickup entries starting from the next pickup after `referenceDate`.
      func upcomingPickups(from referenceDate: Date, count: Int = 8) -> [PickupEntry] {
          var results: [PickupEntry] = []
          var current = nextPickupDate(from: referenceDate)
          for _ in 0..<count {
              results.append(PickupEntry(date: current, rotation: rotation(for: current)))
              current = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: current)!
          }
          return results
      }

      /// Number of days from `referenceDate` until the next pickup.
      func daysUntilNextPickup(from referenceDate: Date = Date()) -> Int {
          let next = nextPickupDate(from: referenceDate)
          return Calendar.current.dateComponents(
              [.day],
              from: Calendar.current.startOfDay(for: referenceDate),
              to: next
          ).day ?? 0
      }
  }
  ```

- [ ] **Step 4: Run tests — expect all PASS**

  ⌘U. All 10 tests green.

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/Models/BinSchedule.swift HouseMateTests/Models/BinScheduleTests.swift
  git commit -m "feat: add BinSchedule model with rotation algorithm (tested)"
  ```

---

### Task 6: MaintenanceItem Model (TDD)

**Files:**
- Create: `HouseMate/Models/MaintenanceItem.swift`
- Create: `HouseMateTests/Models/MaintenanceItemTests.swift`

- [ ] **Step 1: Create MaintenanceItemTests.swift**

  ```swift
  import XCTest
  @testable import HouseMate

  final class MaintenanceItemTests: XCTestCase {

      private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
          var c = DateComponents(); c.year = year; c.month = month; c.day = day
          return Calendar.current.date(from: c)!
      }

      private func daysAgo(_ n: Int) -> Date {
          Calendar.current.date(byAdding: .day, value: -n, to: Date())!
      }

      func test_nextDueDate_calculatedFromLastCompleted() {
          let item = MaintenanceItem(
              name: "Change furnace filter", category: .yearRound,
              intervalDays: 90, lastCompletedDate: date(2026, 1, 1),
              notes: nil, templateID: nil
          )
          XCTAssertEqual(item.nextDueDate, date(2026, 4, 1))
      }

      func test_nextDueDate_nilLastCompleted_returnsNil() {
          let item = MaintenanceItem(
              name: "Flush water heater", category: .yearRound,
              intervalDays: 365, lastCompletedDate: nil,
              notes: nil, templateID: nil
          )
          XCTAssertNil(item.nextDueDate)
      }

      func test_status_green_moreThan14DaysAway() {
          let item = MaintenanceItem(
              name: "Test", category: .yearRound,
              intervalDays: 90, lastCompletedDate: daysAgo(50),
              notes: nil, templateID: nil
          )
          XCTAssertEqual(item.status, .green)
      }

      func test_status_yellow_within14Days() {
          let item = MaintenanceItem(
              name: "Test", category: .yearRound,
              intervalDays: 90, lastCompletedDate: daysAgo(80),
              notes: nil, templateID: nil
          )
          XCTAssertEqual(item.status, .yellow)
      }

      func test_status_yellow_exactlyToday() {
          let item = MaintenanceItem(
              name: "Test", category: .yearRound,
              intervalDays: 90, lastCompletedDate: daysAgo(90),
              notes: nil, templateID: nil
          )
          XCTAssertEqual(item.status, .yellow)
      }

      func test_status_red_overdue() {
          let item = MaintenanceItem(
              name: "Test", category: .yearRound,
              intervalDays: 90, lastCompletedDate: daysAgo(100),
              notes: nil, templateID: nil
          )
          XCTAssertEqual(item.status, .red)
      }

      func test_status_red_neverCompleted() {
          let item = MaintenanceItem(
              name: "Test", category: .yearRound,
              intervalDays: 90, lastCompletedDate: nil,
              notes: nil, templateID: nil
          )
          XCTAssertEqual(item.status, .red)
      }

      func test_isDueSoon_trueForYellowAndRed() {
          let yellow = MaintenanceItem(name: "T", category: .yearRound, intervalDays: 90, lastCompletedDate: daysAgo(80), notes: nil, templateID: nil)
          let red    = MaintenanceItem(name: "T", category: .yearRound, intervalDays: 90, lastCompletedDate: daysAgo(100), notes: nil, templateID: nil)
          let green  = MaintenanceItem(name: "T", category: .yearRound, intervalDays: 90, lastCompletedDate: daysAgo(50), notes: nil, templateID: nil)
          XCTAssertTrue(yellow.isDueSoon)
          XCTAssertTrue(red.isDueSoon)
          XCTAssertFalse(green.isDueSoon)
      }
  }
  ```

- [ ] **Step 2: Run — expect compile failure**

  ⌘U.

- [ ] **Step 3: Create MaintenanceItem.swift**

  ```swift
  import Foundation
  import CloudKit

  enum MaintenanceStatus: Equatable {
      case green, yellow, red
  }

  struct MaintenanceItem {
      var recordID: CKRecord.ID?
      var name: String
      var category: SeasonalCategory
      var intervalDays: Int
      var lastCompletedDate: Date?
      var notes: String?
      var templateID: String?

      var nextDueDate: Date? {
          guard let last = lastCompletedDate else { return nil }
          return Calendar.current.date(byAdding: .day, value: intervalDays, to: last)
      }

      var status: MaintenanceStatus {
          guard let due = nextDueDate else { return .red }
          let today = Calendar.current.startOfDay(for: Date())
          let dueDay = Calendar.current.startOfDay(for: due)
          let daysUntil = Calendar.current.dateComponents([.day], from: today, to: dueDay).day ?? 0
          if daysUntil < 0  { return .red }
          if daysUntil <= 14 { return .yellow }
          return .green
      }

      var isDueSoon: Bool { status == .yellow || status == .red }
  }
  ```

- [ ] **Step 4: Run tests — all PASS**

  ⌘U.

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/Models/MaintenanceItem.swift HouseMateTests/Models/MaintenanceItemTests.swift
  git commit -m "feat: add MaintenanceItem model with due date and status logic (tested)"
  ```

---

### Task 7: HouseMateTask Model + Recurring Date Advancement (TDD)

**Files:**
- Create: `HouseMate/Models/Task.swift`
- Create: `HouseMateTests/Models/TaskTests.swift`

> Named `HouseMateTask` to avoid conflict with Swift's built-in `Task` type.

- [ ] **Step 1: Create TaskTests.swift**

  ```swift
  import XCTest
  @testable import HouseMate

  final class TaskTests: XCTestCase {

      private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
          var c = DateComponents(); c.year = year; c.month = month; c.day = day
          return Calendar.current.date(from: c)!
      }

      func test_advanceRecurring_weekly_advancesByOneWeek() {
          var task = HouseMateTask(
              title: "Take out trash", category: .kitchen, priority: .medium,
              isRecurring: true, recurringInterval: .weekly, dueDate: date(2026, 3, 12)
          )
          task.advanceRecurringDueDate()
          XCTAssertEqual(task.dueDate, date(2026, 3, 19))
      }

      func test_advanceRecurring_monthly_advancesByOneMonth() {
          var task = HouseMateTask(
              title: "Clean fridge", category: .kitchen, priority: .medium,
              isRecurring: true, recurringInterval: .monthly, dueDate: date(2026, 3, 1)
          )
          task.advanceRecurringDueDate()
          XCTAssertEqual(task.dueDate, date(2026, 4, 1))
      }

      func test_advanceRecurring_daily_advancesByOneDay() {
          var task = HouseMateTask(
              title: "Check mail", category: .errands, priority: .low,
              isRecurring: true, recurringInterval: .daily, dueDate: date(2026, 3, 12)
          )
          task.advanceRecurringDueDate()
          XCTAssertEqual(task.dueDate, date(2026, 3, 13))
      }

      func test_advanceRecurring_nilDueDate_setsToTodayPlusInterval() {
          var task = HouseMateTask(
              title: "Vacuum", category: .other, priority: .low,
              isRecurring: true, recurringInterval: .weekly, dueDate: nil
          )
          let today = Calendar.current.startOfDay(for: Date())
          let expected = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: today)!
          task.advanceRecurringDueDate(today: today)
          XCTAssertEqual(task.dueDate, expected)
      }

      func test_advanceRecurring_resetsCompletionState() {
          var task = HouseMateTask(
              title: "Test", category: .other, priority: .low,
              isRecurring: true, recurringInterval: .weekly, dueDate: date(2026, 3, 12)
          )
          task.isCompleted = true
          task.completedAt = Date()
          task.advanceRecurringDueDate()
          XCTAssertFalse(task.isCompleted)
          XCTAssertNil(task.completedAt)
          XCTAssertNil(task.completedBy)
      }

      func test_isOverdue_pastDueDate_returnsTrue() {
          let task = HouseMateTask(
              title: "Test", category: .other, priority: .low,
              isRecurring: false, recurringInterval: nil,
              dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
          )
          XCTAssertTrue(task.isOverdue)
      }

      func test_isOverdue_futureDueDate_returnsFalse() {
          let task = HouseMateTask(
              title: "Test", category: .other, priority: .low,
              isRecurring: false, recurringInterval: nil,
              dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())
          )
          XCTAssertFalse(task.isOverdue)
      }

      func test_isOverdue_noDueDate_returnsFalse() {
          let task = HouseMateTask(
              title: "Test", category: .other, priority: .low,
              isRecurring: false, recurringInterval: nil, dueDate: nil
          )
          XCTAssertFalse(task.isOverdue)
      }

      func test_isOverdue_completedTask_returnsFalse() {
          var task = HouseMateTask(
              title: "Test", category: .other, priority: .low,
              isRecurring: false, recurringInterval: nil,
              dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
          )
          task.isCompleted = true
          XCTAssertFalse(task.isOverdue)
      }

      func test_isDueToday_todayDate_returnsTrue() {
          let task = HouseMateTask(
              title: "Test", category: .other, priority: .low,
              isRecurring: false, recurringInterval: nil,
              dueDate: Calendar.current.startOfDay(for: Date())
          )
          XCTAssertTrue(task.isDueToday)
      }
  }
  ```

- [ ] **Step 2: Run — expect compile failure**

  ⌘U.

- [ ] **Step 3: Create Task.swift**

  ```swift
  import Foundation
  import CloudKit

  struct HouseMateTask {
      var recordID: CKRecord.ID?
      var title: String
      var category: TaskCategory
      var priority: TaskPriority
      var assignedTo: CKRecord.Reference?
      var dueDate: Date?
      var isRecurring: Bool
      var recurringInterval: RecurringInterval?
      var isCompleted: Bool = false
      var completedBy: CKRecord.Reference?
      var completedAt: Date?
      var templateID: String?

      var isOverdue: Bool {
          guard let due = dueDate, !isCompleted else { return false }
          return due < Calendar.current.startOfDay(for: Date())
      }

      var isDueToday: Bool {
          guard let due = dueDate else { return false }
          return Calendar.current.isDateInToday(due)
      }

      /// Advances dueDate by recurringInterval and resets completion state.
      /// If dueDate is nil, sets next due to today + interval.
      mutating func advanceRecurringDueDate(today: Date = Date()) {
          guard isRecurring, let interval = recurringInterval else { return }
          let base = dueDate ?? Calendar.current.startOfDay(for: today)
          dueDate = interval.advance(from: base)
          isCompleted = false
          completedBy = nil
          completedAt = nil
      }
  }

  struct TaskCompletionLog {
      var recordID: CKRecord.ID?
      var taskID: CKRecord.Reference
      var completedBy: CKRecord.Reference
      var completedAt: Date
  }
  ```

- [ ] **Step 4: Run tests — all PASS**

  ⌘U.

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/Models/Task.swift HouseMateTests/Models/TaskTests.swift
  git commit -m "feat: add HouseMateTask model with recurring date advancement (tested)"
  ```

---

### Task 8: Remaining Models

**Files:**
- Create: `HouseMate/Models/Household.swift`
- Create: `HouseMate/Models/Member.swift`
- Create: `HouseMate/Models/TaskTemplate.swift`
- Create: `HouseMate/Models/MaintenanceLog.swift`
- Create: `HouseMate/Models/MaintenanceTemplate.swift`

- [ ] **Step 1: Create Household.swift**

  ```swift
  import Foundation
  import CloudKit

  struct Household {
      var recordID: CKRecord.ID?
      var name: String
      var createdBy: CKRecord.Reference?
      var members: [CKRecord.Reference]
  }
  ```

- [ ] **Step 2: Create Member.swift**

  ```swift
  import Foundation
  import CloudKit

  struct Member {
      var recordID: CKRecord.ID?
      var displayName: String
      var appleUserID: String
  }
  ```

- [ ] **Step 3: Create TaskTemplate.swift**

  ```swift
  import Foundation
  import CloudKit

  struct TaskTemplate {
      var recordID: CKRecord.ID?         // nil for built-in (local only)
      var title: String
      var category: TaskCategory
      var recurringInterval: RecurringInterval?
      var isBuiltIn: Bool
  }
  ```

- [ ] **Step 4: Create MaintenanceLog.swift**

  ```swift
  import Foundation
  import CloudKit

  struct MaintenanceLog {
      var recordID: CKRecord.ID?
      var maintenanceItemID: CKRecord.Reference
      var completedDate: Date
      var notes: String?
      var cost: Double?
  }
  ```

- [ ] **Step 5: Create MaintenanceTemplate.swift**

  ```swift
  import Foundation
  import CloudKit

  struct MaintenanceTemplate {
      var recordID: CKRecord.ID?         // nil for built-in (local only)
      var name: String
      var category: SeasonalCategory
      var intervalDays: Int
      var isBuiltIn: Bool
  }
  ```

- [ ] **Step 6: Build — no compile errors**

  ⌘B.

- [ ] **Step 7: Commit**

  ```bash
  git add HouseMate/Models/
  git commit -m "feat: add Household, Member, TaskTemplate, MaintenanceLog, MaintenanceTemplate models"
  ```

---

## Chunk 3: CloudKit Service Layer

### Task 9: CKRecord Mapping Extensions (TDD)

**Files:**
- Create: `HouseMate/Services/CKRecord+HouseMate.swift`
- Create: `HouseMateTests/Services/CKRecordMappingTests.swift`

- [ ] **Step 1: Create CKRecordMappingTests.swift**

  In Xcode, create `HouseMateTests/Services/` group, then add:

  ```swift
  import XCTest
  import CloudKit
  @testable import HouseMate

  final class CKRecordMappingTests: XCTestCase {

      private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
          var c = DateComponents(); c.year = year; c.month = month; c.day = day
          return Calendar.current.date(from: c)!
      }

      // MARK: - BinSchedule

      func test_binSchedule_roundtrip() {
          let original = BinSchedule(
              pickupDayOfWeek: 5,
              rotationA: "Compost + Recycling",
              rotationB: "Compost + Garbage",
              startingRotation: .a,
              startingDate: date(2026, 3, 5),
              notifyDayBefore: true,
              notifyMorningOf: false
          )
          let decoded = BinSchedule(from: original.toCKRecord())
          XCTAssertEqual(decoded?.pickupDayOfWeek, original.pickupDayOfWeek)
          XCTAssertEqual(decoded?.rotationA, original.rotationA)
          XCTAssertEqual(decoded?.rotationB, original.rotationB)
          XCTAssertEqual(decoded?.startingRotation, original.startingRotation)
          XCTAssertEqual(decoded?.startingDate, original.startingDate)
          XCTAssertEqual(decoded?.notifyDayBefore, original.notifyDayBefore)
          XCTAssertEqual(decoded?.notifyMorningOf, original.notifyMorningOf)
      }

      // MARK: - MaintenanceItem

      func test_maintenanceItem_roundtrip_withLastCompleted() {
          let original = MaintenanceItem(
              name: "Change furnace filter", category: .yearRound,
              intervalDays: 90, lastCompletedDate: date(2026, 1, 1),
              notes: "Use MERV-11", templateID: "tmpl-abc"
          )
          let decoded = MaintenanceItem(from: original.toCKRecord())
          XCTAssertEqual(decoded?.name, original.name)
          XCTAssertEqual(decoded?.category, original.category)
          XCTAssertEqual(decoded?.intervalDays, original.intervalDays)
          XCTAssertEqual(decoded?.lastCompletedDate, original.lastCompletedDate)
          XCTAssertEqual(decoded?.notes, original.notes)
          XCTAssertEqual(decoded?.templateID, original.templateID)
      }

      func test_maintenanceItem_roundtrip_nilLastCompleted() {
          let original = MaintenanceItem(
              name: "Flush water heater", category: .yearRound,
              intervalDays: 365, lastCompletedDate: nil,
              notes: nil, templateID: nil
          )
          let decoded = MaintenanceItem(from: original.toCKRecord())
          XCTAssertNil(decoded?.lastCompletedDate)
      }

      // MARK: - HouseMateTask

      func test_task_roundtrip_withDueDate() {
          let original = HouseMateTask(
              title: "Take out trash", category: .kitchen, priority: .medium,
              isRecurring: true, recurringInterval: .weekly,
              dueDate: date(2026, 4, 1)
          )
          let decoded = HouseMateTask(from: original.toCKRecord())
          XCTAssertEqual(decoded?.title, original.title)
          XCTAssertEqual(decoded?.category, original.category)
          XCTAssertEqual(decoded?.priority, original.priority)
          XCTAssertEqual(decoded?.isRecurring, original.isRecurring)
          XCTAssertEqual(decoded?.recurringInterval, original.recurringInterval)
          XCTAssertEqual(decoded?.dueDate, original.dueDate)
          XCTAssertEqual(decoded?.isCompleted, false)
      }

      func test_task_roundtrip_nilDueDate() {
          let original = HouseMateTask(
              title: "Buy groceries", category: .errands, priority: .high,
              isRecurring: false, recurringInterval: nil, dueDate: nil
          )
          let decoded = HouseMateTask(from: original.toCKRecord())
          XCTAssertNil(decoded?.dueDate)
          XCTAssertNil(decoded?.recurringInterval)
      }

      // MARK: - MaintenanceLog

      func test_maintenanceLog_roundtrip() {
          let itemRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: "item-123"), action: .deleteSelf)
          let original = MaintenanceLog(
              maintenanceItemID: itemRef,
              completedDate: date(2026, 3, 1),
              notes: "Used professional service",
              cost: 149.99
          )
          let decoded = MaintenanceLog(from: original.toCKRecord())
          XCTAssertEqual(decoded?.completedDate, original.completedDate)
          XCTAssertEqual(decoded?.notes, original.notes)
          XCTAssertEqual(decoded?.cost, original.cost)
          XCTAssertEqual(decoded?.maintenanceItemID.recordID.recordName, itemRef.recordID.recordName)
      }

      // MARK: - Household

      func test_household_roundtrip_withMembers() {
          let creatorRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: "creator-001"), action: .none)
          let memberRef  = CKRecord.Reference(recordID: CKRecord.ID(recordName: "member-002"), action: .none)
          let original = Household(
              name: "The Smith Household",
              createdBy: creatorRef,
              members: [creatorRef, memberRef]
          )
          let decoded = Household(from: original.toCKRecord())
          XCTAssertEqual(decoded?.name, original.name)
          XCTAssertEqual(decoded?.createdBy?.recordID.recordName, creatorRef.recordID.recordName)
          XCTAssertEqual(decoded?.members.count, 2)
          XCTAssertEqual(decoded?.members[0].recordID.recordName, creatorRef.recordID.recordName)
      }

      func test_household_roundtrip_noCreator() {
          let original = Household(name: "New Household", createdBy: nil, members: [])
          let decoded = Household(from: original.toCKRecord())
          XCTAssertEqual(decoded?.name, original.name)
          XCTAssertNil(decoded?.createdBy)
          XCTAssertEqual(decoded?.members.count, 0)
      }

      // MARK: - Member

      func test_member_roundtrip() {
          let original = Member(displayName: "Alex", appleUserID: "user_abc123")
          let decoded = Member(from: original.toCKRecord())
          XCTAssertEqual(decoded?.displayName, original.displayName)
          XCTAssertEqual(decoded?.appleUserID, original.appleUserID)
      }

      // MARK: - TaskTemplate (user-created)

      func test_taskTemplate_userCreated_withInterval_roundtrip() {
          let original = TaskTemplate(
              title: "Water plants", category: .outdoor,
              recurringInterval: .weekly, isBuiltIn: false
          )
          let decoded = TaskTemplate(from: original.toCKRecord())
          XCTAssertEqual(decoded?.title, original.title)
          XCTAssertEqual(decoded?.category, original.category)
          XCTAssertEqual(decoded?.recurringInterval, original.recurringInterval)
          XCTAssertFalse(decoded?.isBuiltIn ?? true)
      }

      func test_taskTemplate_userCreated_nilInterval_roundtrip() {
          // Seasonal / one-time templates have no interval
          let original = TaskTemplate(
              title: "Spring cleaning", category: .other,
              recurringInterval: nil, isBuiltIn: false
          )
          let decoded = TaskTemplate(from: original.toCKRecord())
          XCTAssertEqual(decoded?.title, original.title)
          XCTAssertNil(decoded?.recurringInterval)
      }

      // MARK: - TaskCompletionLog

      func test_taskCompletionLog_roundtrip() {
          let taskRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: "task-456"), action: .deleteSelf)
          let memberRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: "member-789"), action: .none)
          let original = TaskCompletionLog(
              taskID: taskRef, completedBy: memberRef, completedAt: date(2026, 3, 10)
          )
          let decoded = TaskCompletionLog(from: original.toCKRecord())
          XCTAssertEqual(decoded?.completedAt, original.completedAt)
          XCTAssertEqual(decoded?.taskID.recordID.recordName, taskRef.recordID.recordName)
          XCTAssertEqual(decoded?.completedBy.recordID.recordName, memberRef.recordID.recordName)
      }

      // MARK: - MaintenanceTemplate (user-created)

      func test_maintenanceTemplate_userCreated_roundtrip() {
          let original = MaintenanceTemplate(
              name: "Check sprinkler heads", category: .spring,
              intervalDays: 365, isBuiltIn: false
          )
          let decoded = MaintenanceTemplate(from: original.toCKRecord())
          XCTAssertEqual(decoded?.name, original.name)
          XCTAssertEqual(decoded?.category, original.category)
          XCTAssertEqual(decoded?.intervalDays, original.intervalDays)
          XCTAssertFalse(decoded?.isBuiltIn ?? true)
      }
  }
  ```

- [ ] **Step 2: Run — expect compile failure**

  ⌘U.

- [ ] **Step 3: Create CKRecord+HouseMate.swift**

  ```swift
  import Foundation
  import CloudKit

  // MARK: - Record Type Name Constants

  enum CKRecordTypeName {
      static let household          = "Household"
      static let member             = "Member"
      static let task               = "HouseMateTask"
      static let taskCompletionLog  = "TaskCompletionLog"
      static let taskTemplate       = "TaskTemplate"
      static let binSchedule        = "BinSchedule"
      static let maintenanceItem    = "MaintenanceItem"
      static let maintenanceLog     = "MaintenanceLog"
      static let maintenanceTemplate = "MaintenanceTemplate"
  }

  // MARK: - BinSchedule

  extension BinSchedule {
      func toCKRecord() -> CKRecord {
          let id = recordID ?? CKRecord.ID(recordName: UUID().uuidString)
          let r = CKRecord(recordType: CKRecordTypeName.binSchedule, recordID: id)
          r["pickupDayOfWeek"]  = pickupDayOfWeek as NSNumber
          r["rotationA"]        = rotationA as NSString
          r["rotationB"]        = rotationB as NSString
          r["startingRotation"] = startingRotation.rawValue as NSString
          r["startingDate"]     = startingDate as NSDate
          r["notifyDayBefore"]  = (notifyDayBefore ? 1 : 0) as NSNumber
          r["notifyMorningOf"]  = (notifyMorningOf ? 1 : 0) as NSNumber
          return r
      }

      init?(from record: CKRecord) {
          guard record.recordType == CKRecordTypeName.binSchedule,
                let dow      = record["pickupDayOfWeek"] as? Int,
                let rotA     = record["rotationA"] as? String,
                let rotB     = record["rotationB"] as? String,
                let rotRaw   = record["startingRotation"] as? String,
                let rotStart = BinRotation(rawValue: rotRaw),
                let startDt  = record["startingDate"] as? Date else { return nil }
          self.recordID         = record.recordID
          self.pickupDayOfWeek  = dow
          self.rotationA        = rotA
          self.rotationB        = rotB
          self.startingRotation = rotStart
          self.startingDate     = startDt
          self.notifyDayBefore  = (record["notifyDayBefore"] as? Int ?? 0) == 1
          self.notifyMorningOf  = (record["notifyMorningOf"] as? Int ?? 0) == 1
      }
  }

  // MARK: - MaintenanceItem

  extension MaintenanceItem {
      func toCKRecord() -> CKRecord {
          let id = recordID ?? CKRecord.ID(recordName: UUID().uuidString)
          let r = CKRecord(recordType: CKRecordTypeName.maintenanceItem, recordID: id)
          r["name"]        = name as NSString
          r["category"]    = category.rawValue as NSString
          r["intervalDays"] = intervalDays as NSNumber
          if let last = lastCompletedDate { r["lastCompletedDate"] = last as NSDate }
          if let n = notes    { r["notes"]      = n as NSString }
          if let t = templateID { r["templateID"] = t as NSString }
          return r
      }

      init?(from record: CKRecord) {
          guard record.recordType == CKRecordTypeName.maintenanceItem,
                let name    = record["name"] as? String,
                let catRaw  = record["category"] as? String,
                let cat     = SeasonalCategory(rawValue: catRaw),
                let interval = record["intervalDays"] as? Int else { return nil }
          self.recordID          = record.recordID
          self.name              = name
          self.category          = cat
          self.intervalDays      = interval
          self.lastCompletedDate = record["lastCompletedDate"] as? Date
          self.notes             = record["notes"] as? String
          self.templateID        = record["templateID"] as? String
      }
  }

  // MARK: - HouseMateTask

  extension HouseMateTask {
      func toCKRecord() -> CKRecord {
          let id = recordID ?? CKRecord.ID(recordName: UUID().uuidString)
          let r = CKRecord(recordType: CKRecordTypeName.task, recordID: id)
          r["title"]       = title as NSString
          r["category"]    = category.rawValue as NSString
          r["priority"]    = priority.rawValue as NSString
          r["isRecurring"] = (isRecurring ? 1 : 0) as NSNumber
          r["isCompleted"] = (isCompleted ? 1 : 0) as NSNumber
          if let i = recurringInterval { r["recurringInterval"] = i.rawValue as NSString }
          if let d = dueDate       { r["dueDate"]      = d as NSDate }
          if let a = assignedTo    { r["assignedTo"]   = a }
          if let c = completedBy   { r["completedBy"]  = c }
          if let ca = completedAt  { r["completedAt"]  = ca as NSDate }
          if let t = templateID    { r["templateID"]   = t as NSString }
          return r
      }

      init?(from record: CKRecord) {
          guard record.recordType == CKRecordTypeName.task,
                let title  = record["title"] as? String,
                let catRaw = record["category"] as? String,
                let cat    = TaskCategory(rawValue: catRaw),
                let priRaw = record["priority"] as? String,
                let pri    = TaskPriority(rawValue: priRaw) else { return nil }
          self.recordID          = record.recordID
          self.title             = title
          self.category          = cat
          self.priority          = pri
          self.isRecurring       = (record["isRecurring"] as? Int ?? 0) == 1
          self.isCompleted       = (record["isCompleted"] as? Int ?? 0) == 1
          self.dueDate           = record["dueDate"] as? Date
          self.assignedTo        = record["assignedTo"] as? CKRecord.Reference
          self.completedBy       = record["completedBy"] as? CKRecord.Reference
          self.completedAt       = record["completedAt"] as? Date
          self.templateID        = record["templateID"] as? String
          self.recurringInterval = (record["recurringInterval"] as? String).flatMap(RecurringInterval.init)
      }
  }

  // MARK: - TaskCompletionLog

  extension TaskCompletionLog {
      func toCKRecord() -> CKRecord {
          let id = recordID ?? CKRecord.ID(recordName: UUID().uuidString)
          let r = CKRecord(recordType: CKRecordTypeName.taskCompletionLog, recordID: id)
          r["taskID"]      = taskID
          r["completedBy"] = completedBy
          r["completedAt"] = completedAt as NSDate
          return r
      }

      init?(from record: CKRecord) {
          guard record.recordType == CKRecordTypeName.taskCompletionLog,
                let taskRef   = record["taskID"] as? CKRecord.Reference,
                let memberRef = record["completedBy"] as? CKRecord.Reference,
                let at        = record["completedAt"] as? Date else { return nil }
          self.recordID    = record.recordID
          self.taskID      = taskRef
          self.completedBy = memberRef
          self.completedAt = at
      }
  }

  // MARK: - Household

  extension Household {
      func toCKRecord() -> CKRecord {
          let id = recordID ?? CKRecord.ID(recordName: UUID().uuidString)
          let r = CKRecord(recordType: CKRecordTypeName.household, recordID: id)
          r["name"]    = name as NSString
          if let c = createdBy { r["createdBy"] = c }
          r["members"] = members as NSArray
          return r
      }

      init?(from record: CKRecord) {
          guard record.recordType == CKRecordTypeName.household,
                let name = record["name"] as? String else { return nil }
          self.recordID  = record.recordID
          self.name      = name
          self.createdBy = record["createdBy"] as? CKRecord.Reference
          self.members   = record["members"] as? [CKRecord.Reference] ?? []
      }
  }

  // MARK: - Member

  extension Member {
      func toCKRecord() -> CKRecord {
          let id = recordID ?? CKRecord.ID(recordName: UUID().uuidString)
          let r = CKRecord(recordType: CKRecordTypeName.member, recordID: id)
          r["displayName"] = displayName as NSString
          r["appleUserID"] = appleUserID as NSString
          return r
      }

      init?(from record: CKRecord) {
          guard record.recordType == CKRecordTypeName.member,
                let displayName = record["displayName"] as? String,
                let appleUserID = record["appleUserID"] as? String else { return nil }
          self.recordID    = record.recordID
          self.displayName = displayName
          self.appleUserID = appleUserID
      }
  }

  // MARK: - MaintenanceLog

  extension MaintenanceLog {
      func toCKRecord() -> CKRecord {
          let id = recordID ?? CKRecord.ID(recordName: UUID().uuidString)
          let r = CKRecord(recordType: CKRecordTypeName.maintenanceLog, recordID: id)
          r["maintenanceItemID"] = maintenanceItemID
          r["completedDate"]     = completedDate as NSDate
          if let n = notes { r["notes"] = n as NSString }
          if let c = cost  { r["cost"]  = c as NSNumber }
          return r
      }

      init?(from record: CKRecord) {
          guard record.recordType == CKRecordTypeName.maintenanceLog,
                let itemRef = record["maintenanceItemID"] as? CKRecord.Reference,
                let date    = record["completedDate"] as? Date else { return nil }
          self.recordID           = record.recordID
          self.maintenanceItemID  = itemRef
          self.completedDate      = date
          self.notes              = record["notes"] as? String
          self.cost               = record["cost"] as? Double
      }
  }

  // MARK: - TaskTemplate (user-created only — built-ins live locally)

  extension TaskTemplate {
      func toCKRecord() -> CKRecord {
          let id = recordID ?? CKRecord.ID(recordName: UUID().uuidString)
          let r = CKRecord(recordType: CKRecordTypeName.taskTemplate, recordID: id)
          r["title"]    = title as NSString
          r["category"] = category.rawValue as NSString
          r["isBuiltIn"] = 0 as NSNumber
          if let i = recurringInterval { r["recurringInterval"] = i.rawValue as NSString }
          return r
      }

      init?(from record: CKRecord) {
          guard record.recordType == CKRecordTypeName.taskTemplate,
                let title  = record["title"] as? String,
                let catRaw = record["category"] as? String,
                let cat    = TaskCategory(rawValue: catRaw) else { return nil }
          self.recordID          = record.recordID
          self.title             = title
          self.category          = cat
          self.isBuiltIn         = false
          self.recurringInterval = (record["recurringInterval"] as? String).flatMap(RecurringInterval.init)
      }
  }

  // MARK: - MaintenanceTemplate (user-created only)

  extension MaintenanceTemplate {
      func toCKRecord() -> CKRecord {
          let id = recordID ?? CKRecord.ID(recordName: UUID().uuidString)
          let r = CKRecord(recordType: CKRecordTypeName.maintenanceTemplate, recordID: id)
          r["name"]        = name as NSString
          r["category"]    = category.rawValue as NSString
          r["intervalDays"] = intervalDays as NSNumber
          r["isBuiltIn"]   = 0 as NSNumber
          return r
      }

      init?(from record: CKRecord) {
          guard record.recordType == CKRecordTypeName.maintenanceTemplate,
                let name    = record["name"] as? String,
                let catRaw  = record["category"] as? String,
                let cat     = SeasonalCategory(rawValue: catRaw),
                let interval = record["intervalDays"] as? Int else { return nil }
          self.recordID     = record.recordID
          self.name         = name
          self.category     = cat
          self.intervalDays = interval
          self.isBuiltIn    = false
      }
  }
  ```

- [ ] **Step 4: Run tests — all mapping tests PASS**

  ⌘U.

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/Services/CKRecord+HouseMate.swift HouseMateTests/Services/CKRecordMappingTests.swift
  git commit -m "feat: add CKRecord encode/decode extensions for all models (tested)"
  ```

---

### Task 10: CloudKitService Base

**Files:**
- Create: `HouseMate/Services/CloudKitService.swift`

- [ ] **Step 1: Create CloudKitService.swift**

  ```swift
  import CloudKit

  enum CloudKitError: Error, LocalizedError {
      case notAuthenticated
      case recordNotFound
      case zoneNotFound
      case unexpectedType
      case alreadyCompleted

      var errorDescription: String? {
          switch self {
          case .notAuthenticated:  return "iCloud account not available."
          case .recordNotFound:    return "Record not found."
          case .zoneNotFound:      return "CloudKit zone not found."
          case .unexpectedType:    return "Unexpected CloudKit record type."
          case .alreadyCompleted:  return "This task was already completed."
          }
      }
  }

  @MainActor
  final class CloudKitService {
      static let shared = CloudKitService()

      let container: CKContainer
      let privateDB: CKDatabase
      let sharedDB: CKDatabase

      static let householdZoneName = "HouseholdZone"
      private static let hasCreatedZoneKey = "ck_zone_created"

      /// The current user's record name, set after startup. Used for owner-vs-participant routing.
      var currentUserRecordName: String?

      private init() {
          container = CKContainer(identifier: "iCloud.com.housemate.app")
          privateDB = container.privateCloudDatabase
          sharedDB  = container.sharedCloudDatabase
      }

      // MARK: - Account

      /// Returns the current iCloud account status.
      func checkAccountStatus() async throws {
          let status = try await container.accountStatus()
          guard status == .available else {
              throw CloudKitError.notAuthenticated
          }
      }

      /// Fetches the current user's stable CloudKit record ID and caches the record name.
      @discardableResult
      func fetchAndCacheCurrentUserRecordName() async throws -> String {
          let recordID = try await container.userRecordID()
          currentUserRecordName = recordID.recordName
          return recordID.recordName
      }

      // MARK: - Database Routing

      /// Returns the correct database for household data operations.
      /// The household creator (owner) uses privateDB; invited participants use sharedDB.
      func householdDatabase(ownerRecordName: String) -> CKDatabase {
          guard let current = currentUserRecordName else { return privateDB }
          return ownerRecordName == current ? privateDB : sharedDB
      }

      /// Returns the zone ID for household data using the owner's record name.
      /// This is necessary because CloudKit zone IDs encode the owner's identity.
      func householdZoneID(ownerRecordName: String) -> CKRecordZone.ID {
          CKRecordZone.ID(zoneName: Self.householdZoneName, ownerName: ownerRecordName)
      }

      /// The owner's private zone ID — used only by the household creator during setup.
      var ownerZoneID: CKRecordZone.ID {
          CKRecordZone.ID(zoneName: Self.householdZoneName, ownerName: CKCurrentUserDefaultName)
      }

      // MARK: - Zone Setup

      /// Creates the shared custom zone in the owner's private database.
      /// Gated by a UserDefaults flag — safe to call on every launch but only
      /// actually creates the zone once. Non-owners skip this entirely (zone
      /// creation in someone else's private database would fail).
      func createSharedZoneIfNeeded() async throws {
          guard currentUserRecordName != nil else { return }
          let key = Self.hasCreatedZoneKey
          guard !UserDefaults.standard.bool(forKey: key) else { return }
          let zone = CKRecordZone(zoneID: ownerZoneID)
          _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
          UserDefaults.standard.set(true, forKey: key)
      }
  }
  ```

- [ ] **Step 2: Build — no compile errors**

  ⌘B.

- [ ] **Step 3: Commit**

  ```bash
  git add HouseMate/Services/CloudKitService.swift
  git commit -m "feat: add CloudKitService base with container, zones, and account check"
  ```

---

### Task 11: Domain Service Classes

**Files:**
- Create: `HouseMate/Services/HouseholdService.swift`
- Create: `HouseMate/Services/TaskService.swift`
- Create: `HouseMate/Services/BinScheduleService.swift`
- Create: `HouseMate/Services/MaintenanceService.swift`

- [ ] **Step 1: Create HouseholdService.swift**

  ```swift
  import CloudKit

  @MainActor
  final class HouseholdService {
      private let ck = CloudKitService.shared

      // MARK: - Create

      func createHousehold(name: String, creatorRecordName: String) async throws -> (Household, CKShare) {
          let creatorRecordID = CKRecord.ID(recordName: creatorRecordName)
          let creatorRef = CKRecord.Reference(recordID: creatorRecordID, action: .none)

          // Build the record directly in the household zone (zone must already exist from app startup)
          let zoneID = ck.ownerZoneID
          let ckRecord = CKRecord(
              recordType: CKRecordTypeName.household,
              recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
          )
          ckRecord["name"]      = name as NSString
          ckRecord["createdBy"] = creatorRef
          ckRecord["members"]   = [creatorRef] as NSArray

          let share = CKShare(rootRecord: ckRecord)
          share[CKShare.SystemFieldKey.title] = name as CKRecordValue
          share.publicPermission = .none

          let (savedRecords, _, _) = try await ck.privateDB.modifyRecords(saving: [ckRecord, share], deleting: [])
          guard let saved = savedRecords
              .first(where: { $0.recordType == CKRecordTypeName.household })
              .flatMap(Household.init) else {
              throw CloudKitError.recordNotFound
          }
          let savedShare = savedRecords.first(where: { $0 is CKShare }) as? CKShare ?? share
          return (saved, savedShare)
      }

      // MARK: - Fetch

      /// Fetches the household, trying the owner's private database first,
      /// then all shared zones (for invited participants).
      func fetchHousehold() async throws -> Household? {
          // Try owner path first
          let ownerZoneID = ck.ownerZoneID
          let query = CKQuery(recordType: CKRecordTypeName.household, predicate: NSPredicate(value: true))
          if let household = try? await {
              let (results, _) = try await ck.privateDB.records(matching: query, inZoneWith: ownerZoneID)
              return results.compactMap { try? $0.1.get() }.compactMap(Household.init).first
          }() {
              return household
          }

          // Participant path: discover shared zones and search each
          let sharedZones = try await ck.sharedDB.allRecordZones()
          for zone in sharedZones where zone.zoneID.zoneName == CloudKitService.householdZoneName {
              let (results, _) = try await ck.sharedDB.records(matching: query, inZoneWith: zone.zoneID)
              if let household = results.compactMap({ try? $0.1.get() }).compactMap(Household.init).first {
                  return household
              }
          }
          return nil
      }

      // MARK: - Update

      func updateHouseholdName(_ name: String, household: Household, ownerRecordName: String) async throws -> Household {
          guard let recordID = household.recordID else { throw CloudKitError.recordNotFound }
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let record = try await db.record(for: recordID)
          record["name"] = name as NSString
          let saved = try await db.save(record)
          guard let updated = Household(from: saved) else { throw CloudKitError.unexpectedType }
          return updated
      }

      // MARK: - Share Management

      /// Deletes the existing CKShare and creates a new one, invalidating the old invite link.
      /// Only the household creator can call this.
      func regenerateShareLink(for household: Household) async throws -> CKShare {
          guard let recordID = household.recordID else { throw CloudKitError.recordNotFound }
          let householdRecord = try await ck.privateDB.record(for: recordID)
          let newShare = CKShare(rootRecord: householdRecord)
          newShare.publicPermission = .none
          let (saved, _, _) = try await ck.privateDB.modifyRecords(saving: [householdRecord, newShare], deleting: [])
          guard let share = saved.first(where: { $0 is CKShare }) as? CKShare else {
              throw CloudKitError.recordNotFound
          }
          return share
      }

      // MARK: - Members

      func fetchMembers(household: Household, ownerRecordName: String) async throws -> [Member] {
          let refs = household.members
          guard !refs.isEmpty else { return [] }
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let results = try await db.records(for: refs.map(\.recordID))
          return results.values.compactMap { try? $0.get() }.compactMap(Member.init)
      }
  }
  ```

- [ ] **Step 2: Create TaskService.swift**

  ```swift
  import CloudKit

  @MainActor
  final class TaskService {
      private let ck = CloudKitService.shared

      // MARK: - CRUD

      func fetchAllTasks(ownerRecordName: String) async throws -> [HouseMateTask] {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          let query = CKQuery(recordType: CKRecordTypeName.task, predicate: NSPredicate(value: true))
          query.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
          let (results, _) = try await db.records(matching: query, inZoneWith: zoneID)
          return results.compactMap { try? $0.1.get() }.compactMap(HouseMateTask.init)
      }

      func saveTask(_ task: HouseMateTask, ownerRecordName: String) async throws -> HouseMateTask {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          var taskToSave = task
          // Ensure new records are placed in the household zone, not the default zone
          if taskToSave.recordID == nil {
              taskToSave.recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
          }
          let saved = try await db.save(taskToSave.toCKRecord())
          guard let updated = HouseMateTask(from: saved) else { throw CloudKitError.unexpectedType }
          return updated
      }

      /// Hard-deletes the task. TaskCompletionLog records cascade-delete via .deleteSelf.
      func deleteTask(_ task: HouseMateTask, ownerRecordName: String) async throws {
          guard let recordID = task.recordID else { return }
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          try await db.deleteRecord(withID: recordID)
      }

      // MARK: - Completion

      /// Completes a task. For recurring tasks, advances the due date.
      /// Fetches a fresh record first to guard against concurrent completion of non-recurring tasks.
      /// For recurring tasks, concurrent completion is allowed (both log entries created, last write wins
      /// for date advancement — this is intentional per spec, not an oversight).
      func completeTask(_ task: HouseMateTask, by memberRef: CKRecord.Reference, ownerRecordName: String) async throws -> (HouseMateTask, TaskCompletionLog) {
          guard let taskRecordID = task.recordID else { throw CloudKitError.recordNotFound }
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)

          let freshRecord = try await db.record(for: taskRecordID)
          guard let freshTask = HouseMateTask(from: freshRecord) else { throw CloudKitError.unexpectedType }

          // For non-recurring: throw if already completed (concurrent completion guard).
          // For recurring: allow concurrent completion — last write wins per spec.
          if freshTask.isCompleted && !freshTask.isRecurring {
              throw CloudKitError.alreadyCompleted
          }

          var updatedTask = freshTask
          let taskRef = CKRecord.Reference(recordID: taskRecordID, action: .deleteSelf)
          let log = TaskCompletionLog(taskID: taskRef, completedBy: memberRef, completedAt: Date())

          if updatedTask.isRecurring {
              updatedTask.advanceRecurringDueDate()
          } else {
              updatedTask.isCompleted = true
              updatedTask.completedBy = memberRef
              updatedTask.completedAt = Date()
          }

          let (saved, _, _) = try await db.modifyRecords(
              saving: [updatedTask.toCKRecord(), log.toCKRecord()], deleting: []
          )
          guard
              let savedTask = saved.first(where: { $0.recordType == CKRecordTypeName.task }).flatMap(HouseMateTask.init),
              let savedLog  = saved.first(where: { $0.recordType == CKRecordTypeName.taskCompletionLog }).flatMap(TaskCompletionLog.init)
          else { throw CloudKitError.unexpectedType }

          return (savedTask, savedLog)
      }

      // MARK: - History

      func fetchCompletionLogs(for task: HouseMateTask, ownerRecordName: String, limit: Int = 5) async throws -> [TaskCompletionLog] {
          guard let recordID = task.recordID else { return [] }
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          let ref  = CKRecord.Reference(recordID: recordID, action: .none)
          let pred = NSPredicate(format: "taskID == %@", ref)
          let query = CKQuery(recordType: CKRecordTypeName.taskCompletionLog, predicate: pred)
          query.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
          let (results, _) = try await db.records(matching: query, inZoneWith: zoneID, resultsLimit: limit)
          return results.compactMap { try? $0.1.get() }.compactMap(TaskCompletionLog.init)
      }

      // MARK: - User Templates

      func fetchUserTaskTemplates(ownerRecordName: String) async throws -> [TaskTemplate] {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          let query = CKQuery(recordType: CKRecordTypeName.taskTemplate, predicate: NSPredicate(value: true))
          let (results, _) = try await db.records(matching: query, inZoneWith: zoneID)
          return results.compactMap { try? $0.1.get() }.compactMap(TaskTemplate.init)
      }

      func saveUserTaskTemplate(_ template: TaskTemplate, ownerRecordName: String) async throws -> TaskTemplate {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          var tmpl = template
          if tmpl.recordID == nil {
              tmpl.recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
          }
          let saved = try await db.save(tmpl.toCKRecord())
          guard let updated = TaskTemplate(from: saved) else { throw CloudKitError.unexpectedType }
          return updated
      }

      func deleteUserTaskTemplate(_ template: TaskTemplate, ownerRecordName: String) async throws {
          guard let recordID = template.recordID else { return }
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          try await db.deleteRecord(withID: recordID)
      }
  }
  ```

- [ ] **Step 3: Create BinScheduleService.swift**

  ```swift
  import CloudKit

  @MainActor
  final class BinScheduleService {
      private let ck = CloudKitService.shared

      func fetchBinSchedule(ownerRecordName: String) async throws -> BinSchedule? {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          let query = CKQuery(recordType: CKRecordTypeName.binSchedule, predicate: NSPredicate(value: true))
          let (results, _) = try await db.records(matching: query, inZoneWith: zoneID, resultsLimit: 1)
          return results.compactMap { try? $0.1.get() }.compactMap(BinSchedule.init).first
      }

      func saveBinSchedule(_ schedule: BinSchedule, ownerRecordName: String) async throws -> BinSchedule {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          var scheduleToSave = schedule
          if scheduleToSave.recordID == nil {
              scheduleToSave.recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
          }
          let saved = try await db.save(scheduleToSave.toCKRecord())
          guard let updated = BinSchedule(from: saved) else { throw CloudKitError.unexpectedType }
          return updated
      }
  }
  ```

- [ ] **Step 4: Create MaintenanceService.swift**

  ```swift
  import CloudKit

  @MainActor
  final class MaintenanceService {
      private let ck = CloudKitService.shared

      // MARK: - Items

      func fetchAllItems(ownerRecordName: String) async throws -> [MaintenanceItem] {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          let query = CKQuery(recordType: CKRecordTypeName.maintenanceItem, predicate: NSPredicate(value: true))
          let (results, _) = try await db.records(matching: query, inZoneWith: zoneID)
          return results.compactMap { try? $0.1.get() }.compactMap(MaintenanceItem.init)
      }

      func saveItem(_ item: MaintenanceItem, ownerRecordName: String) async throws -> MaintenanceItem {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          var itemToSave = item
          if itemToSave.recordID == nil {
              itemToSave.recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
          }
          let saved = try await db.save(itemToSave.toCKRecord())
          guard let updated = MaintenanceItem(from: saved) else { throw CloudKitError.unexpectedType }
          return updated
      }

      func deleteItem(_ item: MaintenanceItem, ownerRecordName: String) async throws {
          guard let recordID = item.recordID else { return }
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          try await db.deleteRecord(withID: recordID)
      }

      // MARK: - Logs

      /// Saves a completion log and updates lastCompletedDate on the item atomically.
      func logCompletion(_ log: MaintenanceLog, updatingItem item: MaintenanceItem, ownerRecordName: String) async throws -> (MaintenanceItem, MaintenanceLog) {
          var updatedItem = item
          updatedItem.lastCompletedDate = log.completedDate
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let (saved, _, _) = try await db.modifyRecords(
              saving: [updatedItem.toCKRecord(), log.toCKRecord()], deleting: []
          )
          guard
              let savedItem = saved.first(where: { $0.recordType == CKRecordTypeName.maintenanceItem }).flatMap(MaintenanceItem.init),
              let savedLog  = saved.first(where: { $0.recordType == CKRecordTypeName.maintenanceLog }).flatMap(MaintenanceLog.init)
          else { throw CloudKitError.unexpectedType }
          return (savedItem, savedLog)
      }

      func fetchLogs(for item: MaintenanceItem, ownerRecordName: String) async throws -> [MaintenanceLog] {
          guard let recordID = item.recordID else { return [] }
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          let ref  = CKRecord.Reference(recordID: recordID, action: .none)
          let pred = NSPredicate(format: "maintenanceItemID == %@", ref)
          let query = CKQuery(recordType: CKRecordTypeName.maintenanceLog, predicate: pred)
          query.sortDescriptors = [NSSortDescriptor(key: "completedDate", ascending: false)]
          let (results, _) = try await db.records(matching: query, inZoneWith: zoneID)
          return results.compactMap { try? $0.1.get() }.compactMap(MaintenanceLog.init)
      }

      // MARK: - User Templates

      func fetchUserMaintenanceTemplates(ownerRecordName: String) async throws -> [MaintenanceTemplate] {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          let query = CKQuery(recordType: CKRecordTypeName.maintenanceTemplate, predicate: NSPredicate(value: true))
          let (results, _) = try await db.records(matching: query, inZoneWith: zoneID)
          return results.compactMap { try? $0.1.get() }.compactMap(MaintenanceTemplate.init)
      }

      func saveUserMaintenanceTemplate(_ template: MaintenanceTemplate, ownerRecordName: String) async throws -> MaintenanceTemplate {
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          let zoneID = ck.householdZoneID(ownerRecordName: ownerRecordName)
          var tmpl = template
          if tmpl.recordID == nil {
              tmpl.recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
          }
          let saved = try await db.save(tmpl.toCKRecord())
          guard let updated = MaintenanceTemplate(from: saved) else { throw CloudKitError.unexpectedType }
          return updated
      }

      func deleteUserMaintenanceTemplate(_ template: MaintenanceTemplate, ownerRecordName: String) async throws {
          guard let recordID = template.recordID else { return }
          let db = ck.householdDatabase(ownerRecordName: ownerRecordName)
          try await db.deleteRecord(withID: recordID)
      }
  }
  ```

- [ ] **Step 5: Build — no compile errors**

  ⌘B. Fix any issues before continuing.

- [ ] **Step 6: Commit**

  ```bash
  git add HouseMate/Services/
  git commit -m "feat: add domain service layer (Household, Task, BinSchedule, Maintenance)"
  ```

---

## Chunk 4: Built-in Templates + App Wiring

### Task 12: Built-in Templates

**Files:**
- Create: `HouseMate/Resources/BuiltInTemplates.swift`

- [ ] **Step 1: Create BuiltInTemplates.swift**

  ```swift
  import Foundation

  enum BuiltInTemplates {

      // MARK: - Task Templates

      static let tasks: [TaskTemplate] = [
          // Weekly
          TaskTemplate(title: "Take out trash",              category: .kitchen,  recurringInterval: .weekly,  isBuiltIn: true),
          TaskTemplate(title: "Vacuum living room",           category: .other,    recurringInterval: .weekly,  isBuiltIn: true),
          TaskTemplate(title: "Clean bathrooms",             category: .bathroom, recurringInterval: .weekly,  isBuiltIn: true),
          TaskTemplate(title: "Wipe down kitchen counters",  category: .kitchen,  recurringInterval: .weekly,  isBuiltIn: true),
          TaskTemplate(title: "Do laundry",                  category: .other,    recurringInterval: .weekly,  isBuiltIn: true),
          TaskTemplate(title: "Mop floors",                  category: .other,    recurringInterval: .weekly,  isBuiltIn: true),
          // Monthly
          TaskTemplate(title: "Clean fridge",                category: .kitchen,  recurringInterval: .monthly, isBuiltIn: true),
          TaskTemplate(title: "Dust ceiling fans",           category: .other,    recurringInterval: .monthly, isBuiltIn: true),
          TaskTemplate(title: "Wash windows",                category: .outdoor,  recurringInterval: .monthly, isBuiltIn: true),
          TaskTemplate(title: "Deep clean oven",             category: .kitchen,  recurringInterval: .monthly, isBuiltIn: true),
          // Seasonal / one-time checklists
          TaskTemplate(title: "Spring cleaning",             category: .other,    recurringInterval: nil,      isBuiltIn: true),
          TaskTemplate(title: "Pre-guest prep",              category: .other,    recurringInterval: nil,      isBuiltIn: true),
          TaskTemplate(title: "Move-in checklist",           category: .other,    recurringInterval: nil,      isBuiltIn: true),
      ]

      // MARK: - Maintenance Templates

      static let maintenanceItems: [MaintenanceTemplate] = [
          MaintenanceTemplate(name: "Change furnace filter",      category: .yearRound, intervalDays: 90,  isBuiltIn: true),
          MaintenanceTemplate(name: "Replace HVAC filter",        category: .yearRound, intervalDays: 90,  isBuiltIn: true),
          MaintenanceTemplate(name: "Clean dryer vent",           category: .yearRound, intervalDays: 365, isBuiltIn: true),
          MaintenanceTemplate(name: "Sweep/blow out garage",      category: .yearRound, intervalDays: 30,  isBuiltIn: true),
          MaintenanceTemplate(name: "Test smoke detectors",       category: .yearRound, intervalDays: 180, isBuiltIn: true),
          MaintenanceTemplate(name: "Clean range hood filter",    category: .yearRound, intervalDays: 90,  isBuiltIn: true),
          MaintenanceTemplate(name: "Flush water heater",         category: .yearRound, intervalDays: 365, isBuiltIn: true),
          MaintenanceTemplate(name: "Check window/door seals",   category: .fall,      intervalDays: 365, isBuiltIn: true),
          MaintenanceTemplate(name: "Clean gutters",              category: .spring,    intervalDays: 180, isBuiltIn: true),
          MaintenanceTemplate(name: "Winterize outdoor faucets",  category: .fall,      intervalDays: 365, isBuiltIn: true),
      ]
  }
  ```

- [ ] **Step 2: Build — no compile errors**

  ⌘B.

- [ ] **Step 3: Commit**

  ```bash
  git add HouseMate/Resources/BuiltInTemplates.swift
  git commit -m "feat: add built-in task and maintenance templates (bundled locally)"
  ```

---

### Task 13: App Startup + CloudKit Initialization

**Files:**
- Modify: `HouseMate/HouseMateApp.swift`

- [ ] **Step 1: Update HouseMateApp.swift to initialize CloudKit on launch**

  ```swift
  import SwiftUI

  @main
  struct HouseMateApp: App {
      var body: some Scene {
          WindowGroup {
              ContentView()
                  .task {
                      await initializeCloudKit()
                  }
          }
      }

      private func initializeCloudKit() async {
          do {
              let ck = CloudKitService.shared
              try await ck.checkAccountStatus()
              // Cache the current user's record name — required for owner-vs-participant
              // database routing throughout all service calls.
              try await ck.fetchAndCacheCurrentUserRecordName()
              // Create the shared zone if this is a first launch (gated by UserDefaults flag).
              // Non-owners: this is a no-op because the flag won't be set on their device.
              try await ck.createSharedZoneIfNeeded()
          } catch {
              // iCloud unavailable or account error — handled in onboarding flow (next plan)
              print("[HouseMate] CloudKit init: \(error.localizedDescription)")
          }
      }
  }
  ```

- [ ] **Step 2: Build and run on simulator**

  ⌘R. App launches, 4 tabs visible. Console shows CloudKit init log (expected: error about iCloud not being available in the Simulator — this is normal; sign into iCloud in the simulator or use a device).

- [ ] **Step 3: Run all tests**

  ⌘U. All unit tests pass.

- [ ] **Step 4: Final commit**

  ```bash
  git add HouseMate/HouseMateApp.swift
  git commit -m "feat: wire CloudKit initialization into app startup"
  ```

---

## Foundation Complete

**Deliverables:**
- Xcode project with CloudKit + Push Notifications + Background Modes entitlements
- All data models with unit-tested business logic (rotation algorithm, due date status, recurring task advancement)
- CKRecord ↔ model roundtrip mapping for all types — unit tested
- CloudKit service layer: `CloudKitService` base + 4 domain services
- Navigation skeleton: 4 tabs with placeholder views
- Built-in templates bundled locally

**Test coverage summary:**
- `BinScheduleTests` — 10 tests covering rotation calc, next pickup, upcoming list, days-until
- `MaintenanceItemTests` — 8 tests covering due date calculation, all three status thresholds, isDueSoon
- `TaskTests` — 9 tests covering recurring advancement (daily/weekly/monthly), nil dueDate, overdue logic, isDueToday
- `CKRecordMappingTests` — 8 tests covering roundtrip for all key record types

**Next plans (execute in order):**
1. `2026-03-12-housemate-onboarding.md` — iCloud check, create/join household, share link, error states
2. `2026-03-12-housemate-tasks.md` — Tasks tab: list, detail, add/edit, templates, swipe actions
3. `2026-03-12-housemate-bins.md` — Bins tab: rotation display, upcoming list, schedule config
4. `2026-03-12-housemate-maintenance.md` — Maintenance tab: grouped list, detail, log completion, templates
5. `2026-03-12-housemate-home.md` — Dashboard, Settings, local + push notifications
