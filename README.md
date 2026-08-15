# Offline First Task Board

Kanban board (To Do / In Progress / Done) that keeps working with no network. **Core Data is the source of truth.** Firestore is a remote `TaskAPI` behind an outbox, not the UI’s database.

## Run

1. Clone this repo.
2. Open `OfflineFirstTaskBoard.xcodeproj` in Xcode 26+ (Swift 6, Approachable Concurrency).
3. Select the `OfflineFirstTaskBoard` scheme and an iOS 17+ simulator.
4. ⌘R.

`GoogleService-Info.plist` is already in the app target. No Firebase console steps, no login.

## Architecture

Three layers. No UseCases. The UI never talks to Firestore.

```
BoardView → BoardViewModel → TaskRepository
                                ├─ CoreDataTaskStore  → Core Data (source of truth)
                                ├─ SyncEngine         → push pending/failed, then pull
                                └─ TaskAPI            → FirebaseTaskAPI / MockTaskAPI
```

| Layer | What |
|---|---|
| **Domain** | `TaskItem`, `TaskStatus`, `SyncStatus`, `BoardRules`, `TaskRepository`, `TaskAPI` — all `nonisolated` so tests and the sync actor are not stuck on the main actor |
| **Data** | `CoreDataTaskStore` maps `TaskEntity` ↔ `TaskItem`. `TaskRepositoryImpl` is an actor: every write is local-first (`.pending`). `SyncEngine` is push then pull. `FirebaseTaskAPI` / `MockTaskAPI` implement `TaskAPI` |
| **Features** | `BoardView` / `BoardViewModel`, `TaskCard`, `SyncBanner`, `EditorSheet`. The view model calls the repository only |

**Why no UseCases.** The repository *is* the use case. Create / move / delete / sync are already the verbs. Extra types would only forward to the same actor.

**Local-first.** `create` / `edit` / `move` / `reorder` / `delete` write Core Data immediately. Delete: never-on-remote is dropped; already-on-remote is a tombstone (`.pending` + `isDeleted`). `loadTasks` returns local if anything is there; only an empty store hydrates from Firestore.

**Sync.** `sync()` pushes `.pending` / `.failed`, then pulls. Pull skips dirty local rows. Synced locals missing on the server are deleted (remote tombstone). Tests inject `MockTaskAPI` + in-memory Core Data.

## Firebase

- Firestore implements `TaskAPI` only (`fetchAll` / `create` / `update` / `delete`).
- Path: `boards/demo/tasks/{id}`. No Auth. Open rules on that path so two simulators share one board (take-home only).
- `MemoryCacheSettings` is on so Firestore’s disk cache does not become a second source of truth. The app owns the outbox; pull uses `getDocuments(source: .server)`.
- `sortOrder` is read as `NSNumber` (Firestore’s type), not `Int`.

## Sync rules

Last-write-wins, **dirty local wins**: pull does not overwrite `.pending` or `.failed`. After fetch, local rows that are synced, exist on remote, and are missing from Firestore are deleted (remote tombstone). Pending/failed rows stay.

`NWPathMonitor` drives the **Offline** banner when the path is unsatisfied. A failed `TaskAPI` call still becomes **Sync failed** (and a red `!` on the card). Writes still succeed locally while offline.

## UI

- Segmented **To Do / In Progress / Done** (not a paging swipe — that stole row swipes).
- Swipe a **row** left to Move or Delete; swipe right to go Back. Not cross-column drag.
- Tap a card to edit. Nav-bar **Edit** reorders inside one column.
- Banner: Offline / Syncing / Last synced / Sync failed. Tap to sync. Orange ● = pending; red ! = failed (tap to retry).

## Demo

**One simulator:** ⌘R → seed cards (●) → wait for Last synced → add/move/delete → dots clear. Airplane Mode → add a card → Offline (or Sync failed) → network on → tap banner → Last synced. Confirm in Firestore: project `offlinetaskdrmarrow`, `boards/demo/tasks`.

**Two simulators:** Sync on A. On B, **delete the app** (wipe Core Data only), then ⌘R. Empty local hydrates from Firestore. Delete on A + sync; pull on B removes the card. Edit a title on B (pending) + sync; A’s pull keeps B’s title.

## Screenshots

<table>
  <tr>
    <td align="center" valign="top">
      <img src="https://github.com/user-attachments/assets/c16eaadd-6da9-409d-92a3-ed1c2d50c50c" width="160" alt="Board with To Do selected and Last synced"><br>
      Board + sync banner
    </td>
    <td align="center" valign="top">
      <img src="https://github.com/user-attachments/assets/303147ca-ae47-428a-a020-76ea01374ef4" width="160" alt="To Do row swiped left showing Move and Delete"><br>
      Swipe: Move / Delete
    </td>
    <td align="center" valign="top">
      <img src="https://github.com/user-attachments/assets/0e3eecba-8545-413a-b039-420fa7f12dcf" width="160" alt="Board showing Offline banner"><br>
      Airplane Mode → Offline
    </td>
    <td align="center" valign="top">
      <img src="https://github.com/user-attachments/assets/b3961110-5867-480e-a8aa-f79b33f231ef" width="160" alt="New task editor"><br>
      Add a task
    </td>
    <td align="center" valign="top">
      <img src="https://github.com/user-attachments/assets/ecdf706f-1d35-4e09-b0dc-883d00afad8e" width="160" alt="In Progress column after sync"><br>
      In Progress, Last synced
    </td>
  </tr>
</table>

## Limitations

- Shared demo board, no Auth, open rules.
- No undo after delete, no conflict glyph, no cross-column drag.
- Second device that already seeded will not pull until the app is deleted.
- UI tests hit the real board and leave extra cards on that simulator.

## Time and AI

Built in about a day as a take-home, with Cursor used for scaffolding, Swift 6 isolation, Firestore adapter details, and tests. Domain rules, outbox shape, and merge policy were specified and reviewed by hand.
