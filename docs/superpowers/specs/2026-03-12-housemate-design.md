# HouseMate — Design Spec
**Date:** 2026-03-12
**Status:** Approved

---

## Overview

HouseMate is an iOS app for couples and roommates to manage their shared household. It covers home maintenance tracking (repairs, recurring tasks, and lifecycle items), a household dashboard, insights, and finances. The app is built with SwiftUI and Supabase as the backend.

> **2026-03-13 update:** Chore/task management and the dedicated Bins tab have been removed from v1 scope. The app now has four tabs: Home, Maintenance, Insights, Finance. Bin schedule data and config remain but are surfaced on the dashboard and in Settings only. Insights and Finance tabs are stubs in v1 with content planned for future phases.

---

## Target Audience

Couples or roommates sharing a home who want a simple, shared system to coordinate household responsibilities.

---

## Platform

- iOS only (SwiftUI)
- Testable on simulator and physical device via Xcode (free Apple ID sufficient for device install, reinstall required every 7 days)
- Supabase free tier used for all backend services during development and personal use
- Push notifications and App Store publishing require Apple Developer account ($99/year) — deferred to a later phase

---

## Architecture

### Technology Stack
- **Frontend:** SwiftUI (iOS 17+, `@Observable`)
- **Backend:** Supabase (PostgreSQL + Row Level Security)
- **Auth:** Supabase Auth (email + password)
- **Sync:** Supabase Realtime (postgres_changes WebSocket subscriptions, filtered by household_id)
- **Scheduled reminders:** UNUserNotificationCenter (local, per-device — bin day and maintenance)
- **Push notifications:** Deferred to a future phase (requires paid Apple Developer account for APNs)
- **Swift SDK:** `supabase-swift` via Swift Package Manager (https://github.com/supabase/supabase-swift)

### Supabase Conventions
All primary keys are `UUID` (PostgreSQL `gen_random_uuid()`). Foreign keys use `UUID`. Snake_case column names map to camelCase Swift properties via `CodingKeys`. Row Level Security (RLS) policies enforce that authenticated users can only read/write rows belonging to their household (determined by membership in the `members` table). All tables have `created_at TIMESTAMPTZ DEFAULT now()`. Mutable tables also have `updated_at TIMESTAMPTZ DEFAULT now()` maintained via a trigger.

### Database Tables
- `households` — id, name, created_by (auth.users)
- `members` — id, household_id, user_id (auth.users), display_name
- `household_invites` — id, household_id, invite_code (unique), is_active, created_by
- `bin_schedules` — id, household_id (UNIQUE), pickup_day_of_week, rotation_a, rotation_b, starting_rotation, starting_date, notify_day_before, notify_morning_of, updated_at
- `maintenance_items` — id, household_id, item_type (repair|recurring|lifecycle), name, category, interval_days (nullable), last_completed_date, notes, template_id, updated_at
- `maintenance_logs` — id, maintenance_item_id (CASCADE), completed_by (members, nullable), completed_date, notes, cost (NUMERIC nullable)
- `maintenance_templates` — id, household_id, name, category, interval_days (user-created only; built-in are bundled in app)

### Household Invite Flow
1. User creates a household → app generates a random 8-character alphanumeric invite code → stored in `household_invites`
2. Code is surfaced in the app with copy/share options
3. Invited member signs up → enters the code → app looks up `household_invites` → inserts a `members` row linking their user_id to the household
4. Both devices sync via Supabase Realtime
5. The invite code can be regenerated at any time (old code set `is_active = false`, new code inserted)
6. Maximum 6 members per household (enforced in app before joining)

### Local Notification Distribution
Bin day and maintenance reminders use `UNUserNotificationCenter` (local, per-device). Because `bin_schedules` and `maintenance_items` are fetched from Supabase on launch and whenever Realtime fires a change, every member's device has access to the current data. Each device independently schedules its own local notifications.

---

## Data Models

### Household
| Field | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| name | String | e.g. "The Smith Household" |
| createdBy | UUID | FK → auth.users |

### Member
| Field | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| householdId | UUID | FK → households |
| userId | UUID | FK → auth.users |
| displayName | String | |

### BinSchedule
**Cardinality:** Exactly one row per household (UNIQUE on household_id). If none exists, the Bin This Week dashboard card shows an empty state prompting the user to configure the schedule in Settings.

| Field | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| householdId | UUID | FK → households (UNIQUE) |
| pickupDayOfWeek | Int | 1 = Sunday … 7 = Saturday |
| rotationA | String | Max 50 chars. Required. |
| rotationB | String | Max 50 chars. Required. |
| startingRotation | String | "A" or "B" |
| startingDate | Date | Known past pickup date — rotation anchor |
| notifyDayBefore | Bool | |
| notifyMorningOf | Bool | |
| updatedAt | Date | |

**Rotation calculation:** `weeksDiff = floor((D - startingDate) / 7)`. Even → startingRotation. Odd → the other. `startingDate` must be past/present. Changing `pickupDayOfWeek` resets `startingDate` to the most recent past occurrence of that day and requires re-confirming `startingRotation`.

### MaintenanceItem
| Field | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| householdId | UUID | FK → households |
| itemType | Enum | repair, recurring, lifecycle |
| name | String | |
| category | Enum | exterior, hvac, electrical, plumbing, structural, vehicle |
| intervalDays | Int? | nil for repair type |
| lastCompletedDate | Date? | nil = never completed |
| notes | String? | Permanent item-level notes |
| templateId | UUID? | FK → maintenance_templates |
| updatedAt | Date | |

**Item types:** `repair` = ad-hoc fix (no interval); `recurring` = scheduled maintenance with a fixed interval; `lifecycle` = long-lived item tracking (e.g. appliance age).

**Next due:** `lastCompletedDate + intervalDays`. Nil → treat as overdue. Not applicable to repair type.

**Color thresholds:** Green = >14 days away. Yellow = ≤14 days (including today). Red = overdue or never completed. Repairs with no scheduled date show as red.

> Full item type behaviour, frequency enums, and form logic are defined in the Maintenance implementation plan: `docs/superpowers/plans/2026-03-13-housemate-maintenance.md`.

### MaintenanceLog
| Field | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| maintenanceItemId | UUID | FK → maintenance_items (ON DELETE CASCADE) |
| completedBy | UUID? | Optional FK → members — used for per-member Insights |
| completedDate | Date | |
| notes | String? | |
| cost | Decimal? | |

### MaintenanceTemplate
| Field | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| householdId | UUID? | FK → households — null for built-in (local only) |
| name | String | |
| category | Enum | exterior, hvac, electrical, plumbing, structural, vehicle |
| intervalDays | Int | |

Built-in maintenance templates are bundled locally in the app (no DB rows). User-created templates are stored in `maintenance_templates` with a non-null `household_id`.

---

## Screens & Navigation

### Tab Bar (4 tabs)
1. Home
2. Maintenance
3. Insights
4. Finance

Plus a Settings screen accessible via a profile/gear icon in the Home tab navigation bar.

---

### Onboarding (first launch)

**Happy path:**
- Check for active Supabase Auth session; if none, show Sign Up / Sign In screen
- After auth: check if user has a `members` row; if not, show choice: **Create a Household** or **Join a Household**
  - Create → enter household name + your display name → household + member rows created → invite code generated → shown with copy/share options → proceed to Home
  - Join → enter invite code → validated against `household_invites` → member row created → proceed to Home

**Error states:**
- Network unavailable: show "No internet connection. HouseMate requires a connection to sync." with retry option
- Invalid invite code: "That code wasn't found. Check the code and try again."
- Household full (6 members): "This household is full. Ask your admin to make room."
- Auth error (wrong password, email taken): shown inline below the relevant field

---

### Home (Dashboard)

- Greeting: "Good morning, [displayName]"
- **Summary Stats card** — key household numbers (e.g. items overdue, completed this month). Placeholder for richer Insights content in a future phase.
- **Bin This Week card** — answers "garbage or recycle?" for the current week's pickup. Taps through to bin schedule config in Settings.
- **Open Repairs card** — maintenance items of type `repair` that are overdue or unscheduled. Taps through to filtered Maintenance list.
- **Upcoming Maintenance card** — next few recurring/lifecycle items due soon (yellow/red status). Taps through to Maintenance list.

> Detailed layout and card behaviour to be designed during the Home tab implementation phase.

---

### Maintenance Tab

**List view:**
- Items grouped by category (exterior, hvac, electrical, plumbing, structural, vehicle)
- Each row: name, last done date (or "Never"), next due date, color-coded dot
- Tap → item detail

**Item detail:**
- Name, item type, category, interval (if applicable), next due date, color status
- Permanent notes field (editable inline)
- **Log Completion** → sheet: date (default today), notes, cost
- Full history log ordered by `completedDate` descending
- Edit item button

**Add item:**
- Manual: item type (repair / recurring / lifecycle), name, category, interval (required for recurring/lifecycle), last completed date (optional)
- "From Templates" → browse and tap to pre-fill

**Built-in maintenance templates:**
- Change furnace filter — 90 days — HVAC
- Replace HVAC filter — 90 days — HVAC
- Clean dryer vent — 365 days — HVAC
- Sweep/blow out garage — 30 days — Exterior
- Test smoke detectors — 180 days — Electrical
- Clean range hood filter — 90 days — HVAC
- Flush water heater — 365 days — Plumbing
- Check window/door seals — 365 days — Structural
- Clean gutters — 180 days — Exterior
- Winterize outdoor faucets — 365 days — Plumbing

**Maintenance notifications:**
- Local notification fires at 9 AM on item's next due date: "Time to: [item name]"
- After each log entry saved, notification cancelled and rescheduled
- **Notification budget:** 64 local notification cap. Each maintenance item schedules only its single next notification. Bin day = at most 2 slots. On app launch and after any Realtime change to relevant tables, all notifications cancelled and rescheduled from scratch.

---

### Insights Tab

Stub in v1 — placeholder screen ("Coming soon").

**Planned future content:**
- Repair costs and categories over time
- Maintenance completion rates
- Per-member breakdowns (who did what)
No additional data models required for the stub. The data to power most Insights content (maintenance logs with costs, completion timestamps, member attribution) is already captured by the Maintenance module.

---

### Finance Tab

Stub in v1 — placeholder screen ("Coming soon"). Full implementation deferred to a dedicated Finance phase.

**Planned future content:**
- Mortgage tracking: balance, equity, interest rate, loan length, renewal date — with graphs/charts
- Utility bill tracking: Electricity, Power, City Utilities, Hydro, Internet — monthly entries with interactive charts grouped by category and time period

No data models or DB tables defined until the Finance phase is planned.

---

### Settings

- Household name (editable)
- Members list with display names
- **Invite Member** — shows current invite code with copy/share options; **Regenerate Code** button deactivates old code, creates new one
- **Member removal** — not supported in v1. Help text: "To leave this household, contact your household admin."
- **Bin Schedule** — configure pickup day of week, rotation A/B labels, starting rotation + date, notification toggles (day before at 6 PM, morning of at 7 AM). Reschedules local notifications on save.
- **Notification preferences** — maintenance due reminder toggle (9 AM on due date)
- Your display name (editable)

---

## Notification Summary

| Trigger | Delivery | Recipient |
|---|---|---|
| Bin day (day before, 6 PM) | Local scheduled (per device) | All members independently |
| Bin day (morning of, 7 AM) | Local scheduled (per device) | All members independently |
| Maintenance item due | Local scheduled (9 AM on due date, per device) | All members independently |

Push notifications (background alerts when app is closed) deferred to a future phase requiring paid Apple Developer account.

---

## Built-in Template Library

### Maintenance Templates
See Maintenance tab section above.

---

## V1 Scope Boundaries (explicitly out of scope)

- Chore / task management — deferred; no Tasks tab in v1
- Dedicated Bins tab — bin schedule config is in Settings; bin data surfaced on dashboard only
- Finance features (mortgage, utility tracking) — deferred to Finance phase
- Insights content (charts, stats, cost breakdowns) — Insights tab is a stub in v1
- Android support
- Web companion app
- Municipality calendar import
- Expense splitting / shared budgeting
- Grocery / pantry tracking
- In-app messaging / chat
- Smart home integrations
- Gamification / points system
- Bin schedule import from external calendar
- Push notifications (background alerts when app closed) — deferred to paid Apple Developer phase
