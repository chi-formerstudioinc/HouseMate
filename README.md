# feature/foundation — Safe to delete

This branch has been squash-merged into `main` via PR #1 on 2026-03-12. Everything here lives permanently in `main`.

## What was built here

- **Models** — Household, Member, Task, TaskCompletionLog, TaskTemplate, BinSchedule, MaintenanceItem, MaintenanceLog, MaintenanceTemplate
- **Services** — AuthService, HouseholdService, MemberService, TaskService, BinService, MaintenanceService, TemplateService, RealtimeService
- **State** — AppState (@Observable, session restoration)
- **Views** — Full onboarding flow (AuthView → HouseholdChoiceView → Create/JoinHouseholdView) + MainTabView 4-tab skeleton
- **Shared decoder** — HouseMateDecoder handling ISO8601 and date-only strings
- **Tests** — 43 unit tests, all passing

## To delete

Go to GitHub → Code → Branches → find `feature/foundation` → click the trash icon.
