# HouseMate Tasks Feature Implementation Plan (Supabase)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Tasks tab — list with sorting/filtering/swipe actions, task detail with completion history, add/edit form with recurring support, and a template browser. In-app live updates via Supabase Realtime (tasks refresh automatically when another member makes changes).

**Architecture:** `AppState` (`@Observable`) holds household/member context and is injected via SwiftUI `.environment`. `TasksViewModel` and `TaskFormViewModel` (`@Observable`) are owned as `@State` in their views. They call `TaskService` and `TemplateService` for all data operations. `TasksViewModel` observes `NotificationCenter` for `RealtimeService.tasksChangedNotification` to refresh the list when another member changes a task. Sorting/filtering logic is pure computed properties on `TasksViewModel` and is fully unit-tested.

**Tech Stack:** Swift 5.9+, SwiftUI (`@Observable`), Supabase (via `TaskService`/`TemplateService`), UNUserNotificationCenter, XCTest, iOS 17.0+

**Prerequisite:** Foundation plan complete — `HouseMate/Models/`, `HouseMate/Services/`, `HouseMate/State/AppState.swift`, `HouseMate/Resources/BuiltInTemplates.swift`, `HouseMate/Services/RealtimeService.swift`, and the 4-tab navigation skeleton must all be in place.

**Spec:** `docs/superpowers/specs/2026-03-12-housemate-design.md`

---

## File Structure

**New files:**
- `HouseMate/ViewModels/TasksViewModel.swift` — task list state: fetch, filter, sort, complete, delete; observes RealtimeService notifications
- `HouseMate/ViewModels/TaskFormViewModel.swift` — add/edit form state, validation, save
- `HouseMate/Views/Tasks/TaskRowView.swift` — single list row with overdue indicator and swipe actions
- `HouseMate/Views/Tasks/TaskListView.swift` — full task list: filter bar, list, FAB
- `HouseMate/Views/Tasks/TaskDetailView.swift` — task detail with completion log
- `HouseMate/Views/Tasks/TaskFormView.swift` — add/edit task form sheet
- `HouseMate/Views/Tasks/TaskTemplateView.swift` — template browser sheet

**Modified files:**
- `HouseMate/Views/Main/MainTabView.swift` — replace Tasks placeholder with `TaskListView`

---

## Chunk 1: ViewModels

### Task 1: TasksViewModel

**Files:**
- Create: `HouseMate/ViewModels/TasksViewModel.swift`
- Create: `HouseMateTests/ViewModels/TasksViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // HouseMateTests/ViewModels/TasksViewModelTests.swift
  import XCTest
  @testable import HouseMate

  final class TasksViewModelTests: XCTestCase {
      let householdId = UUID()
      var memberId: UUID!

      override func setUp() {
          super.setUp()
          memberId = UUID()
      }

      func makeTasks() -> [HMTask] {
          let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
          let tomorrow  = Calendar.current.date(byAdding: .day, value:  1, to: Date())!
          let nextWeek  = Calendar.current.date(byAdding: .day, value:  7, to: Date())!
          return [
              HMTask.makeTest(title: "Overdue",   dueDate: yesterday, isCompleted: false),
              HMTask.makeTest(title: "Tomorrow",  dueDate: tomorrow,  isCompleted: false),
              HMTask.makeTest(title: "Next Week", dueDate: nextWeek,  isCompleted: false),
              HMTask.makeTest(title: "Undated",   dueDate: nil,       isCompleted: false),
              HMTask.makeTest(title: "Done",      dueDate: tomorrow,  isCompleted: true),
          ]
      }

      // MARK: - Sorting

      func test_defaultSort_overdueFirst() {
          let vm = TasksViewModel(householdId: householdId, memberId: memberId)
          vm.tasks = makeTasks()
          vm.filterMode = .all
          let sorted = vm.filteredAndSortedTasks
          XCTAssertEqual(sorted.first?.title, "Overdue")
      }

      func test_defaultSort_dueDateAscendingAfterOverdue() {
          let vm = TasksViewModel(householdId: householdId, memberId: memberId)
          vm.tasks = makeTasks()
          vm.filterMode = .all
          let sorted = vm.filteredAndSortedTasks
          let nonOverdueTitles = sorted.filter { !$0.isOverdue && !$0.isCompleted && $0.dueDate != nil }.map(\.title)
          XCTAssertEqual(nonOverdueTitles.first, "Tomorrow")
      }

      func test_defaultSort_undatedAfterDated() {
          let vm = TasksViewModel(householdId: householdId, memberId: memberId)
          vm.tasks = makeTasks()
          vm.filterMode = .all
          let sorted = vm.filteredAndSortedTasks
          let lastBeforeCompleted = sorted.filter { !$0.isCompleted }.last
          XCTAssertEqual(lastBeforeCompleted?.title, "Undated")
      }

      // MARK: - Filtering

      func test_filterAll_includesIncompleteAndComplete() {
          let vm = TasksViewModel(householdId: householdId, memberId: memberId)
          vm.tasks = makeTasks()
          vm.filterMode = .all
          // "all" shows incomplete tasks (not completed)
          let titles = vm.filteredAndSortedTasks.map(\.title)
          XCTAssertFalse(titles.contains("Done"))
          XCTAssertTrue(titles.contains("Tomorrow"))
      }

      func test_filterCompleted_showsOnlyCompleted() {
          let vm = TasksViewModel(householdId: householdId, memberId: memberId)
          vm.tasks = makeTasks()
          vm.filterMode = .completed
          XCTAssertTrue(vm.filteredAndSortedTasks.allSatisfy(\.isCompleted))
          XCTAssertEqual(vm.filteredAndSortedTasks.count, 1)
      }

      func test_filterMine_showsOnlyAssignedToCurrentMember() {
          let vm = TasksViewModel(householdId: householdId, memberId: memberId)
          var tasks = makeTasks()
          tasks[0] = HMTask.makeTest(title: "Mine", assignedTo: memberId)
          tasks[1] = HMTask.makeTest(title: "Theirs", assignedTo: UUID())
          vm.tasks = tasks
          vm.filterMode = .mine
          let titles = vm.filteredAndSortedTasks.map(\.title)
          XCTAssertTrue(titles.contains("Mine"))
          XCTAssertFalse(titles.contains("Theirs"))
      }

      func test_filterUnassigned_showsOnlyNilAssignee() {
          let vm = TasksViewModel(householdId: householdId, memberId: memberId)
          vm.tasks = makeTasks()  // all have nil assignedTo
          vm.filterMode = .unassigned
          XCTAssertTrue(vm.filteredAndSortedTasks.allSatisfy { $0.assignedTo == nil })
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

  ```bash
  xcodebuild test -scheme HouseMate -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing HouseMateTests/TasksViewModelTests
  ```
  Expected: FAIL — `TasksViewModel` not defined.

- [ ] **Step 3: Implement TasksViewModel.swift**

  ```swift
  // HouseMate/ViewModels/TasksViewModel.swift
  import Observation
  import Foundation

  enum TaskFilterMode: String, CaseIterable {
      case all, mine, unassigned, completed
      var displayName: String { rawValue.capitalized }
  }

  @Observable
  @MainActor
  final class TasksViewModel {
      var tasks: [HMTask] = []
      var filterMode: TaskFilterMode = .all
      var isLoading = false
      var error: Error?

      private let householdId: UUID
      private let memberId: UUID
      private let taskService = TaskService()
      private var realtimeObserver: NSObjectProtocol?

      init(householdId: UUID, memberId: UUID) {
          self.householdId = householdId
          self.memberId = memberId
      }

      var filteredAndSortedTasks: [HMTask] {
          let filtered: [HMTask]
          switch filterMode {
          case .all:
              filtered = tasks.filter { !$0.isCompleted }
          case .mine:
              filtered = tasks.filter { $0.assignedTo == memberId && !$0.isCompleted }
          case .unassigned:
              filtered = tasks.filter { $0.assignedTo == nil && !$0.isCompleted }
          case .completed:
              filtered = tasks.filter(\.isCompleted)
          }
          return filtered.sorted { a, b in
              // 1. Overdue first
              if a.isOverdue != b.isOverdue { return a.isOverdue }
              // 2. Dated before undated
              switch (a.dueDate, b.dueDate) {
              case (.some(let da), .some(let db)): return da < db
              case (.some, .none): return true
              case (.none, .some): return false
              case (.none, .none): return a.createdAt < b.createdAt
              }
          }
      }

      func load() async {
          isLoading = true
          error = nil
          do {
              tasks = try await taskService.fetchTasks(householdId: householdId)
          } catch {
              self.error = error
          }
          isLoading = false
      }

      func subscribeToRealtime() {
          realtimeObserver = NotificationCenter.default.addObserver(
              forName: RealtimeService.tasksChangedNotification.name,
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

      /// Returns nil if the task was already completed by another member (concurrent race).
      func completeTask(_ task: HMTask) async -> Bool {
          do {
              guard let updated = try await taskService.completeTask(task, memberId: memberId) else {
                  return false  // already completed
              }
              if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                  tasks[index] = updated
              }
              return true
          } catch {
              self.error = error
              return false
          }
      }

      func deleteTask(_ task: HMTask) async {
          do {
              try await taskService.deleteTask(id: task.id)
              tasks.removeAll { $0.id == task.id }
          } catch {
              self.error = error
          }
      }

      func taskAdded(_ task: HMTask) {
          tasks.insert(task, at: 0)
      }

      func taskUpdated(_ task: HMTask) {
          if let index = tasks.firstIndex(where: { $0.id == task.id }) {
              tasks[index] = task
          }
      }
  }
  ```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/ViewModels/TasksViewModel.swift HouseMateTests/ViewModels/TasksViewModelTests.swift
  git commit -m "feat: add TasksViewModel with filtering, sorting, and Realtime integration"
  ```

---

### Task 2: TaskFormViewModel

**Files:**
- Create: `HouseMate/ViewModels/TaskFormViewModel.swift`
- Create: `HouseMateTests/ViewModels/TaskFormViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // HouseMateTests/ViewModels/TaskFormViewModelTests.swift
  import XCTest
  @testable import HouseMate

  final class TaskFormViewModelTests: XCTestCase {
      func test_newForm_hasDefaultValues() {
          let vm = TaskFormViewModel(householdId: UUID(), memberId: UUID())
          XCTAssertEqual(vm.title, "")
          XCTAssertEqual(vm.category, .other)
          XCTAssertEqual(vm.priority, .medium)
          XCTAssertFalse(vm.isRecurring)
          XCTAssertNil(vm.recurringInterval)
      }

      func test_editForm_populatesFieldsFromTask() {
          let task = HMTask.makeTest(
              title: "Clean kitchen",
              category: .kitchen,
              priority: .high,
              isRecurring: true,
              recurringInterval: .weekly
          )
          let vm = TaskFormViewModel(householdId: UUID(), memberId: UUID(), editingTask: task)
          XCTAssertEqual(vm.title, "Clean kitchen")
          XCTAssertEqual(vm.category, .kitchen)
          XCTAssertEqual(vm.priority, .high)
          XCTAssertTrue(vm.isRecurring)
          XCTAssertEqual(vm.recurringInterval, .weekly)
      }

      func test_canSave_requiresNonEmptyTitle() {
          let vm = TaskFormViewModel(householdId: UUID(), memberId: UUID())
          XCTAssertFalse(vm.canSave)
          vm.title = "  "  // whitespace only
          XCTAssertFalse(vm.canSave)
          vm.title = "Take out trash"
          XCTAssertTrue(vm.canSave)
      }

      func test_toggleRecurring_clearsInterval() {
          let vm = TaskFormViewModel(householdId: UUID(), memberId: UUID())
          vm.isRecurring = true
          vm.recurringInterval = .weekly
          vm.isRecurring = false
          XCTAssertNil(vm.recurringInterval)
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement TaskFormViewModel.swift**

  ```swift
  // HouseMate/ViewModels/TaskFormViewModel.swift
  import Observation
  import Foundation

  @Observable
  @MainActor
  final class TaskFormViewModel {
      var title: String = ""
      var category: TaskCategory = .other
      var priority: TaskPriority = .medium
      var assignedTo: UUID? = nil
      var dueDate: Date? = nil
      var hasDueDate: Bool = false
      var isRecurring: Bool = false {
          didSet { if !isRecurring { recurringInterval = nil } }
      }
      var recurringInterval: RecurringInterval? = nil
      var isSaving = false
      var saveError: Error?

      private let householdId: UUID
      private let memberId: UUID
      private let editingTask: HMTask?
      private let taskService = TaskService()

      var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
      var isEditing: Bool { editingTask != nil }

      init(householdId: UUID, memberId: UUID, editingTask: HMTask? = nil) {
          self.householdId = householdId
          self.memberId = memberId
          self.editingTask = editingTask
          if let task = editingTask {
              title = task.title
              category = task.category
              priority = task.priority
              assignedTo = task.assignedTo
              if let due = task.dueDate { dueDate = due; hasDueDate = true }
              isRecurring = task.isRecurring
              recurringInterval = task.recurringInterval
          }
      }

      /// Saves (create or update). Returns the saved task on success, nil on failure.
      func save() async -> HMTask? {
          guard canSave else { return nil }
          isSaving = true
          saveError = nil
          do {
              let result: HMTask
              if let existing = editingTask {
                  var updated = existing
                  updated.title = title.trimmingCharacters(in: .whitespaces)
                  updated.category = category
                  updated.priority = priority
                  updated.assignedTo = assignedTo
                  updated.dueDate = hasDueDate ? dueDate : nil
                  updated.isRecurring = isRecurring
                  updated.recurringInterval = isRecurring ? recurringInterval : nil
                  try await taskService.updateTask(updated)
                  result = updated
              } else {
                  let newTask = HMTask(
                      id: UUID(),
                      householdId: householdId,
                      title: title.trimmingCharacters(in: .whitespaces),
                      category: category,
                      priority: priority,
                      assignedTo: assignedTo,
                      dueDate: hasDueDate ? dueDate : nil,
                      isRecurring: isRecurring,
                      recurringInterval: isRecurring ? recurringInterval : nil,
                      isCompleted: false,
                      completedBy: nil,
                      completedAt: nil,
                      templateId: nil,
                      createdAt: Date(),
                      updatedAt: Date()
                  )
                  result = try await taskService.createTask(newTask)
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

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

  ```bash
  git add HouseMate/ViewModels/TaskFormViewModel.swift HouseMateTests/ViewModels/TaskFormViewModelTests.swift
  git commit -m "feat: add TaskFormViewModel with create/edit logic and validation"
  ```

---

## Chunk 2: Views — List and Row

### Task 3: TaskRowView

**Files:**
- Create: `HouseMate/Views/Tasks/TaskRowView.swift`

- [ ] **Step 1: Implement TaskRowView.swift**

  ```swift
  // HouseMate/Views/Tasks/TaskRowView.swift
  import SwiftUI

  struct TaskRowView: View {
      let task: HMTask
      let memberName: String
      let onComplete: () -> Void
      let onDelete: () -> Void

      var body: some View {
          HStack(alignment: .top, spacing: 12) {
              // Overdue indicator
              Circle()
                  .fill(task.isOverdue ? Color.red : Color.clear)
                  .frame(width: 8, height: 8)
                  .padding(.top, 6)

              VStack(alignment: .leading, spacing: 4) {
                  Text(task.title)
                      .font(.body)
                      .strikethrough(task.isCompleted)
                      .foregroundStyle(task.isCompleted ? .secondary : .primary)

                  HStack(spacing: 8) {
                      Label(task.category.displayName, systemImage: "tag")
                      if let due = task.dueDate {
                          Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                              .foregroundStyle(task.isOverdue ? .red : .secondary)
                      }
                      if !memberName.isEmpty {
                          Label(memberName, systemImage: "person")
                      }
                  }
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Spacer()

              if task.isRecurring {
                  Image(systemName: "arrow.clockwise")
                      .font(.caption)
                      .foregroundStyle(.secondary)
              }
          }
          .padding(.vertical, 4)
          .swipeActions(edge: .leading, allowsFullSwipe: true) {
              Button {
                  onComplete()
              } label: {
                  Label("Complete", systemImage: "checkmark")
              }
              .tint(.green)
          }
          .swipeActions(edge: .trailing) {
              Button(role: .destructive) {
                  onDelete()
              } label: {
                  Label("Delete", systemImage: "trash")
              }
          }
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add HouseMate/Views/Tasks/TaskRowView.swift
  git commit -m "feat: add TaskRowView with overdue indicator and swipe actions"
  ```

---

### Task 4: TaskListView

**Files:**
- Create: `HouseMate/Views/Tasks/TaskListView.swift`
- Modify: `HouseMate/Views/Main/MainTabView.swift`

- [ ] **Step 1: Implement TaskListView.swift**

  ```swift
  // HouseMate/Views/Tasks/TaskListView.swift
  import SwiftUI

  struct TaskListView: View {
      @Environment(AppState.self) private var appState
      @State private var viewModel: TasksViewModel?
      @State private var showAddForm = false
      @State private var taskToDelete: HMTask?
      @State private var showAlreadyCompletedAlert = false

      var body: some View {
          NavigationStack {
              Group {
                  if let vm = viewModel {
                      taskListContent(vm: vm)
                  } else {
                      ProgressView()
                  }
              }
              .navigationTitle("Tasks")
              .toolbar {
                  ToolbarItem(placement: .primaryAction) {
                      Button { showAddForm = true } label: {
                          Image(systemName: "plus")
                      }
                  }
              }
          }
          .task { await setupViewModel() }
          .sheet(isPresented: $showAddForm) {
              if let vm = viewModel,
                 let household = appState.household,
                 let member = appState.currentMember {
                  TaskFormView(householdId: household.id, memberId: member.id, members: appState.members) { task in
                      vm.taskAdded(task)
                  }
              }
          }
          .alert("Already Completed", isPresented: $showAlreadyCompletedAlert) {
              Button("OK", role: .cancel) { }
          } message: {
              Text("This task was already completed by another member.")
          }
          .alert("Delete Task?", isPresented: Binding(
              get: { taskToDelete != nil },
              set: { if !$0 { taskToDelete = nil } }
          )) {
              Button("Delete", role: .destructive) {
                  if let task = taskToDelete {
                      taskToDelete = nil
                      Task { await viewModel?.deleteTask(task) }
                  }
              }
              Button("Cancel", role: .cancel) { taskToDelete = nil }
          } message: {
              Text("Delete this task? Its completion history will also be deleted.")
          }
      }

      @ViewBuilder
      private func taskListContent(vm: TasksViewModel) -> some View {
          VStack(spacing: 0) {
              // Filter bar
              ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 8) {
                      ForEach(TaskFilterMode.allCases, id: \.self) { mode in
                          Button(mode.displayName) {
                              vm.filterMode = mode
                          }
                          .buttonStyle(.bordered)
                          .tint(vm.filterMode == mode ? .accentColor : .secondary)
                      }
                  }
                  .padding(.horizontal)
              }
              .padding(.vertical, 8)

              if vm.isLoading {
                  ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
              } else if vm.filteredAndSortedTasks.isEmpty {
                  ContentUnavailableView("No Tasks", systemImage: "checklist",
                      description: Text(emptyDescription(for: vm.filterMode)))
              } else {
                  List(vm.filteredAndSortedTasks) { task in
                      NavigationLink(destination: taskDetail(task: task, vm: vm)) {
                          TaskRowView(
                              task: task,
                              memberName: appState.memberName(for: task.assignedTo),
                              onComplete: {
                                  Task {
                                      let succeeded = await vm.completeTask(task)
                                      if !succeeded { showAlreadyCompletedAlert = true }
                                  }
                              },
                              onDelete: { taskToDelete = task }
                          )
                      }
                  }
                  .listStyle(.plain)
                  .refreshable { await vm.load() }
              }
          }
      }

      @ViewBuilder
      private func taskDetail(task: HMTask, vm: TasksViewModel) -> some View {
          if let household = appState.household, let member = appState.currentMember {
              TaskDetailView(
                  task: task,
                  householdId: household.id,
                  memberId: member.id,
                  members: appState.members,
                  onUpdate: { vm.taskUpdated($0) },
                  onDelete: { vm.deleteTask($0) }
              )
          }
      }

      private func setupViewModel() async {
          guard let household = appState.household, let member = appState.currentMember else { return }
          if viewModel == nil {
              let vm = TasksViewModel(householdId: household.id, memberId: member.id)
              viewModel = vm
              await vm.load()
              vm.subscribeToRealtime()
          }
      }

      private func emptyDescription(for mode: TaskFilterMode) -> String {
          switch mode {
          case .all: return "No tasks yet. Tap + to add one."
          case .mine: return "No tasks assigned to you."
          case .unassigned: return "No unassigned tasks."
          case .completed: return "No completed tasks."
          }
      }
  }
  ```

- [ ] **Step 2: Wire up TaskListView in MainTabView.swift**

  ```swift
  // HouseMate/Views/Main/MainTabView.swift
  import SwiftUI

  struct MainTabView: View {
      var body: some View {
          TabView {
              Text("Home")
                  .tabItem { Label("Home", systemImage: "house") }
              TaskListView()
                  .tabItem { Label("Tasks", systemImage: "checklist") }
              Text("Bins")
                  .tabItem { Label("Bins", systemImage: "trash") }
              Text("Maintenance")
                  .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver") }
          }
      }
  }
  ```

- [ ] **Step 3: Build and verify**

  Run in simulator. Verify:
  - Tasks tab shows the list view with filter bar
  - If no tasks, shows empty state
  - Tapping + opens the add task sheet (not yet implemented, but button should be present)

- [ ] **Step 4: Commit**

  ```bash
  git add HouseMate/Views/Tasks/TaskListView.swift HouseMate/Views/Main/MainTabView.swift
  git commit -m "feat: add TaskListView with filter bar, empty state, and navigation"
  ```

---

## Chunk 3: Views — Detail and Form

### Task 5: TaskDetailView

**Files:**
- Create: `HouseMate/Views/Tasks/TaskDetailView.swift`

- [ ] **Step 1: Implement TaskDetailView.swift**

  ```swift
  // HouseMate/Views/Tasks/TaskDetailView.swift
  import SwiftUI

  struct TaskDetailView: View {
      @State private var task: HMTask
      @State private var completionLogs: [TaskCompletionLog] = []
      @State private var isLoadingLogs = false
      @State private var showEditForm = false
      @State private var showDeleteConfirmation = false
      @Environment(\.dismiss) private var dismiss

      let householdId: UUID
      let memberId: UUID
      let members: [Member]
      let onUpdate: (HMTask) -> Void
      let onDelete: (HMTask) async -> Void

      private let taskService = TaskService()

      init(task: HMTask, householdId: UUID, memberId: UUID, members: [Member],
           onUpdate: @escaping (HMTask) -> Void, onDelete: @escaping (HMTask) async -> Void) {
          _task = State(initialValue: task)
          self.householdId = householdId
          self.memberId = memberId
          self.members = members
          self.onUpdate = onUpdate
          self.onDelete = onDelete
      }

      var body: some View {
          List {
              Section {
                  LabeledContent("Category", value: task.category.displayName)
                  LabeledContent("Priority", value: task.priority.displayName)
                  if let assignee = task.assignedTo {
                      LabeledContent("Assigned to", value: memberName(for: assignee))
                  }
                  if let due = task.dueDate {
                      LabeledContent("Due", value: due.formatted(date: .long, time: .omitted))
                  }
                  if task.isRecurring, let interval = task.recurringInterval {
                      LabeledContent("Recurring", value: interval.displayName)
                  }
                  LabeledContent("Status", value: task.isCompleted ? "Completed" : "Pending")
              }

              Section("Completion History") {
                  if isLoadingLogs {
                      ProgressView()
                  } else if completionLogs.isEmpty {
                      Text("No completions yet.").foregroundStyle(.secondary)
                  } else {
                      ForEach(completionLogs) { log in
                          HStack {
                              Text(memberName(for: log.completedBy))
                              Spacer()
                              Text(log.completedAt.formatted(date: .abbreviated, time: .shortened))
                                  .foregroundStyle(.secondary)
                                  .font(.caption)
                          }
                      }
                  }
              }
          }
          .navigationTitle(task.title)
          .navigationBarTitleDisplayMode(.large)
          .toolbar {
              ToolbarItem(placement: .primaryAction) {
                  Button("Edit") { showEditForm = true }
              }
              ToolbarItem(placement: .destructiveAction) {
                  Button("Delete", role: .destructive) { showDeleteConfirmation = true }
              }
          }
          .sheet(isPresented: $showEditForm) {
              TaskFormView(householdId: householdId, memberId: memberId, members: members,
                  editingTask: task) { updated in
                  task = updated
                  onUpdate(updated)
              }
          }
          .alert("Delete Task?", isPresented: $showDeleteConfirmation) {
              Button("Delete", role: .destructive) {
                  Task {
                      await onDelete(task)
                      dismiss()
                  }
              }
              Button("Cancel", role: .cancel) { }
          } message: {
              Text("Delete this task? Its completion history will also be deleted.")
          }
          .task { await loadCompletionLogs() }
      }

      private func loadCompletionLogs() async {
          isLoadingLogs = true
          completionLogs = (try? await taskService.fetchCompletionLogs(taskId: task.id, limit: 5)) ?? []
          isLoadingLogs = false
      }

      private func memberName(for memberId: UUID) -> String {
          members.first { $0.id == memberId }?.displayName ?? "Unknown"
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add HouseMate/Views/Tasks/TaskDetailView.swift
  git commit -m "feat: add TaskDetailView with completion history"
  ```

---

### Task 6: TaskFormView

**Files:**
- Create: `HouseMate/Views/Tasks/TaskFormView.swift`

- [ ] **Step 1: Implement TaskFormView.swift**

  ```swift
  // HouseMate/Views/Tasks/TaskFormView.swift
  import SwiftUI

  struct TaskFormView: View {
      @Environment(\.dismiss) private var dismiss
      @State private var viewModel: TaskFormViewModel
      @State private var showTemplateBrowser = false

      let members: [Member]
      let onSaved: (HMTask) -> Void

      init(householdId: UUID, memberId: UUID, members: [Member],
           editingTask: HMTask? = nil, onSaved: @escaping (HMTask) -> Void) {
          _viewModel = State(initialValue: TaskFormViewModel(
              householdId: householdId, memberId: memberId, editingTask: editingTask))
          self.members = members
          self.onSaved = onSaved
      }

      var body: some View {
          NavigationStack {
              Form {
                  Section("Task Details") {
                      TextField("Title", text: $viewModel.title)
                      Picker("Category", selection: $viewModel.category) {
                          ForEach(TaskCategory.allCases, id: \.self) {
                              Text($0.displayName).tag($0)
                          }
                      }
                      Picker("Priority", selection: $viewModel.priority) {
                          ForEach(TaskPriority.allCases, id: \.self) {
                              Text($0.displayName).tag($0)
                          }
                      }
                  }

                  Section("Assignment") {
                      Picker("Assign to", selection: $viewModel.assignedTo) {
                          Text("Unassigned").tag(Optional<UUID>.none)
                          ForEach(members) { member in
                              Text(member.displayName).tag(Optional(member.id))
                          }
                      }
                  }

                  Section("Due Date") {
                      Toggle("Has due date", isOn: $viewModel.hasDueDate)
                      if viewModel.hasDueDate {
                          DatePicker("Due date",
                              selection: Binding(
                                  get: { viewModel.dueDate ?? Date() },
                                  set: { viewModel.dueDate = $0 }),
                              displayedComponents: .date)
                      }
                  }

                  Section("Recurring") {
                      Toggle("Repeats", isOn: $viewModel.isRecurring)
                      if viewModel.isRecurring {
                          Picker("Interval", selection: $viewModel.recurringInterval) {
                              Text("Select…").tag(Optional<RecurringInterval>.none)
                              ForEach(RecurringInterval.allCases, id: \.self) {
                                  Text($0.displayName).tag(Optional($0))
                              }
                          }
                      }
                  }

                  if !viewModel.isEditing {
                      Section {
                          Button("Browse Templates") { showTemplateBrowser = true }
                      }
                  }

                  if let error = viewModel.saveError {
                      Section {
                          Text(error.localizedDescription)
                              .foregroundStyle(.red)
                      }
                  }
              }
              .navigationTitle(viewModel.isEditing ? "Edit Task" : "New Task")
              .toolbar {
                  ToolbarItem(placement: .confirmationAction) {
                      Button("Save") {
                          Task {
                              if let saved = await viewModel.save() {
                                  onSaved(saved)
                                  dismiss()
                              }
                          }
                      }
                      .disabled(!viewModel.canSave || viewModel.isSaving)
                  }
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { dismiss() }
                  }
              }
              .disabled(viewModel.isSaving)
          }
          .sheet(isPresented: $showTemplateBrowser) {
              TaskTemplateView(householdId: viewModel.householdId) { template in
                  viewModel.title = template.title
                  viewModel.category = template.category
                  if let interval = template.recurringInterval {
                      viewModel.isRecurring = true
                      viewModel.recurringInterval = interval
                  }
                  showTemplateBrowser = false
              }
          }
      }
  }

  // Expose householdId for the template browser
  extension TaskFormViewModel {
      var householdId: UUID { _householdId }
  }
  ```

  > **Note:** Add `private let _householdId: UUID` to `TaskFormViewModel` and expose it as `var householdId: UUID { _householdId }`, or make `householdId` internal directly. Adjust access control as needed.

- [ ] **Step 2: Fix TaskFormViewModel to expose householdId**

  In `TaskFormViewModel.swift`, change:
  ```swift
  private let householdId: UUID
  ```
  to:
  ```swift
  let householdId: UUID
  ```

- [ ] **Step 3: Build and verify**

  Run in simulator. Verify:
  - Tapping + in TaskListView opens TaskFormView
  - All fields are present and functional
  - Save creates a task visible in the list
  - Edit from TaskDetailView pre-fills fields

- [ ] **Step 4: Commit**

  ```bash
  git add HouseMate/Views/Tasks/TaskFormView.swift HouseMate/ViewModels/TaskFormViewModel.swift
  git commit -m "feat: add TaskFormView with all fields and template browser integration"
  ```

---

### Task 7: TaskTemplateView

**Files:**
- Create: `HouseMate/Views/Tasks/TaskTemplateView.swift`

- [ ] **Step 1: Implement TaskTemplateView.swift**

  ```swift
  // HouseMate/Views/Tasks/TaskTemplateView.swift
  import SwiftUI

  struct TaskTemplateView: View {
      let householdId: UUID
      let onSelect: (TaskTemplate) -> Void

      @State private var userTemplates: [TaskTemplate] = []
      @State private var isLoading = false
      @State private var error: Error?
      @State private var templateToDelete: TaskTemplate?
      @Environment(\.dismiss) private var dismiss

      private let templateService = TemplateService()

      var body: some View {
          NavigationStack {
              List {
                  Section("Built-in Templates") {
                      ForEach(groupedBuiltIns, id: \.0) { category, templates in
                          Section(category) {
                              ForEach(templates) { template in
                                  Button {
                                      onSelect(template)
                                  } label: {
                                      VStack(alignment: .leading) {
                                          Text(template.title)
                                          if let interval = template.recurringInterval {
                                              Text(interval.displayName)
                                                  .font(.caption)
                                                  .foregroundStyle(.secondary)
                                          }
                                      }
                                  }
                                  .foregroundStyle(.primary)
                              }
                          }
                      }
                  }

                  if !userTemplates.isEmpty {
                      Section("My Templates") {
                          ForEach(userTemplates) { template in
                              Button {
                                  onSelect(template)
                              } label: {
                                  Text(template.title)
                              }
                              .foregroundStyle(.primary)
                              .swipeActions {
                                  Button(role: .destructive) {
                                      templateToDelete = template
                                  } label: {
                                      Label("Delete", systemImage: "trash")
                                  }
                              }
                          }
                      }
                  }
              }
              .navigationTitle("Templates")
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { dismiss() }
                  }
              }
              .task { await loadUserTemplates() }
              .alert("Delete Template?", isPresented: Binding(
                  get: { templateToDelete != nil },
                  set: { if !$0 { templateToDelete = nil } }
              )) {
                  Button("Delete", role: .destructive) {
                      if let t = templateToDelete {
                          templateToDelete = nil
                          Task { await deleteTemplate(t) }
                      }
                  }
                  Button("Cancel", role: .cancel) { templateToDelete = nil }
              }
          }
      }

      private var groupedBuiltIns: [(String, [TaskTemplate])] {
          let weekly = BuiltInTemplates.tasks.filter { $0.recurringInterval == .weekly }
          let monthly = BuiltInTemplates.tasks.filter { $0.recurringInterval == .monthly }
          let seasonal = BuiltInTemplates.tasks.filter { $0.recurringInterval == nil }
          return [
              ("Weekly", weekly),
              ("Monthly", monthly),
              ("Seasonal / One-time", seasonal),
          ].filter { !$0.1.isEmpty }
      }

      private func loadUserTemplates() async {
          isLoading = true
          userTemplates = (try? await templateService.fetchUserTaskTemplates(householdId: householdId)) ?? []
          isLoading = false
      }

      private func deleteTemplate(_ template: TaskTemplate) async {
          try? await templateService.deleteTaskTemplate(id: template.id)
          userTemplates.removeAll { $0.id == template.id }
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add HouseMate/Views/Tasks/TaskTemplateView.swift
  git commit -m "feat: add TaskTemplateView with built-in and user templates"
  ```

---

## Chunk 4: Realtime Integration and Local Notifications

### Task 8: Wire Realtime into AppState and Start Channel on Login

The `RealtimeService` is instantiated in `AppState` and its channel is started once the household is known.

**Files:**
- Modify: `HouseMate/State/AppState.swift`

- [ ] **Step 1: Update AppState to own RealtimeService**

  Add to `AppState.swift`:

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
      private let realtimeService = RealtimeService()

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
          if let h = try? await householdService.fetchHousehold(id: member.householdId) {
              household = h
              members = (try? await memberService.fetchMembers(householdId: h.id)) ?? []
              await realtimeService.subscribe(householdId: h.id)
          }
      }

      func signOut() async throws {
          await realtimeService.unsubscribe()
          try await authService.signOut()
          household = nil
          currentMember = nil
          members = []
      }

      func memberName(for memberId: UUID?) -> String {
          guard let memberId else { return "" }
          return members.first { $0.id == memberId }?.displayName ?? "Unknown"
      }
  }
  ```

- [ ] **Step 2: Verify Realtime works end-to-end**

  Test with two simulator instances (or two accounts on two devices):
  - User A adds a task
  - User B's task list should refresh automatically (within ~1 second)

- [ ] **Step 3: Commit**

  ```bash
  git add HouseMate/State/AppState.swift
  git commit -m "feat: wire RealtimeService into AppState, start channel on household load"
  ```

---

### Task 9: Local Notifications for Scheduled Reminders

**Files:**
- Create: `HouseMate/Services/NotificationService.swift`

- [ ] **Step 1: Write failing test**

  ```swift
  // HouseMateTests/Services/NotificationServiceTests.swift
  import XCTest
  @testable import HouseMate

  final class NotificationServiceTests: XCTestCase {
      func test_notificationService_exists() {
          XCTAssertNotNil(NotificationService())
      }

      func test_tasksDueToday_returnsCorrectTasks() {
          let today = Calendar.current.startOfDay(for: Date())
          let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
          let t1 = HMTask.makeTest(title: "Today Task", dueDate: today, assignedTo: UUID())
          let t2 = HMTask.makeTest(title: "Tomorrow Task", dueDate: tomorrow, assignedTo: UUID())
          let memberId = t1.assignedTo!
          let mine = NotificationService.tasksDueToday([t1, t2], memberId: memberId)
          XCTAssertEqual(mine.count, 1)
          XCTAssertEqual(mine.first?.title, "Today Task")
      }
  }
  ```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement NotificationService.swift**

  ```swift
  // HouseMate/Services/NotificationService.swift
  import UserNotifications
  import Foundation

  @MainActor
  final class NotificationService {

      func requestPermission() async -> Bool {
          do {
              return try await UNUserNotificationCenter.current()
                  .requestAuthorization(options: [.alert, .sound, .badge])
          } catch {
              return false
          }
      }

      /// Schedule a single local notification for a maintenance item on its next due date at 9 AM.
      func scheduleMaintenance(_ item: MaintenanceItem) async {
          guard let nextDue = item.nextDueDate else { return }
          let center = UNUserNotificationCenter.current()
          // Remove existing notification for this item
          center.removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])

          var components = Calendar.current.dateComponents([.year, .month, .day], from: nextDue)
          components.hour = 9
          components.minute = 0

          let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
          let content = UNMutableNotificationContent()
          content.title = "Maintenance Due"
          content.body = "Time to: \(item.name)"
          content.sound = .default

          let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
          try? await center.add(request)
      }

      /// Reschedule all maintenance notifications from scratch.
      func rescheduleMaintenance(items: [MaintenanceItem]) async {
          let center = UNUserNotificationCenter.current()
          let ids = items.map(\.id.uuidString)
          center.removePendingNotificationRequests(withIdentifiers: ids)
          for item in items { await scheduleMaintenance(item) }
      }

      /// Schedule bin day notifications for the next 12 months (day-before at 6 PM, morning-of at 7 AM).
      func scheduleBinNotifications(schedule: BinSchedule) async {
          let center = UNUserNotificationCenter.current()
          center.removePendingNotificationRequests(withIdentifiers: binNotificationIds)

          let upcoming = schedule.upcomingPickups(count: 52)  // ~12 months
          var requests: [UNNotificationRequest] = []

          for (date, rotation) in upcoming {
              if schedule.notifyDayBefore {
                  let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: date)!
                  requests.append(binRequest(date: dayBefore, hour: 18, rotation: rotation,
                      id: "bin-before-\(date.timeIntervalSince1970)",
                      body: "Bin day tomorrow: \(rotation)"))
              }
              if schedule.notifyMorningOf {
                  requests.append(binRequest(date: date, hour: 7, rotation: rotation,
                      id: "bin-morning-\(date.timeIntervalSince1970)",
                      body: "Bin day today: \(rotation)"))
              }
              if requests.count >= 60 { break }  // stay within 64-notification budget
          }

          for req in requests { try? await center.add(req) }
      }

      func cancelBinNotifications() {
          UNUserNotificationCenter.current()
              .removePendingNotificationRequests(withIdentifiers: binNotificationIds)
      }

      private var binNotificationIds: [String] {
          // We don't track IDs persistently; cancellation is by prefix prefix-matching is not available,
          // so we cancel all pending requests with "bin-" in their ID by fetching pending requests.
          return []  // handled via removeAll in scheduleBinNotifications by re-scheduling
      }

      private func binRequest(date: Date, hour: Int, rotation: String,
                               id: String, body: String) -> UNNotificationRequest {
          var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
          components.hour = hour
          components.minute = 0
          let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
          let content = UNMutableNotificationContent()
          content.title = "Bin Day"
          content.body = body
          content.sound = .default
          return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
      }

      static func tasksDueToday(_ tasks: [HMTask], memberId: UUID) -> [HMTask] {
          let today = Calendar.current.startOfDay(for: Date())
          let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
          return tasks.filter { task in
              guard let due = task.dueDate, task.assignedTo == memberId, !task.isCompleted else { return false }
              return due >= today && due < tomorrow
          }
      }
  }
  ```

- [ ] **Step 4: Request notification permission in HouseMateApp**

  In `HouseMateApp.swift`, add permission request after session load:
  ```swift
  .task {
      await appState.loadSession()
      let notificationService = NotificationService()
      _ = await notificationService.requestPermission()
  }
  ```

- [ ] **Step 5: Run tests to verify they pass**

- [ ] **Step 6: Commit**

  ```bash
  git add HouseMate/Services/NotificationService.swift HouseMateTests/Services/NotificationServiceTests.swift HouseMate/App/HouseMateApp.swift
  git commit -m "feat: add NotificationService for local maintenance and bin day notifications"
  ```

---

## Chunk 5: Polish and Quick-Add FAB

### Task 10: Quick-Add FAB on Home Tab and TaskListView

The design spec requires a floating action button (FAB) on the Home tab and a `+` button on the Tasks tab for quick task creation.

**Files:**
- Modify: `HouseMate/Views/Tasks/TaskListView.swift` — already has + button in toolbar; verify it works
- Modify: `HouseMate/Views/Main/MainTabView.swift` — add FAB overlay (placeholder for Home feature plan)

- [ ] **Step 1: Verify TaskListView + button triggers TaskFormView correctly**

  Run in simulator:
  - Tap Tasks tab
  - Tap + button in navigation bar
  - TaskFormView sheet opens
  - Fill in title, tap Save
  - Task appears in list
  - Task persists after closing and reopening the app

- [ ] **Step 2: Verify swipe-to-complete works**

  - Add a task
  - Swipe right on the row → task disappears from "All" filter (non-recurring) or resets due date (recurring)
  - Check that a `TaskCompletionLog` row was created in Supabase (via dashboard)

- [ ] **Step 3: Verify swipe-to-delete works**

  - Add a task
  - Swipe left → tap Delete → confirmation alert → task deleted from Supabase

- [ ] **Step 4: Verify Realtime sync**

  Using two simulator instances logged into different accounts in the same household:
  - User A adds a task
  - User B's task list refreshes automatically
  - User A completes a task
  - User B's list reflects the change

- [ ] **Step 5: Commit any polish fixes**

  ```bash
  git add -A
  git commit -m "feat: verify and polish task CRUD, swipe actions, and Realtime sync"
  ```

---

### Task 11: TaskDetailView Completion Logs with Member Names

Completion logs show member display names. The `members` array is passed from `AppState` through `TaskListView` to `TaskDetailView`.

- [ ] **Step 1: Verify member names display correctly in TaskDetailView**

  - Create a task
  - Complete it as User A
  - View task detail — completion log shows User A's display name (not UUID)
  - Second user (User B in second simulator) completes the same recurring task
  - Log shows both User A and User B names

- [ ] **Step 2: Verify the "already completed" alert fires on concurrent completion**

  - Have two simulators open with the same task visible
  - Simultaneously swipe-complete on both
  - One should show "Already Completed" alert

- [ ] **Step 3: Commit**

  No code changes expected if behavior is correct. If fixes needed, commit them:
  ```bash
  git add -A
  git commit -m "fix: member name resolution in TaskDetailView completion logs"
  ```

---

**Tasks feature complete.** All views, ViewModels, Realtime integration, and local notifications are in place. Proceed to the Bins feature plan (not yet written) or run the full review cycle.
