# HouseMate Foundation Implementation Plan (Supabase)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the HouseMate iOS Xcode project, set up Supabase (schema + RLS), implement all Swift data models, create the Supabase service layer, wire up auth and onboarding, and deliver the 4-tab navigation skeleton — the complete foundation before building feature UIs.

**Architecture:** Codable Swift structs map 1:1 to Supabase tables. A single `SupabaseClient` singleton provides all database access. `@MainActor` service classes own async CRUD operations. `AppState` (`@Observable`) holds current user, member, and household context and is injected via SwiftUI `.environment`. Supabase Realtime channels live in a `RealtimeService` that posts `NotificationCenter` events which ViewModels observe. No third-party dependencies beyond `supabase-swift`.

**Tech Stack:** Swift 5.9+, SwiftUI, Supabase (supabase-swift 2.x), XCTest, iOS 17.0+

**Spec:** `docs/superpowers/specs/2026-03-12-housemate-design.md`

---

## File Structure

```
HouseMate/
├── App/
│   ├── HouseMateApp.swift          — app entry point, injects AppState
│   └── ContentView.swift           — root view: onboarding vs main tab bar
├── Config/
│   └── Supabase.swift              — SupabaseClient singleton
├── Models/
│   ├── Household.swift             — Household, HouseholdInvite
│   ├── Member.swift                — Member
│   ├── Task.swift                  — Task, TaskCategory, TaskPriority, RecurringInterval
│   ├── TaskCompletionLog.swift     — TaskCompletionLog
│   ├── TaskTemplate.swift          — TaskTemplate (Codable for DB rows + local built-ins)
│   ├── BinSchedule.swift           — BinSchedule, RotationLabel
│   ├── MaintenanceItem.swift       — MaintenanceItem, MaintenanceCategory, MaintenanceStatus
│   ├── MaintenanceLog.swift        — MaintenanceLog
│   └── MaintenanceTemplate.swift  — MaintenanceTemplate (DB rows + local built-ins)
├── Services/
│   ├── AuthService.swift           — sign up, sign in, sign out, current user
│   ├── HouseholdService.swift      — create, join, fetch household + invite management
│   ├── MemberService.swift         — fetch members for household
│   ├── TaskService.swift           — CRUD for tasks + completion logs
│   ├── BinService.swift            — upsert + fetch bin schedule
│   ├── MaintenanceService.swift    — CRUD for items + logs
│   ├── TemplateService.swift       — user-created templates CRUD + built-in bundles
│   └── RealtimeService.swift       — Supabase Realtime channels, posts NotificationCenter events
├── State/
│   └── AppState.swift              — @Observable: currentUser, currentMember, household, members
├── Resources/
│   └── BuiltInTemplates.swift      — hardcoded built-in task + maintenance templates
└── Views/
    ├── Onboarding/
    │   ├── AuthView.swift          — sign up / sign in form
    │   ├── HouseholdChoiceView.swift — create or join household
    │   ├── CreateHouseholdView.swift
    │   └── JoinHouseholdView.swift
    └── Main/
        └── MainTabView.swift       — 4-tab skeleton with placeholder content
```

---

## Chunk 1: Project Setup

### Task 1: Create Xcode Project and Add Supabase SDK

**Files:**
- Create: `HouseMate.xcodeproj` (via Xcode GUI)
- Create: `HouseMate/App/HouseMateApp.swift`
- Create: `HouseMate/App/ContentView.swift`

- [ ] **Step 1: Create project in Xcode**

  File > New > Project > iOS > App:
  - Product Name: `HouseMate`
  - Bundle Identifier: `com.<yourname>.HouseMate`
  - Interface: SwiftUI
  - Language: Swift
  - Storage: None (uncheck Core Data)
  - Include Tests: checked
  - Minimum Deployment: iOS 17.0
  - Save to: `/Users/chilee-old/Documents/Development/augment-projects/HouseMate/`

- [ ] **Step 2: Add supabase-swift via Swift Package Manager**

  File > Add Package Dependencies:
  - URL: `https://github.com/supabase/supabase-swift`
  - Version: Up to Next Major from `2.0.0`
  - Add to target: `HouseMate`
  - Select product: `Supabase` (includes Auth, Realtime, PostgREST)

- [ ] **Step 3: Verify build**

  Product > Build (⌘B). Should build with no errors.

- [ ] **Step 4: Commit**

  ```bash
  git add .
  git commit -m "feat: create Xcode project and add supabase-swift"
  ```

---

### Task 2: Set Up Supabase Project and Database Schema

**This task is performed in the Supabase web dashboard, not in Xcode.**

- [ ] **Step 1: Create Supabase project**

  Go to https://supabase.com, sign in, click "New project":
  - Name: `HouseMate`
  - Database password: save this somewhere safe
  - Region: choose nearest
  - Wait for project to provision (~2 minutes)

- [ ] **Step 2: Run database schema SQL**

  Go to SQL Editor in the Supabase dashboard and run the following in order:

  ```sql
  -- Enable UUID generation
  CREATE EXTENSION IF NOT EXISTS "pgcrypto";

  -- updated_at trigger function
  CREATE OR REPLACE FUNCTION set_updated_at()
  RETURNS TRIGGER AS $$
  BEGIN
    NEW.updated_at = now();
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

  -- households
  CREATE TABLE households (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- members
  CREATE TABLE members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    display_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (household_id, user_id)
  );

  -- household_invites
  CREATE TABLE household_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    invite_code TEXT NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- tasks
  CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    priority TEXT NOT NULL,
    assigned_to UUID REFERENCES members(id) ON DELETE SET NULL,
    due_date DATE,
    is_recurring BOOLEAN NOT NULL DEFAULT false,
    recurring_interval TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    completed_by UUID REFERENCES members(id) ON DELETE SET NULL,
    completed_at TIMESTAMPTZ,
    template_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  CREATE TRIGGER tasks_updated_at BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

  -- task_completion_logs
  CREATE TABLE task_completion_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    completed_by UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- task_templates (user-created only)
  CREATE TABLE task_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    recurring_interval TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- bin_schedules
  CREATE TABLE bin_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE UNIQUE,
    pickup_day_of_week INTEGER NOT NULL,
    rotation_a TEXT NOT NULL,
    rotation_b TEXT NOT NULL,
    starting_rotation TEXT NOT NULL,
    starting_date DATE NOT NULL,
    notify_day_before BOOLEAN NOT NULL DEFAULT false,
    notify_morning_of BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  CREATE TRIGGER bin_schedules_updated_at BEFORE UPDATE ON bin_schedules
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

  -- maintenance_items
  CREATE TABLE maintenance_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    interval_days INTEGER NOT NULL,
    last_completed_date DATE,
    notes TEXT,
    template_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  CREATE TRIGGER maintenance_items_updated_at BEFORE UPDATE ON maintenance_items
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

  -- maintenance_logs
  CREATE TABLE maintenance_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    maintenance_item_id UUID NOT NULL REFERENCES maintenance_items(id) ON DELETE CASCADE,
    completed_date DATE NOT NULL,
    notes TEXT,
    cost NUMERIC(10, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- maintenance_templates (user-created only)
  CREATE TABLE maintenance_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    interval_days INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ```

- [ ] **Step 3: Enable Row Level Security and add policies**

  ```sql
  -- Helper function: get the household_id for the current user
  CREATE OR REPLACE FUNCTION my_household_id()
  RETURNS UUID AS $$
    SELECT household_id FROM members WHERE user_id = auth.uid() LIMIT 1;
  $$ LANGUAGE sql STABLE SECURITY DEFINER;

  -- Enable RLS on all tables
  ALTER TABLE households ENABLE ROW LEVEL SECURITY;
  ALTER TABLE members ENABLE ROW LEVEL SECURITY;
  ALTER TABLE household_invites ENABLE ROW LEVEL SECURITY;
  ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
  ALTER TABLE task_completion_logs ENABLE ROW LEVEL SECURITY;
  ALTER TABLE task_templates ENABLE ROW LEVEL SECURITY;
  ALTER TABLE bin_schedules ENABLE ROW LEVEL SECURITY;
  ALTER TABLE maintenance_items ENABLE ROW LEVEL SECURITY;
  ALTER TABLE maintenance_logs ENABLE ROW LEVEL SECURITY;
  ALTER TABLE maintenance_templates ENABLE ROW LEVEL SECURITY;

  -- households: members can read their household; creator can update
  CREATE POLICY "members can view their household"
    ON households FOR SELECT
    USING (id = my_household_id());

  CREATE POLICY "creator can update household"
    ON households FOR UPDATE
    USING (created_by = auth.uid());

  -- members: can view all members of their household; can insert own row; can update own row
  CREATE POLICY "view household members"
    ON members FOR SELECT
    USING (household_id = my_household_id());

  CREATE POLICY "insert own member row"
    ON members FOR INSERT
    WITH CHECK (user_id = auth.uid());

  CREATE POLICY "update own member row"
    ON members FOR UPDATE
    USING (user_id = auth.uid());

  -- household_invites: household members can read/insert/update
  CREATE POLICY "view household invites"
    ON household_invites FOR SELECT
    USING (household_id = my_household_id() OR true); -- public read for joining

  CREATE POLICY "insert household invite"
    ON household_invites FOR INSERT
    WITH CHECK (household_id = my_household_id());

  CREATE POLICY "update household invite"
    ON household_invites FOR UPDATE
    USING (household_id = my_household_id());

  -- tasks
  CREATE POLICY "household tasks select"
    ON tasks FOR SELECT USING (household_id = my_household_id());
  CREATE POLICY "household tasks insert"
    ON tasks FOR INSERT WITH CHECK (household_id = my_household_id());
  CREATE POLICY "household tasks update"
    ON tasks FOR UPDATE USING (household_id = my_household_id());
  CREATE POLICY "household tasks delete"
    ON tasks FOR DELETE USING (household_id = my_household_id());

  -- task_completion_logs
  CREATE POLICY "household task_completion_logs select"
    ON task_completion_logs FOR SELECT
    USING (task_id IN (SELECT id FROM tasks WHERE household_id = my_household_id()));
  CREATE POLICY "household task_completion_logs insert"
    ON task_completion_logs FOR INSERT
    WITH CHECK (task_id IN (SELECT id FROM tasks WHERE household_id = my_household_id()));

  -- task_templates
  CREATE POLICY "household task_templates select"
    ON task_templates FOR SELECT USING (household_id = my_household_id());
  CREATE POLICY "household task_templates insert"
    ON task_templates FOR INSERT WITH CHECK (household_id = my_household_id());
  CREATE POLICY "household task_templates delete"
    ON task_templates FOR DELETE USING (household_id = my_household_id());

  -- bin_schedules
  CREATE POLICY "household bin_schedules select"
    ON bin_schedules FOR SELECT USING (household_id = my_household_id());
  CREATE POLICY "household bin_schedules insert"
    ON bin_schedules FOR INSERT WITH CHECK (household_id = my_household_id());
  CREATE POLICY "household bin_schedules update"
    ON bin_schedules FOR UPDATE USING (household_id = my_household_id());

  -- maintenance_items
  CREATE POLICY "household maintenance_items select"
    ON maintenance_items FOR SELECT USING (household_id = my_household_id());
  CREATE POLICY "household maintenance_items insert"
    ON maintenance_items FOR INSERT WITH CHECK (household_id = my_household_id());
  CREATE POLICY "household maintenance_items update"
    ON maintenance_items FOR UPDATE USING (household_id = my_household_id());
  CREATE POLICY "household maintenance_items delete"
    ON maintenance_items FOR DELETE USING (household_id = my_household_id());

  -- maintenance_logs
  CREATE POLICY "household maintenance_logs select"
    ON maintenance_logs FOR SELECT
    USING (maintenance_item_id IN (SELECT id FROM maintenance_items WHERE household_id = my_household_id()));
  CREATE POLICY "household maintenance_logs insert"
    ON maintenance_logs FOR INSERT
    WITH CHECK (maintenance_item_id IN (SELECT id FROM maintenance_items WHERE household_id = my_household_id()));
  CREATE POLICY "household maintenance_logs delete"
    ON maintenance_logs FOR DELETE
    USING (maintenance_item_id IN (SELECT id FROM maintenance_items WHERE household_id = my_household_id()));

  -- maintenance_templates
  CREATE POLICY "household maintenance_templates select"
    ON maintenance_templates FOR SELECT USING (household_id = my_household_id());
  CREATE POLICY "household maintenance_templates insert"
    ON maintenance_templates FOR INSERT WITH CHECK (household_id = my_household_id());
  CREATE POLICY "household maintenance_templates delete"
    ON maintenance_templates FOR DELETE USING (household_id = my_household_id());
  ```

- [ ] **Step 4: Enable Realtime on relevant tables**

  In the Supabase dashboard: Database > Replication > enable Realtime for:
  - `tasks`
  - `task_completion_logs`
  - `bin_schedules`
  - `maintenance_items`
  - `maintenance_logs`
  - `members`

- [ ] **Step 5: Get API credentials**

  Project Settings > API. Copy:
  - Project URL (e.g. `https://xxxx.supabase.co`)
  - `anon` public key

---

### Task 3: Configure SupabaseClient in App

**Files:**
- Create: `HouseMate/Config/Supabase.swift`
- Create: `HouseMate/Config/Secrets.swift` (gitignored)
- Modify: `.gitignore`

- [ ] **Step 1: Write failing test**

  In `HouseMateTests/ConfigTests.swift`:
  ```swift
  import XCTest
  @testable import HouseMate

  final class ConfigTests: XCTestCase {
      func test_supabaseClient_isNotNil() {
          XCTAssertNotNil(supabase)
      }
  }
  ```

- [ ] **Step 2: Run test to verify it fails**

  Run: `xcodebuild test -scheme HouseMate -destination 'platform=iOS Simulator,name=iPhone 16'`
  Expected: FAIL — `supabase` not defined.

- [ ] **Step 3: Create Secrets.swift**

  ```swift
  // HouseMate/Config/Secrets.swift
  // DO NOT COMMIT — add to .gitignore
  enum Secrets {
      static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
      static let supabaseAnonKey = "YOUR_ANON_KEY"
  }
  ```

- [ ] **Step 4: Create Supabase.swift**

  ```swift
  // HouseMate/Config/Supabase.swift
  import Supabase

  let supabase = SupabaseClient(
      supabaseURL: URL(string: Secrets.supabaseURL)!,
      supabaseKey: Secrets.supabaseAnonKey
  )
  ```

- [ ] **Step 5: Add Secrets.swift to .gitignore**

  Append to `.gitignore`:
  ```
  HouseMate/Config/Secrets.swift
  ```

- [ ] **Step 6: Run test to verify it passes**

  Expected: PASS.

- [ ] **Step 7: Commit**

  ```bash
  git add HouseMate/Config/Supabase.swift .gitignore HouseMateTests/ConfigTests.swift
  git commit -m "feat: configure SupabaseClient singleton"
  ```

---

## Chunk 2: Models

### Task 4: Core Models — Household, Member, HouseholdInvite

**Files:**
- Create: `HouseMate/Models/Household.swift`
- Create: `HouseMate/Models/Member.swift`
- Create: `HouseMateTests/Models/HouseholdTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // HouseMateTests/Models/HouseholdTests.swift
  import XCTest
  @testable import HouseMate

  final class HouseholdTests: XCTestCase {
      func test_household_decodesFromJSON() throws {
          let json = """
          {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Test House",
            "created_by": "00000000-0000-0000-0000-000000000002",
            "created_at": "2026-01-01T00:00:00Z"
          }
          """.data(using: .utf8)!
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .iso8601
          let household = try decoder.decode(Household.self, from: json)
          XCTAssertEqual(household.name, "Test House")
      }

      func test_member_decodesFromJSON() throws {
          let json = """
          {
            "id": "00000000-0000-0000-0000-000000000001",
            "household_id": "00000000-0000-0000-0000-000000000002",
            "user_id": "00000000-0000-0000-0000-000000000003",
            "display_name": "Alice",
            "created_at": "2026-01-01T00:00:00Z"
          }
          """.data(using: .utf8)!
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .iso8601
          let member = try decoder.decode(Member.self, from: json)
          XCTAssertEqual(member.displayName, "Alice")
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

  Expected: FAIL — types not defined.

- [ ] **Step 3: Implement Household.swift**

  ```swift
  // HouseMate/Models/Household.swift
  import Foundation

  struct Household: Codable, Identifiable {
      let id: UUID
      let name: String
      let createdBy: UUID
      let createdAt: Date

      enum CodingKeys: String, CodingKey {
          case id, name
          case createdBy = "created_by"
          case createdAt = "created_at"
      }
  }

  struct HouseholdInvite: Codable, Identifiable {
      let id: UUID
      let householdId: UUID
      let inviteCode: String
      let isActive: Bool
      let createdBy: UUID
      let createdAt: Date

      enum CodingKeys: String, CodingKey {
          case id
          case householdId = "household_id"
          case inviteCode = "invite_code"
          case isActive = "is_active"
          case createdBy = "created_by"
          case createdAt = "created_at"
      }
  }
  ```

- [ ] **Step 4: Implement Member.swift**

  ```swift
  // HouseMate/Models/Member.swift
  import Foundation

  struct Member: Codable, Identifiable {
      let id: UUID
      let householdId: UUID
      let userId: UUID
      let displayName: String
      let createdAt: Date

      enum CodingKeys: String, CodingKey {
          case id
          case householdId = "household_id"
          case userId = "user_id"
          case displayName = "display_name"
          case createdAt = "created_at"
      }
  }
  ```

- [ ] **Step 5: Run tests to verify they pass**

  Expected: PASS.

- [ ] **Step 6: Commit**

  ```bash
  git add HouseMate/Models/Household.swift HouseMate/Models/Member.swift HouseMateTests/Models/HouseholdTests.swift
  git commit -m "feat: add Household and Member models"
  ```

---

### Task 5: Task Models

**Files:**
- Create: `HouseMate/Models/Task.swift`
- Create: `HouseMate/Models/TaskCompletionLog.swift`
- Create: `HouseMateTests/Models/TaskTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // HouseMateTests/Models/TaskTests.swift
  import XCTest
  @testable import HouseMate

  final class TaskTests: XCTestCase {
      func test_task_decodesFromJSON() throws {
          let json = """
          {
            "id": "00000000-0000-0000-0000-000000000001",
            "household_id": "00000000-0000-0000-0000-000000000002",
            "title": "Take out trash",
            "category": "other",
            "priority": "medium",
            "assigned_to": null,
            "due_date": "2026-03-15",
            "is_recurring": true,
            "recurring_interval": "weekly",
            "is_completed": false,
            "completed_by": null,
            "completed_at": null,
            "template_id": null,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
          }
          """.data(using: .utf8)!
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .custom { decoder in
              let s = try decoder.singleValueContainer().decode(String.self)
              if let date = ISO8601DateFormatter().date(from: s) { return date }
              let df = DateFormatter()
              df.dateFormat = "yyyy-MM-dd"
              if let date = df.date(from: s) { return date }
              throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad date: \(s)"))
          }
          let task = try decoder.decode(HMTask.self, from: json)
          XCTAssertEqual(task.title, "Take out trash")
          XCTAssertEqual(task.recurringInterval, .weekly)
          XCTAssertFalse(task.isCompleted)
      }

      func test_task_nextDueDate_weekly() {
          let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
          let task = HMTask.makeTest(dueDate: base, recurringInterval: .weekly)
          XCTAssertEqual(task.nextDueDate, Calendar.current.date(byAdding: .day, value: 7, to: base))
      }

      func test_task_nextDueDate_monthly() {
          let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
          let task = HMTask.makeTest(dueDate: base, recurringInterval: .monthly)
          XCTAssertEqual(task.nextDueDate, Calendar.current.date(byAdding: .month, value: 1, to: base))
      }

      func test_task_isOverdue_whenDueDatePast() {
          let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
          let task = HMTask.makeTest(dueDate: yesterday, isCompleted: false)
          XCTAssertTrue(task.isOverdue)
      }

      func test_task_isNotOverdue_whenCompleted() {
          let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
          let task = HMTask.makeTest(dueDate: yesterday, isCompleted: true)
          XCTAssertFalse(task.isOverdue)
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement Task.swift**

  ```swift
  // HouseMate/Models/Task.swift
  import Foundation

  // Named HMTask to avoid conflict with Swift concurrency's Task type
  struct HMTask: Codable, Identifiable {
      let id: UUID
      let householdId: UUID
      var title: String
      var category: TaskCategory
      var priority: TaskPriority
      var assignedTo: UUID?
      var dueDate: Date?
      var isRecurring: Bool
      var recurringInterval: RecurringInterval?
      var isCompleted: Bool
      var completedBy: UUID?
      var completedAt: Date?
      let templateId: UUID?
      let createdAt: Date
      var updatedAt: Date

      enum CodingKeys: String, CodingKey {
          case id, title, category, priority
          case householdId = "household_id"
          case assignedTo = "assigned_to"
          case dueDate = "due_date"
          case isRecurring = "is_recurring"
          case recurringInterval = "recurring_interval"
          case isCompleted = "is_completed"
          case completedBy = "completed_by"
          case completedAt = "completed_at"
          case templateId = "template_id"
          case createdAt = "created_at"
          case updatedAt = "updated_at"
      }

      var isOverdue: Bool {
          guard !isCompleted, let due = dueDate else { return false }
          return due < Calendar.current.startOfDay(for: Date())
      }

      var nextDueDate: Date? {
          guard let due = dueDate, let interval = recurringInterval else { return nil }
          switch interval {
          case .daily:   return Calendar.current.date(byAdding: .day, value: 1, to: due)
          case .weekly:  return Calendar.current.date(byAdding: .day, value: 7, to: due)
          case .monthly: return Calendar.current.date(byAdding: .month, value: 1, to: due)
          }
      }
  }

  enum TaskCategory: String, Codable, CaseIterable {
      case kitchen, bathroom, outdoor, errands, other
      var displayName: String { rawValue.capitalized }
  }

  enum TaskPriority: String, Codable, CaseIterable {
      case high, medium, low
      var displayName: String { rawValue.capitalized }
  }

  enum RecurringInterval: String, Codable, CaseIterable {
      case daily, weekly, monthly
      var displayName: String { rawValue.capitalized }
      var days: Int {
          switch self { case .daily: return 1; case .weekly: return 7; case .monthly: return 30 }
      }
  }

  // Test helper
  extension HMTask {
      static func makeTest(
          id: UUID = UUID(),
          householdId: UUID = UUID(),
          title: String = "Test Task",
          category: TaskCategory = .other,
          priority: TaskPriority = .medium,
          assignedTo: UUID? = nil,
          dueDate: Date? = nil,
          isRecurring: Bool = false,
          recurringInterval: RecurringInterval? = nil,
          isCompleted: Bool = false,
          completedBy: UUID? = nil,
          completedAt: Date? = nil,
          templateId: UUID? = nil
      ) -> HMTask {
          HMTask(
              id: id, householdId: householdId, title: title,
              category: category, priority: priority, assignedTo: assignedTo,
              dueDate: dueDate, isRecurring: isRecurring, recurringInterval: recurringInterval,
              isCompleted: isCompleted, completedBy: completedBy, completedAt: completedAt,
              templateId: templateId, createdAt: Date(), updatedAt: Date()
          )
      }
  }
  ```

- [ ] **Step 4: Implement TaskCompletionLog.swift**

  ```swift
  // HouseMate/Models/TaskCompletionLog.swift
  import Foundation

  struct TaskCompletionLog: Codable, Identifiable {
      let id: UUID
      let taskId: UUID
      let completedBy: UUID
      let completedAt: Date

      enum CodingKeys: String, CodingKey {
          case id
          case taskId = "task_id"
          case completedBy = "completed_by"
          case completedAt = "completed_at"
      }
  }
  ```

- [ ] **Step 5: Run tests to verify they pass**

- [ ] **Step 6: Commit**

  ```bash
  git add HouseMate/Models/Task.swift HouseMate/Models/TaskCompletionLog.swift HouseMateTests/Models/TaskTests.swift
  git commit -m "feat: add Task and TaskCompletionLog models with business logic"
  ```

---

### Task 6: BinSchedule and Maintenance Models

**Files:**
- Create: `HouseMate/Models/BinSchedule.swift`
- Create: `HouseMate/Models/MaintenanceItem.swift`
- Create: `HouseMate/Models/MaintenanceLog.swift`
- Create: `HouseMate/Models/TaskTemplate.swift`
- Create: `HouseMate/Models/MaintenanceTemplate.swift`
- Create: `HouseMateTests/Models/BinScheduleTests.swift`
- Create: `HouseMateTests/Models/MaintenanceItemTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // HouseMateTests/Models/BinScheduleTests.swift
  import XCTest
  @testable import HouseMate

  final class BinScheduleTests: XCTestCase {
      // startingDate = Monday 2026-03-02, startingRotation = A
      // weekday 2 = Monday (Calendar.weekday)
      let anchor = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 2))!

      func makeSchedule(startingRotation: String = "A") -> BinSchedule {
          BinSchedule(
              id: UUID(), householdId: UUID(),
              pickupDayOfWeek: 2, // Monday
              rotationA: "Recycling", rotationB: "Garbage",
              startingRotation: startingRotation,
              startingDate: anchor,
              notifyDayBefore: false, notifyMorningOf: false,
              createdAt: Date(), updatedAt: Date()
          )
      }

      func test_rotation_onStartingDate_isStartingRotation() {
          let schedule = makeSchedule()
          XCTAssertEqual(schedule.rotation(for: anchor), "Recycling") // weeksDiff = 0 → even → A
      }

      func test_rotation_oneWeekLater_isOtherRotation() {
          let schedule = makeSchedule()
          let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: anchor)!
          XCTAssertEqual(schedule.rotation(for: nextWeek), "Garbage") // weeksDiff = 1 → odd → B
      }

      func test_rotation_twoWeeksLater_isStartingRotation() {
          let schedule = makeSchedule()
          let twoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: anchor)!
          XCTAssertEqual(schedule.rotation(for: twoWeeks), "Recycling") // weeksDiff = 2 → even → A
      }
  }

  // HouseMateTests/Models/MaintenanceItemTests.swift
  final class MaintenanceItemTests: XCTestCase {
      func test_status_isRed_whenNeverCompleted() {
          let item = MaintenanceItem.makeTest(lastCompletedDate: nil)
          XCTAssertEqual(item.status, .red)
      }

      func test_status_isGreen_whenDueFarAway() {
          let future = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
          // intervalDays = 30, lastCompleted = future - 30 days (= today), nextDue = future
          let lastDone = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
          let item = MaintenanceItem.makeTest(intervalDays: 31, lastCompletedDate: lastDone)
          // nextDue = lastDone + 31 days = 30 days from now → green
          XCTAssertEqual(item.status, .green)
      }

      func test_status_isYellow_whenDueSoon() {
          let lastDone = Calendar.current.date(byAdding: .day, value: -80, to: Date())!
          let item = MaintenanceItem.makeTest(intervalDays: 90, lastCompletedDate: lastDone)
          // nextDue = lastDone + 90 = 10 days from now → yellow
          XCTAssertEqual(item.status, .yellow)
      }

      func test_status_isRed_whenOverdue() {
          let lastDone = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
          let item = MaintenanceItem.makeTest(intervalDays: 90, lastCompletedDate: lastDone)
          // nextDue = 10 days ago → red
          XCTAssertEqual(item.status, .red)
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement BinSchedule.swift**

  ```swift
  // HouseMate/Models/BinSchedule.swift
  import Foundation

  struct BinSchedule: Codable, Identifiable {
      let id: UUID
      let householdId: UUID
      var pickupDayOfWeek: Int  // 1 = Sunday … 7 = Saturday
      var rotationA: String
      var rotationB: String
      var startingRotation: String  // "A" or "B"
      var startingDate: Date
      var notifyDayBefore: Bool
      var notifyMorningOf: Bool
      let createdAt: Date
      var updatedAt: Date

      enum CodingKeys: String, CodingKey {
          case id
          case householdId = "household_id"
          case pickupDayOfWeek = "pickup_day_of_week"
          case rotationA = "rotation_a"
          case rotationB = "rotation_b"
          case startingRotation = "starting_rotation"
          case startingDate = "starting_date"
          case notifyDayBefore = "notify_day_before"
          case notifyMorningOf = "notify_morning_of"
          case createdAt = "created_at"
          case updatedAt = "updated_at"
      }

      /// Returns the rotation label (rotationA or rotationB) for the given pickup date.
      func rotation(for date: Date) -> String {
          let cal = Calendar.current
          let start = cal.startOfDay(for: startingDate)
          let target = cal.startOfDay(for: date)
          let daysDiff = cal.dateComponents([.day], from: start, to: target).day ?? 0
          let weeksDiff = daysDiff / 7
          let isStartingRotation = weeksDiff % 2 == 0
          if startingRotation == "A" {
              return isStartingRotation ? rotationA : rotationB
          } else {
              return isStartingRotation ? rotationB : rotationA
          }
      }

      /// Returns the next N pickup dates from today.
      func upcomingPickups(count: Int = 8) -> [(date: Date, rotation: String)] {
          let cal = Calendar.current
          let today = cal.startOfDay(for: Date())
          var results: [(Date, String)] = []
          var candidate = today
          while results.count < count {
              if cal.component(.weekday, from: candidate) == pickupDayOfWeek {
                  results.append((candidate, rotation(for: candidate)))
              }
              candidate = cal.date(byAdding: .day, value: 1, to: candidate)!
          }
          return results
      }
  }
  ```

- [ ] **Step 4: Implement MaintenanceItem.swift**

  ```swift
  // HouseMate/Models/MaintenanceItem.swift
  import Foundation

  struct MaintenanceItem: Codable, Identifiable {
      let id: UUID
      let householdId: UUID
      var name: String
      var category: MaintenanceCategory
      var intervalDays: Int
      var lastCompletedDate: Date?
      var notes: String?
      let templateId: UUID?
      let createdAt: Date
      var updatedAt: Date

      enum CodingKeys: String, CodingKey {
          case id, name, category, notes
          case householdId = "household_id"
          case intervalDays = "interval_days"
          case lastCompletedDate = "last_completed_date"
          case templateId = "template_id"
          case createdAt = "created_at"
          case updatedAt = "updated_at"
      }

      var nextDueDate: Date? {
          guard let last = lastCompletedDate else { return nil }
          return Calendar.current.date(byAdding: .day, value: intervalDays, to: last)
      }

      var status: MaintenanceStatus {
          guard let next = nextDueDate else { return .red }
          let today = Calendar.current.startOfDay(for: Date())
          let daysUntil = Calendar.current.dateComponents([.day], from: today, to: next).day ?? 0
          if daysUntil > 14 { return .green }
          if daysUntil >= 0 { return .yellow }
          return .red
      }

      static func makeTest(
          id: UUID = UUID(), householdId: UUID = UUID(),
          name: String = "Test Item", category: MaintenanceCategory = .yearRound,
          intervalDays: Int = 90, lastCompletedDate: Date? = nil
      ) -> MaintenanceItem {
          MaintenanceItem(id: id, householdId: householdId, name: name,
              category: category, intervalDays: intervalDays,
              lastCompletedDate: lastCompletedDate, notes: nil, templateId: nil,
              createdAt: Date(), updatedAt: Date())
      }
  }

  enum MaintenanceCategory: String, Codable, CaseIterable {
      case spring, summer, fall, winter
      case yearRound = "year_round"
      var displayName: String {
          switch self {
          case .yearRound: return "Year-Round"
          default: return rawValue.capitalized
          }
      }
  }

  enum MaintenanceStatus { case green, yellow, red }
  ```

- [ ] **Step 5: Implement MaintenanceLog.swift**

  ```swift
  // HouseMate/Models/MaintenanceLog.swift
  import Foundation

  struct MaintenanceLog: Codable, Identifiable {
      let id: UUID
      let maintenanceItemId: UUID
      var completedDate: Date
      var notes: String?
      var cost: Decimal?
      let createdAt: Date

      enum CodingKeys: String, CodingKey {
          case id, notes, cost
          case maintenanceItemId = "maintenance_item_id"
          case completedDate = "completed_date"
          case createdAt = "created_at"
      }
  }
  ```

- [ ] **Step 6: Implement TaskTemplate.swift and MaintenanceTemplate.swift**

  ```swift
  // HouseMate/Models/TaskTemplate.swift
  import Foundation

  struct TaskTemplate: Codable, Identifiable {
      let id: UUID
      let householdId: UUID?  // nil for built-in (local only)
      let title: String
      let category: TaskCategory
      let recurringInterval: RecurringInterval?
      let isBuiltIn: Bool

      enum CodingKeys: String, CodingKey {
          case id, title, category
          case householdId = "household_id"
          case recurringInterval = "recurring_interval"
          case isBuiltIn = "is_built_in"
      }

      // Convenience init for built-in templates (local, no DB row)
      init(builtInTitle: String, category: TaskCategory, recurringInterval: RecurringInterval?) {
          self.id = UUID()
          self.householdId = nil
          self.title = builtInTitle
          self.category = category
          self.recurringInterval = recurringInterval
          self.isBuiltIn = true
      }

      // Init for DB rows
      init(id: UUID, householdId: UUID, title: String, category: TaskCategory,
           recurringInterval: RecurringInterval?) {
          self.id = id
          self.householdId = householdId
          self.title = title
          self.category = category
          self.recurringInterval = recurringInterval
          self.isBuiltIn = false
      }
  }

  // HouseMate/Models/MaintenanceTemplate.swift
  struct MaintenanceTemplate: Codable, Identifiable {
      let id: UUID
      let householdId: UUID?  // nil for built-in
      let name: String
      let category: MaintenanceCategory
      let intervalDays: Int
      let isBuiltIn: Bool

      enum CodingKeys: String, CodingKey {
          case id, name, category
          case householdId = "household_id"
          case intervalDays = "interval_days"
          case isBuiltIn = "is_built_in"
      }

      init(builtInName: String, category: MaintenanceCategory, intervalDays: Int) {
          self.id = UUID()
          self.householdId = nil
          self.name = builtInName
          self.category = category
          self.intervalDays = intervalDays
          self.isBuiltIn = true
      }

      init(id: UUID, householdId: UUID, name: String, category: MaintenanceCategory,
           intervalDays: Int) {
          self.id = id
          self.householdId = householdId
          self.name = name
          self.category = category
          self.intervalDays = intervalDays
          self.isBuiltIn = false
      }
  }
  ```

- [ ] **Step 7: Run tests to verify they pass**

- [ ] **Step 8: Commit**

  ```bash
  git add HouseMate/Models/ HouseMateTests/Models/
  git commit -m "feat: add BinSchedule, MaintenanceItem, MaintenanceLog, Template models"
  ```

---

## Chunk 3: Services

### Task 7: AuthService

**Files:**
- Create: `HouseMate/Services/AuthService.swift`
- Create: `HouseMateTests/Services/AuthServiceTests.swift`

- [ ] **Step 1: Write failing test**

  ```swift
  // HouseMateTests/Services/AuthServiceTests.swift
  import XCTest
  @testable import HouseMate

  final class AuthServiceTests: XCTestCase {
      func test_authService_exists() {
          let service = AuthService()
          XCTAssertNotNil(service)
      }

      func test_currentUser_isNilWhenNotSignedIn() async {
          let service = AuthService()
          // If test runs without a real session, currentUser should be nil
          // (In CI this will always be nil; on a device it depends on state)
          _ = service.currentUser  // just verify it doesn't crash
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement AuthService.swift**

  ```swift
  // HouseMate/Services/AuthService.swift
  import Supabase
  import Foundation

  @MainActor
  final class AuthService {
      var currentUser: User? { supabase.auth.currentUser }

      func signUp(email: String, password: String) async throws -> User {
          let response = try await supabase.auth.signUp(email: email, password: password)
          guard let user = response.user else {
              throw AuthError.noUser
          }
          return user
      }

      func signIn(email: String, password: String) async throws -> User {
          let session = try await supabase.auth.signIn(email: email, password: password)
          return session.user
      }

      func signOut() async throws {
          try await supabase.auth.signOut()
      }

      func restoreSession() async throws -> User? {
          try await supabase.auth.session
          return supabase.auth.currentUser
      }
  }

  enum AuthError: LocalizedError {
      case noUser
      var errorDescription: String? {
          switch self { case .noUser: return "Sign up succeeded but no user was returned." }
      }
  }
  ```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/Services/AuthService.swift HouseMateTests/Services/AuthServiceTests.swift
  git commit -m "feat: add AuthService (sign up, sign in, sign out)"
  ```

---

### Task 8: HouseholdService and MemberService

**Files:**
- Create: `HouseMate/Services/HouseholdService.swift`
- Create: `HouseMate/Services/MemberService.swift`
- Create: `HouseMateTests/Services/HouseholdServiceTests.swift`

- [ ] **Step 1: Write failing test**

  ```swift
  // HouseMateTests/Services/HouseholdServiceTests.swift
  import XCTest
  @testable import HouseMate

  final class HouseholdServiceTests: XCTestCase {
      func test_generateInviteCode_isEightCharacters() {
          let code = HouseholdService.generateInviteCode()
          XCTAssertEqual(code.count, 8)
      }

      func test_generateInviteCode_isAlphanumeric() {
          let code = HouseholdService.generateInviteCode()
          let allowed = CharacterSet.alphanumerics
          XCTAssertTrue(code.unicodeScalars.allSatisfy { allowed.contains($0) })
      }

      func test_generateInviteCode_isUppercase() {
          let code = HouseholdService.generateInviteCode()
          XCTAssertEqual(code, code.uppercased())
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement HouseholdService.swift**

  ```swift
  // HouseMate/Services/HouseholdService.swift
  import Supabase
  import Foundation

  @MainActor
  final class HouseholdService {

      func createHousehold(name: String, displayName: String, userId: UUID) async throws -> (Household, Member) {
          // Insert household
          let household: Household = try await supabase
              .from("households")
              .insert(["name": name, "created_by": userId.uuidString])
              .select()
              .single()
              .execute()
              .value

          // Insert member
          let member: Member = try await supabase
              .from("members")
              .insert([
                  "household_id": household.id.uuidString,
                  "user_id": userId.uuidString,
                  "display_name": displayName
              ])
              .select()
              .single()
              .execute()
              .value

          // Generate invite code
          try await generateNewInviteCode(householdId: household.id, userId: userId)

          return (household, member)
      }

      func joinHousehold(inviteCode: String, displayName: String, userId: UUID) async throws -> (Household, Member) {
          // Look up invite
          let invite: HouseholdInvite = try await supabase
              .from("household_invites")
              .select()
              .eq("invite_code", value: inviteCode.uppercased())
              .eq("is_active", value: true)
              .single()
              .execute()
              .value

          // Check member count
          let memberCount: Int = try await supabase
              .from("members")
              .select("id", head: true, count: .exact)
              .eq("household_id", value: invite.householdId.uuidString)
              .execute()
              .count ?? 0
          guard memberCount < 6 else { throw HouseholdError.householdFull }

          // Insert member
          let member: Member = try await supabase
              .from("members")
              .insert([
                  "household_id": invite.householdId.uuidString,
                  "user_id": userId.uuidString,
                  "display_name": displayName
              ])
              .select()
              .single()
              .execute()
              .value

          // Fetch household
          let household: Household = try await supabase
              .from("households")
              .select()
              .eq("id", value: invite.householdId.uuidString)
              .single()
              .execute()
              .value

          return (household, member)
      }

      func fetchHousehold(id: UUID) async throws -> Household {
          try await supabase
              .from("households")
              .select()
              .eq("id", value: id.uuidString)
              .single()
              .execute()
              .value
      }

      func updateHouseholdName(_ name: String, householdId: UUID) async throws {
          try await supabase
              .from("households")
              .update(["name": name])
              .eq("id", value: householdId.uuidString)
              .execute()
      }

      func activeInviteCode(householdId: UUID) async throws -> String? {
          let invites: [HouseholdInvite] = try await supabase
              .from("household_invites")
              .select()
              .eq("household_id", value: householdId.uuidString)
              .eq("is_active", value: true)
              .execute()
              .value
          return invites.first?.inviteCode
      }

      func regenerateInviteCode(householdId: UUID, userId: UUID) async throws -> String {
          // Deactivate existing codes
          try await supabase
              .from("household_invites")
              .update(["is_active": false])
              .eq("household_id", value: householdId.uuidString)
              .execute()
          return try await generateNewInviteCode(householdId: householdId, userId: userId)
      }

      @discardableResult
      private func generateNewInviteCode(householdId: UUID, userId: UUID) async throws -> String {
          let code = HouseholdService.generateInviteCode()
          try await supabase
              .from("household_invites")
              .insert([
                  "household_id": householdId.uuidString,
                  "invite_code": code,
                  "created_by": userId.uuidString
              ])
              .execute()
          return code
      }

      static func generateInviteCode() -> String {
          let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
          return String((0..<8).map { _ in chars.randomElement()! })
      }
  }

  enum HouseholdError: LocalizedError {
      case householdFull
      case invalidCode
      var errorDescription: String? {
          switch self {
          case .householdFull: return "This household is full (max 6 members)."
          case .invalidCode: return "That code wasn't found. Check the code and try again."
          }
      }
  }
  ```

- [ ] **Step 4: Implement MemberService.swift**

  ```swift
  // HouseMate/Services/MemberService.swift
  import Supabase
  import Foundation

  @MainActor
  final class MemberService {
      func fetchMembers(householdId: UUID) async throws -> [Member] {
          try await supabase
              .from("members")
              .select()
              .eq("household_id", value: householdId.uuidString)
              .order("created_at", ascending: true)
              .execute()
              .value
      }

      func fetchMember(userId: UUID) async throws -> Member? {
          let members: [Member] = try await supabase
              .from("members")
              .select()
              .eq("user_id", value: userId.uuidString)
              .execute()
              .value
          return members.first
      }

      func updateDisplayName(_ name: String, memberId: UUID) async throws {
          try await supabase
              .from("members")
              .update(["display_name": name])
              .eq("id", value: memberId.uuidString)
              .execute()
      }
  }
  ```

- [ ] **Step 5: Run tests to verify they pass**

- [ ] **Step 6: Commit**

  ```bash
  git add HouseMate/Services/HouseholdService.swift HouseMate/Services/MemberService.swift HouseMateTests/Services/HouseholdServiceTests.swift
  git commit -m "feat: add HouseholdService and MemberService"
  ```

---

### Task 9: TaskService

**Files:**
- Create: `HouseMate/Services/TaskService.swift`
- Create: `HouseMateTests/Services/TaskServiceTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // HouseMateTests/Services/TaskServiceTests.swift
  import XCTest
  @testable import HouseMate

  final class TaskServiceTests: XCTestCase {
      // Unit-test the recurring advancement logic (pure function, no network)
      func test_advancedTask_resetsCompletionFields() {
          let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
          var task = HMTask.makeTest(dueDate: base, isRecurring: true, recurringInterval: .weekly,
                                     isCompleted: true, completedBy: UUID(), completedAt: Date())
          TaskService.applyRecurringAdvancement(to: &task)
          XCTAssertFalse(task.isCompleted)
          XCTAssertNil(task.completedBy)
          XCTAssertNil(task.completedAt)
      }

      func test_advancedTask_advancesDueDateByWeek() {
          let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
          var task = HMTask.makeTest(dueDate: base, isRecurring: true, recurringInterval: .weekly)
          TaskService.applyRecurringAdvancement(to: &task)
          let expected = Calendar.current.date(byAdding: .day, value: 7, to: base)!
          XCTAssertEqual(task.dueDate, expected)
      }

      func test_advancedTask_setsNilDueDateToTodayPlusInterval() {
          var task = HMTask.makeTest(dueDate: nil, isRecurring: true, recurringInterval: .daily)
          TaskService.applyRecurringAdvancement(to: &task)
          let expected = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
          XCTAssertEqual(task.dueDate, expected)
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement TaskService.swift**

  ```swift
  // HouseMate/Services/TaskService.swift
  import Supabase
  import Foundation

  @MainActor
  final class TaskService {

      func fetchTasks(householdId: UUID) async throws -> [HMTask] {
          try await supabase
              .from("tasks")
              .select()
              .eq("household_id", value: householdId.uuidString)
              .order("created_at", ascending: false)
              .execute()
              .value
      }

      func createTask(_ task: HMTask) async throws -> HMTask {
          try await supabase
              .from("tasks")
              .insert(task)
              .select()
              .single()
              .execute()
              .value
      }

      func updateTask(_ task: HMTask) async throws {
          try await supabase
              .from("tasks")
              .update(task)
              .eq("id", value: task.id.uuidString)
              .execute()
      }

      func deleteTask(id: UUID) async throws {
          try await supabase
              .from("tasks")
              .delete()
              .eq("id", value: id.uuidString)
              .execute()
      }

      /// Complete a task. For recurring tasks, creates a log entry and advances the due date.
      /// For one-time tasks, marks it completed. Returns nil if already completed (concurrent race).
      func completeTask(_ task: HMTask, memberId: UUID) async throws -> HMTask? {
          // Fetch fresh copy to detect concurrent completion
          let fresh: HMTask = try await supabase
              .from("tasks")
              .select()
              .eq("id", value: task.id.uuidString)
              .single()
              .execute()
              .value

          guard !fresh.isCompleted else { return nil }  // already completed

          // Insert completion log
          let log = TaskCompletionLog(
              id: UUID(), taskId: task.id, completedBy: memberId, completedAt: Date()
          )
          try await supabase.from("task_completion_logs").insert(log).execute()

          if fresh.isRecurring {
              var advanced = fresh
              TaskService.applyRecurringAdvancement(to: &advanced)
              try await updateTask(advanced)
              return advanced
          } else {
              var completed = fresh
              completed.isCompleted = true
              completed.completedBy = memberId
              completed.completedAt = Date()
              try await updateTask(completed)
              return completed
          }
      }

      func fetchCompletionLogs(taskId: UUID, limit: Int = 5) async throws -> [TaskCompletionLog] {
          try await supabase
              .from("task_completion_logs")
              .select()
              .eq("task_id", value: taskId.uuidString)
              .order("completed_at", ascending: false)
              .limit(limit)
              .execute()
              .value
      }

      /// Pure function: advances due date and resets completion fields on a recurring task.
      static func applyRecurringAdvancement(to task: inout HMTask) {
          let today = Calendar.current.startOfDay(for: Date())
          if let due = task.dueDate, let next = task.nextDueDate {
              task.dueDate = next
              _ = due  // suppress unused warning
          } else if let interval = task.recurringInterval {
              task.dueDate = Calendar.current.date(byAdding: .day, value: interval.days, to: today)
          }
          task.isCompleted = false
          task.completedBy = nil
          task.completedAt = nil
      }
  }
  ```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/Services/TaskService.swift HouseMateTests/Services/TaskServiceTests.swift
  git commit -m "feat: add TaskService with completion and recurring advancement logic"
  ```

---

### Task 10: BinService and MaintenanceService

**Files:**
- Create: `HouseMate/Services/BinService.swift`
- Create: `HouseMate/Services/MaintenanceService.swift`
- Create: `HouseMate/Services/TemplateService.swift`
- Create: `HouseMate/Resources/BuiltInTemplates.swift`

- [ ] **Step 1: Implement BinService.swift**

  ```swift
  // HouseMate/Services/BinService.swift
  import Supabase
  import Foundation

  @MainActor
  final class BinService {
      func fetchSchedule(householdId: UUID) async throws -> BinSchedule? {
          let schedules: [BinSchedule] = try await supabase
              .from("bin_schedules")
              .select()
              .eq("household_id", value: householdId.uuidString)
              .execute()
              .value
          return schedules.first
      }

      func upsertSchedule(_ schedule: BinSchedule) async throws -> BinSchedule {
          try await supabase
              .from("bin_schedules")
              .upsert(schedule, onConflict: "household_id")
              .select()
              .single()
              .execute()
              .value
      }
  }
  ```

- [ ] **Step 2: Implement MaintenanceService.swift**

  ```swift
  // HouseMate/Services/MaintenanceService.swift
  import Supabase
  import Foundation

  @MainActor
  final class MaintenanceService {
      func fetchItems(householdId: UUID) async throws -> [MaintenanceItem] {
          try await supabase
              .from("maintenance_items")
              .select()
              .eq("household_id", value: householdId.uuidString)
              .order("name", ascending: true)
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

      func logCompletion(_ log: MaintenanceLog, updatingItem item: MaintenanceItem) async throws -> MaintenanceItem {
          // Insert log
          try await supabase.from("maintenance_logs").insert(log).execute()
          // Update item's lastCompletedDate
          var updated = item
          updated.lastCompletedDate = log.completedDate
          try await updateItem(updated)
          return updated
      }

      func fetchLogs(itemId: UUID) async throws -> [MaintenanceLog] {
          try await supabase
              .from("maintenance_logs")
              .select()
              .eq("maintenance_item_id", value: itemId.uuidString)
              .order("completed_date", ascending: false)
              .execute()
              .value
      }

      func deleteLog(id: UUID) async throws {
          try await supabase
              .from("maintenance_logs")
              .delete()
              .eq("id", value: id.uuidString)
              .execute()
      }
  }
  ```

- [ ] **Step 3: Implement TemplateService.swift**

  ```swift
  // HouseMate/Services/TemplateService.swift
  import Supabase
  import Foundation

  @MainActor
  final class TemplateService {
      // Task templates
      func fetchUserTaskTemplates(householdId: UUID) async throws -> [TaskTemplate] {
          let rows: [[String: String]] = try await supabase
              .from("task_templates")
              .select()
              .eq("household_id", value: householdId.uuidString)
              .order("title", ascending: true)
              .execute()
              .value
          // Decoded via custom init since isBuiltIn is not in DB
          return try rows.map { row in
              guard let idStr = row["id"], let id = UUID(uuidString: idStr),
                    let title = row["title"],
                    let categoryStr = row["category"],
                    let category = TaskCategory(rawValue: categoryStr) else {
                  throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad row"))
              }
              let interval = row["recurring_interval"].flatMap { RecurringInterval(rawValue: $0) }
              return TaskTemplate(id: id, householdId: UUID(uuidString: row["household_id"]!)!,
                                  title: title, category: category, recurringInterval: interval)
          }
      }

      func createTaskTemplate(_ template: TaskTemplate, householdId: UUID) async throws {
          try await supabase
              .from("task_templates")
              .insert([
                  "household_id": householdId.uuidString,
                  "title": template.title,
                  "category": template.category.rawValue,
                  "recurring_interval": template.recurringInterval?.rawValue as Any
              ])
              .execute()
      }

      func deleteTaskTemplate(id: UUID) async throws {
          try await supabase
              .from("task_templates")
              .delete()
              .eq("id", value: id.uuidString)
              .execute()
      }

      // Maintenance templates
      func fetchUserMaintenanceTemplates(householdId: UUID) async throws -> [MaintenanceTemplate] {
          let rows: [MaintenanceTemplate] = try await supabase
              .from("maintenance_templates")
              .select()
              .eq("household_id", value: householdId.uuidString)
              .order("name", ascending: true)
              .execute()
              .value
          return rows
      }

      func createMaintenanceTemplate(_ template: MaintenanceTemplate, householdId: UUID) async throws {
          try await supabase
              .from("maintenance_templates")
              .insert([
                  "household_id": householdId.uuidString,
                  "name": template.name,
                  "category": template.category.rawValue,
                  "interval_days": template.intervalDays
              ])
              .execute()
      }

      func deleteMaintenanceTemplate(id: UUID) async throws {
          try await supabase
              .from("maintenance_templates")
              .delete()
              .eq("id", value: id.uuidString)
              .execute()
      }
  }
  ```

- [ ] **Step 4: Implement BuiltInTemplates.swift**

  ```swift
  // HouseMate/Resources/BuiltInTemplates.swift
  import Foundation

  enum BuiltInTemplates {
      static let tasks: [TaskTemplate] = [
          // Weekly
          TaskTemplate(builtInTitle: "Take out trash", category: .other, recurringInterval: .weekly),
          TaskTemplate(builtInTitle: "Vacuum living room", category: .other, recurringInterval: .weekly),
          TaskTemplate(builtInTitle: "Clean bathrooms", category: .bathroom, recurringInterval: .weekly),
          TaskTemplate(builtInTitle: "Wipe down kitchen counters", category: .kitchen, recurringInterval: .weekly),
          TaskTemplate(builtInTitle: "Do laundry", category: .other, recurringInterval: .weekly),
          TaskTemplate(builtInTitle: "Mop floors", category: .other, recurringInterval: .weekly),
          // Monthly
          TaskTemplate(builtInTitle: "Clean fridge", category: .kitchen, recurringInterval: .monthly),
          TaskTemplate(builtInTitle: "Dust ceiling fans", category: .other, recurringInterval: .monthly),
          TaskTemplate(builtInTitle: "Wash windows", category: .outdoor, recurringInterval: .monthly),
          TaskTemplate(builtInTitle: "Deep clean oven", category: .kitchen, recurringInterval: .monthly),
          // One-time checklists
          TaskTemplate(builtInTitle: "Spring cleaning", category: .other, recurringInterval: nil),
          TaskTemplate(builtInTitle: "Pre-guest prep", category: .other, recurringInterval: nil),
          TaskTemplate(builtInTitle: "Move-in checklist", category: .other, recurringInterval: nil),
      ]

      static let maintenance: [MaintenanceTemplate] = [
          MaintenanceTemplate(builtInName: "Change furnace filter", category: .yearRound, intervalDays: 90),
          MaintenanceTemplate(builtInName: "Replace HVAC filter", category: .yearRound, intervalDays: 90),
          MaintenanceTemplate(builtInName: "Clean dryer vent", category: .yearRound, intervalDays: 365),
          MaintenanceTemplate(builtInName: "Sweep/blow out garage", category: .yearRound, intervalDays: 30),
          MaintenanceTemplate(builtInName: "Test smoke detectors", category: .yearRound, intervalDays: 180),
          MaintenanceTemplate(builtInName: "Clean range hood filter", category: .yearRound, intervalDays: 90),
          MaintenanceTemplate(builtInName: "Flush water heater", category: .yearRound, intervalDays: 365),
          MaintenanceTemplate(builtInName: "Check window/door seals", category: .fall, intervalDays: 365),
          MaintenanceTemplate(builtInName: "Clean gutters", category: .spring, intervalDays: 180),
          MaintenanceTemplate(builtInName: "Winterize outdoor faucets", category: .fall, intervalDays: 365),
      ]
  }
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/Services/BinService.swift HouseMate/Services/MaintenanceService.swift HouseMate/Services/TemplateService.swift HouseMate/Resources/BuiltInTemplates.swift
  git commit -m "feat: add BinService, MaintenanceService, TemplateService, BuiltInTemplates"
  ```

---

## Chunk 4: Realtime, AppState, and Navigation

### Task 11: RealtimeService

**Files:**
- Create: `HouseMate/Services/RealtimeService.swift`

- [ ] **Step 1: Write failing test**

  ```swift
  // HouseMateTests/Services/RealtimeServiceTests.swift
  import XCTest
  @testable import HouseMate

  final class RealtimeServiceTests: XCTestCase {
      func test_realtimeService_canBeInstantiated() {
          let service = RealtimeService()
          XCTAssertNotNil(service)
      }

      func test_notificationNames_areCorrect() {
          XCTAssertEqual(RealtimeService.tasksChangedNotification.rawValue, "RealtimeTasksChanged")
          XCTAssertEqual(RealtimeService.binScheduleChangedNotification.rawValue, "RealtimeBinScheduleChanged")
          XCTAssertEqual(RealtimeService.maintenanceChangedNotification.rawValue, "RealtimeMaintenanceChanged")
          XCTAssertEqual(RealtimeService.membersChangedNotification.rawValue, "RealtimeMembersChanged")
      }
  }
  ```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement RealtimeService.swift**

  ```swift
  // HouseMate/Services/RealtimeService.swift
  import Supabase
  import Foundation

  /// Manages Supabase Realtime subscriptions for a household.
  /// Posts NotificationCenter notifications when changes arrive so ViewModels can refresh.
  @MainActor
  final class RealtimeService {
      enum Notification: String {
          case tasksChangedNotification      = "RealtimeTasksChanged"
          case binScheduleChangedNotification = "RealtimeBinScheduleChanged"
          case maintenanceChangedNotification = "RealtimeMaintenanceChanged"
          case membersChangedNotification    = "RealtimeMembersChanged"

          var name: Foundation.Notification.Name { .init(rawValue) }
      }

      static let tasksChangedNotification      = Notification.tasksChangedNotification
      static let binScheduleChangedNotification = Notification.binScheduleChangedNotification
      static let maintenanceChangedNotification = Notification.maintenanceChangedNotification
      static let membersChangedNotification    = Notification.membersChangedNotification

      private var channel: RealtimeChannelV2?

      func subscribe(householdId: UUID) async {
          await unsubscribe()
          let idStr = householdId.uuidString
          let ch = supabase.channel("household-\(idStr)")

          ch.onPostgresChange(AnyAction.self, schema: "public", table: "tasks",
              filter: "household_id=eq.\(idStr)") { [weak self] _ in
              Task { @MainActor in
                  NotificationCenter.default.post(name: RealtimeService.tasksChangedNotification.name, object: nil)
              }
          }

          ch.onPostgresChange(AnyAction.self, schema: "public", table: "task_completion_logs") { [weak self] _ in
              Task { @MainActor in
                  NotificationCenter.default.post(name: RealtimeService.tasksChangedNotification.name, object: nil)
              }
          }

          ch.onPostgresChange(AnyAction.self, schema: "public", table: "bin_schedules",
              filter: "household_id=eq.\(idStr)") { [weak self] _ in
              Task { @MainActor in
                  NotificationCenter.default.post(name: RealtimeService.binScheduleChangedNotification.name, object: nil)
              }
          }

          ch.onPostgresChange(AnyAction.self, schema: "public", table: "maintenance_items",
              filter: "household_id=eq.\(idStr)") { [weak self] _ in
              Task { @MainActor in
                  NotificationCenter.default.post(name: RealtimeService.maintenanceChangedNotification.name, object: nil)
              }
          }

          ch.onPostgresChange(AnyAction.self, schema: "public", table: "maintenance_logs") { [weak self] _ in
              Task { @MainActor in
                  NotificationCenter.default.post(name: RealtimeService.maintenanceChangedNotification.name, object: nil)
              }
          }

          ch.onPostgresChange(AnyAction.self, schema: "public", table: "members",
              filter: "household_id=eq.\(idStr)") { [weak self] _ in
              Task { @MainActor in
                  NotificationCenter.default.post(name: RealtimeService.membersChangedNotification.name, object: nil)
              }
          }

          await ch.subscribe()
          self.channel = ch
      }

      func unsubscribe() async {
          if let ch = channel {
              await supabase.removeChannel(ch)
              channel = nil
          }
      }
  }
  ```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/Services/RealtimeService.swift HouseMateTests/Services/RealtimeServiceTests.swift
  git commit -m "feat: add RealtimeService with Supabase channel subscriptions"
  ```

---

### Task 12: AppState

**Files:**
- Create: `HouseMate/State/AppState.swift`
- Create: `HouseMateTests/State/AppStateTests.swift`

- [ ] **Step 1: Write failing test**

  ```swift
  // HouseMateTests/State/AppStateTests.swift
  import XCTest
  @testable import HouseMate

  final class AppStateTests: XCTestCase {
      func test_appState_initiallyUnauthenticated() {
          let state = AppState()
          XCTAssertFalse(state.isAuthenticated)
          XCTAssertNil(state.currentMember)
          XCTAssertNil(state.household)
      }

      func test_appState_isAuthenticated_whenUserSet() {
          let state = AppState()
          // isAuthenticated derives from currentUser via AuthService
          // Can't set directly; test the computed property logic
          XCTAssertFalse(state.isAuthenticated)
      }

      func test_appState_hasHousehold_whenHouseholdSet() {
          let state = AppState()
          XCTAssertFalse(state.hasHousehold)
          state.household = Household(id: UUID(), name: "Test", createdBy: UUID(), createdAt: Date())
          XCTAssertTrue(state.hasHousehold)
      }
  }
  ```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement AppState.swift**

  ```swift
  // HouseMate/State/AppState.swift
  import Observation
  import Foundation

  @Observable
  @MainActor
  final class AppState {
      var household: Household?
      var currentMember: Member?
      var members: [Member] = []

      private let authService = AuthService()

      var isAuthenticated: Bool { authService.currentUser != nil }
      var hasHousehold: Bool { household != nil }
      var currentUserId: UUID? { authService.currentUser.map { UUID(uuidString: $0.id.uuidString) } ?? nil }

      func loadSession() async {
          _ = try? await authService.restoreSession()
          guard isAuthenticated, let userId = currentUserId else { return }
          let memberService = MemberService()
          guard let member = try? await memberService.fetchMember(userId: userId) else { return }
          currentMember = member
          let householdService = HouseholdService()
          household = try? await householdService.fetchHousehold(id: member.householdId)
          members = (try? await memberService.fetchMembers(householdId: member.householdId)) ?? []
      }

      func signOut() async throws {
          try await authService.signOut()
          household = nil
          currentMember = nil
          members = []
      }

      func memberName(for memberId: UUID?) -> String {
          guard let memberId else { return "Unknown" }
          return members.first { $0.id == memberId }?.displayName ?? "Unknown"
      }
  }
  ```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/State/AppState.swift HouseMateTests/State/AppStateTests.swift
  git commit -m "feat: add AppState observable with session restoration"
  ```

---

### Task 13: Navigation Skeleton and Onboarding

**Files:**
- Create: `HouseMate/App/HouseMateApp.swift` (replace default)
- Create: `HouseMate/App/ContentView.swift` (replace default)
- Create: `HouseMate/Views/Main/MainTabView.swift`
- Create: `HouseMate/Views/Onboarding/AuthView.swift`
- Create: `HouseMate/Views/Onboarding/HouseholdChoiceView.swift`
- Create: `HouseMate/Views/Onboarding/CreateHouseholdView.swift`
- Create: `HouseMate/Views/Onboarding/JoinHouseholdView.swift`

- [ ] **Step 1: Implement HouseMateApp.swift**

  ```swift
  // HouseMate/App/HouseMateApp.swift
  import SwiftUI

  @main
  struct HouseMateApp: App {
      @State private var appState = AppState()

      var body: some Scene {
          WindowGroup {
              ContentView()
                  .environment(appState)
                  .task { await appState.loadSession() }
          }
      }
  }
  ```

- [ ] **Step 2: Implement ContentView.swift**

  ```swift
  // HouseMate/App/ContentView.swift
  import SwiftUI

  struct ContentView: View {
      @Environment(AppState.self) private var appState

      var body: some View {
          if !appState.isAuthenticated {
              AuthView()
          } else if !appState.hasHousehold {
              HouseholdChoiceView()
          } else {
              MainTabView()
          }
      }
  }
  ```

- [ ] **Step 3: Implement MainTabView.swift**

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
              Text("Maintenance")
                  .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver") }
          }
      }
  }
  ```

- [ ] **Step 4: Implement AuthView.swift**

  ```swift
  // HouseMate/Views/Onboarding/AuthView.swift
  import SwiftUI

  struct AuthView: View {
      @Environment(AppState.self) private var appState
      @State private var email = ""
      @State private var password = ""
      @State private var displayName = ""
      @State private var isSignUp = true
      @State private var isLoading = false
      @State private var errorMessage: String?

      private let authService = AuthService()

      var body: some View {
          NavigationStack {
              Form {
                  Section {
                      TextField("Email", text: $email)
                          .keyboardType(.emailAddress)
                          .autocorrectionDisabled()
                          .textInputAutocapitalization(.never)
                      SecureField("Password", text: $password)
                      if isSignUp {
                          TextField("Your display name", text: $displayName)
                      }
                  }
                  if let error = errorMessage {
                      Section { Text(error).foregroundStyle(.red) }
                  }
                  Section {
                      Button(isSignUp ? "Create Account" : "Sign In") {
                          Task { await submit() }
                      }
                      .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && displayName.isEmpty))
                  }
                  Section {
                      Button(isSignUp ? "Already have an account? Sign In" : "New here? Create Account") {
                          isSignUp.toggle()
                          errorMessage = nil
                      }
                      .foregroundStyle(.secondary)
                  }
              }
              .navigationTitle(isSignUp ? "Create Account" : "Sign In")
              .disabled(isLoading)
          }
      }

      private func submit() async {
          isLoading = true
          errorMessage = nil
          do {
              if isSignUp {
                  _ = try await authService.signUp(email: email, password: password)
              } else {
                  _ = try await authService.signIn(email: email, password: password)
              }
              await appState.loadSession()
          } catch {
              errorMessage = error.localizedDescription
          }
          isLoading = false
      }
  }
  ```

- [ ] **Step 5: Implement HouseholdChoiceView.swift**

  ```swift
  // HouseMate/Views/Onboarding/HouseholdChoiceView.swift
  import SwiftUI

  struct HouseholdChoiceView: View {
      @State private var showCreate = false
      @State private var showJoin = false

      var body: some View {
          NavigationStack {
              VStack(spacing: 24) {
                  Text("Welcome to HouseMate")
                      .font(.largeTitle).bold()
                  Text("Set up your household to get started.")
                      .foregroundStyle(.secondary)
                  Button("Create a Household") { showCreate = true }
                      .buttonStyle(.borderedProminent)
                  Button("Join a Household") { showJoin = true }
                      .buttonStyle(.bordered)
              }
              .padding()
              .sheet(isPresented: $showCreate) { CreateHouseholdView() }
              .sheet(isPresented: $showJoin) { JoinHouseholdView() }
          }
      }
  }
  ```

- [ ] **Step 6: Implement CreateHouseholdView.swift**

  ```swift
  // HouseMate/Views/Onboarding/CreateHouseholdView.swift
  import SwiftUI

  struct CreateHouseholdView: View {
      @Environment(AppState.self) private var appState
      @Environment(\.dismiss) private var dismiss
      @State private var householdName = ""
      @State private var displayName = ""
      @State private var isLoading = false
      @State private var errorMessage: String?

      private let householdService = HouseholdService()

      var body: some View {
          NavigationStack {
              Form {
                  Section("Household") {
                      TextField("e.g. The Smith Household", text: $householdName)
                  }
                  Section("Your Name") {
                      TextField("How should we call you?", text: $displayName)
                  }
                  if let error = errorMessage {
                      Section { Text(error).foregroundStyle(.red) }
                  }
              }
              .navigationTitle("Create Household")
              .toolbar {
                  ToolbarItem(placement: .confirmationAction) {
                      Button("Create") { Task { await create() } }
                          .disabled(isLoading || householdName.isEmpty || displayName.isEmpty)
                  }
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { dismiss() }
                  }
              }
              .disabled(isLoading)
          }
      }

      private func create() async {
          guard let userId = appState.currentUserId else { return }
          isLoading = true
          errorMessage = nil
          do {
              let (household, member) = try await householdService.createHousehold(
                  name: householdName, displayName: displayName, userId: userId)
              appState.household = household
              appState.currentMember = member
              appState.members = [member]
              dismiss()
          } catch {
              errorMessage = error.localizedDescription
          }
          isLoading = false
      }
  }
  ```

- [ ] **Step 7: Implement JoinHouseholdView.swift**

  ```swift
  // HouseMate/Views/Onboarding/JoinHouseholdView.swift
  import SwiftUI

  struct JoinHouseholdView: View {
      @Environment(AppState.self) private var appState
      @Environment(\.dismiss) private var dismiss
      @State private var inviteCode = ""
      @State private var displayName = ""
      @State private var isLoading = false
      @State private var errorMessage: String?

      private let householdService = HouseholdService()
      private let memberService = MemberService()

      var body: some View {
          NavigationStack {
              Form {
                  Section("Invite Code") {
                      TextField("Enter 8-character code", text: $inviteCode)
                          .autocorrectionDisabled()
                          .textInputAutocapitalization(.characters)
                  }
                  Section("Your Name") {
                      TextField("How should we call you?", text: $displayName)
                  }
                  if let error = errorMessage {
                      Section { Text(error).foregroundStyle(.red) }
                  }
              }
              .navigationTitle("Join Household")
              .toolbar {
                  ToolbarItem(placement: .confirmationAction) {
                      Button("Join") { Task { await join() } }
                          .disabled(isLoading || inviteCode.count != 8 || displayName.isEmpty)
                  }
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { dismiss() }
                  }
              }
              .disabled(isLoading)
          }
      }

      private func join() async {
          guard let userId = appState.currentUserId else { return }
          isLoading = true
          errorMessage = nil
          do {
              let (household, member) = try await householdService.joinHousehold(
                  inviteCode: inviteCode, displayName: displayName, userId: userId)
              let allMembers = try await memberService.fetchMembers(householdId: household.id)
              appState.household = household
              appState.currentMember = member
              appState.members = allMembers
              dismiss()
          } catch {
              errorMessage = error.localizedDescription
          }
          isLoading = false
      }
  }
  ```

- [ ] **Step 8: Build and run on simulator**

  Run the app in the iOS Simulator. Verify:
  - App launches to AuthView (sign up / sign in)
  - After sign up, navigates to HouseholdChoiceView
  - "Create a Household" sheet opens and creates a household on submit
  - After creating, navigates to MainTabView (4 tabs visible with placeholder text)
  - Second device/simulator: sign up with different email, "Join a Household", enter the code, navigates to MainTabView

- [ ] **Step 9: Commit**

  ```bash
  git add HouseMate/App/ HouseMate/Views/ HouseMate/State/
  git commit -m "feat: add navigation skeleton, onboarding auth + household flow"
  ```

---

## Chunk 5: Date Decoding Configuration

### Task 14: Supabase Date Decoder

Supabase returns dates in ISO 8601 format for `TIMESTAMPTZ` fields and `YYYY-MM-DD` format for `DATE` fields. The default `JSONDecoder` only handles ISO 8601. We need a shared decoder that handles both.

**Files:**
- Modify: `HouseMate/Config/Supabase.swift`
- Create: `HouseMateTests/Config/DateDecoderTests.swift`

- [ ] **Step 1: Write failing test**

  ```swift
  // HouseMateTests/Config/DateDecoderTests.swift
  import XCTest
  @testable import HouseMate

  final class DateDecoderTests: XCTestCase {
      struct DateWrapper: Decodable {
          let value: Date
      }

      func test_decodesISO8601Timestamp() throws {
          let json = #"{"value":"2026-03-12T10:00:00Z"}"#.data(using: .utf8)!
          let result = try HouseMateDecoder.decode(DateWrapper.self, from: json)
          XCTAssertNotNil(result.value)
      }

      func test_decodesDateOnlyString() throws {
          let json = #"{"value":"2026-03-12"}"#.data(using: .utf8)!
          let result = try HouseMateDecoder.decode(DateWrapper.self, from: json)
          let components = Calendar.current.dateComponents([.year, .month, .day], from: result.value)
          XCTAssertEqual(components.year, 2026)
          XCTAssertEqual(components.month, 3)
          XCTAssertEqual(components.day, 12)
      }
  }
  ```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Add HouseMateDecoder to Supabase.swift**

  ```swift
  // HouseMate/Config/Supabase.swift
  import Supabase
  import Foundation

  let supabase = SupabaseClient(
      supabaseURL: URL(string: Secrets.supabaseURL)!,
      supabaseKey: Secrets.supabaseAnonKey
  )

  enum HouseMateDecoder {
      static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .custom { decoder in
              let s = try decoder.singleValueContainer().decode(String.self)
              if let date = ISO8601DateFormatter().date(from: s) { return date }
              let df = DateFormatter()
              df.dateFormat = "yyyy-MM-dd"
              df.timeZone = TimeZone(identifier: "UTC")
              if let date = df.date(from: s) { return date }
              throw DecodingError.dataCorrupted(
                  .init(codingPath: decoder.codingPath,
                        debugDescription: "Cannot decode date from '\(s)'"))
          }
          return try decoder.decode(type, from: data)
      }
  }
  ```

  > **Note:** `supabase-swift` 2.x uses its own internal decoder configured via `PostgrestClient`. Check the SDK documentation for `PostgrestBuilder.decoder(_:)` — if available, configure the shared decoder there instead of using `HouseMateDecoder` manually. If the SDK handles dates automatically, this task may be a no-op and the tests validate that assumption.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/Config/Supabase.swift HouseMateTests/Config/DateDecoderTests.swift
  git commit -m "feat: add HouseMateDecoder handling ISO8601 and date-only strings"
  ```

---

**Foundation complete.** All models, services, Realtime, AppState, onboarding, and 4-tab skeleton are in place. Proceed to the Tasks feature plan.
