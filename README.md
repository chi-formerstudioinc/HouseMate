# HouseMate

An iOS app for couples and roommates to manage their shared household. Built around **home maintenance tracking**, a household **dashboard**, and stubs for **Insights** and **Finance** features planned for future phases.

Built with SwiftUI and Supabase as the backend.

---

## What it does

- **Home tab** — dashboard showing summary stats, this week's bin collection (garbage or recycle), open repairs, and upcoming maintenance.
- **Maintenance tab** — track repairs, recurring maintenance, and lifecycle items with overdue indicators (green/yellow/red), cost tracking, and a full completion log. Three item types: Repairs, Recurring, Lifecycle.
- **Insights tab** — stub in v1. Planned: repair cost breakdowns, completion rates, per-member stats.
- **Finance tab** — stub in v1. Planned: mortgage tracking and utility bill tracking with charts.
- **Bin schedule** — configured in Settings. A/B weekly rotation with per-device local notifications. Surfaced on the dashboard (no dedicated tab).
- **Onboarding** — sign up/in with email + password. Create a household or join one via an 8-character invite code. Up to 6 members per household.

---

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | SwiftUI, iOS 17+, `@Observable` |
| Backend | Supabase (PostgreSQL + RLS) |
| Auth | Supabase Auth (email + password) |
| Realtime sync | Supabase Realtime (postgres_changes WebSocket) |
| Local notifications | `UNUserNotificationCenter` (per-device) |
| Swift SDK | `supabase-swift` 2.x via Swift Package Manager |

> Push notifications and App Store publishing require an Apple Developer account ($99/yr) — deferred to a future phase. Physical device testing works with a free Apple ID (reinstall required every 7 days).

---

## Project setup

### 1. Supabase project

1. Create a new project at [supabase.com](https://supabase.com)
2. In the SQL editor, run the full schema from `docs/superpowers/plans/2026-03-12-housemate-foundation.md` → **Task 2, Step 2** (create tables) and **Step 3** (RLS policies)
3. Enable Realtime on: `bin_schedules`, `maintenance_items`, `maintenance_logs`, `members`, `household_invites`
4. Go to **Project Settings > API** and copy your Project URL and anon key

### 2. Secrets file

```bash
cp HouseMate/HouseMate/Config/Secrets.swift.example HouseMate/HouseMate/Config/Secrets.swift
```

Open `Secrets.swift` and fill in your credentials:

```swift
enum Secrets {
    static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
    static let supabaseAnonKey = "YOUR_ANON_KEY"
}
```

`Secrets.swift` is gitignored and must never be committed.

### 3. Build

Open `HouseMate/HouseMate.xcodeproj` in Xcode, select a simulator, and hit **⌘B** to build.

---

## Architecture

- **Models** — Codable Swift structs mapping 1:1 to Supabase tables. Snake_case DB columns → camelCase Swift via `CodingKeys`.
- **Services** — `@MainActor` classes (`AuthService`, `TaskService`, `BinService`, etc.) own all async Supabase operations.
- **AppState** — `@Observable` class holding `currentUser`, `currentMember`, `household`, and `members`. Injected via SwiftUI `.environment`.
- **RealtimeService** — subscribes to Supabase Realtime channels and posts `NotificationCenter` events. ViewModels observe these to refresh without polling.
- **HouseMateDecoder** — shared `JSONDecoder` configured to handle both ISO8601 timestamps and `yyyy-MM-dd` date-only strings from Supabase.

---

## Branch strategy & implementation plans

| Branch | Status | Plan |
|---|---|---|
| `feature/foundation` | Merged to main | `docs/superpowers/plans/2026-03-12-housemate-foundation.md` |
| `feature/maintenance` | In progress | `docs/superpowers/plans/2026-03-13-housemate-maintenance.md` |
| `feature/home` | Not started | TBD |
| `feature/insights` | Not started | TBD (stub) |
| `feature/finance` | Not started | TBD (stub, future phase) |

Plans use TDD (write failing tests → implement → pass). Each plan has step-by-step tasks with checkboxes. When resuming, check which steps are done by looking at the existing files vs the plan's file structure.

---

## Key things to know when returning to this project

- **Always branch from main.** One feature branch per plan. Squash and merge PRs to keep main history clean.
- **Secrets.swift is never committed.** If the file is missing after a fresh clone, recreate it from the `.example` file.
- **The `.worktrees/` directory** is gitignored. It's used for Claude worktree sessions and can be safely deleted if stale.
- **Tests are in `HouseMateTests/`.** Run with **⌘U**. The suite has 43 unit tests covering models, services, and state. All must pass before merging.
- **Realtime is filtered by `household_id`** — channels subscribe only to rows belonging to the current household. See `RealtimeService.swift`.
- **Recurring task completion** is a multi-step operation (insert log + reset + advance due date) — it is not atomic. See comments in `TaskService.swift` for the caller contract.
- **Bin rotation** is calculated from `startingDate` (a known past pickup date used as an anchor), not stored state. See `BinSchedule.swift`.
- **Built-in templates** are bundled in `BuiltInTemplates.swift` (13 task + 10 maintenance). User-created templates go to Supabase.
