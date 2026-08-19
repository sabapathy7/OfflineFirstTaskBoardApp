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

**Sync.** `sync()` pushes `.pending` / `.failed`, then pulls. Both directions are last-write-wins on `updatedAt` (see Sync rules). Synced locals missing on the server are deleted (remote tombstone). Tests inject `MockTaskAPI` + in-memory Core Data.

## Firebase

- Firestore implements `TaskAPI` only (`fetchAll` / `create` / `update` / `delete` / `remoteChanges`).
- Path: `boards/demo/tasks/{id}`. No Auth. Open rules on that path so two simulators share one board (take-home only).
- `update` and `delete` run in a **Firestore transaction**: the write is skipped when the server copy has a newer `updatedAt`. An older edit can never clobber a newer one, even if both devices sync at the same moment.
- `remoteChanges` wraps a **snapshot listener** as an `AsyncStream<Void>`; `metadata.hasPendingWrites` filters out the echo of our own writes.
- `MemoryCacheSettings` is on so Firestore’s disk cache does not become a second source of truth. The app owns the outbox; pull uses `getDocuments(source: .server)`.
- `sortOrder` is read as `NSNumber` (Firestore’s type), not `Int`.

## Sync rules

**Sync is automatic — there is no “Sync Now” step.** It runs:

- after every local write (create / edit / move / reorder / delete / archive / restore / subtask change),
- when a Firestore snapshot listener reports a change from another device (`TaskAPI.remoteChanges`),
- when `NWPathMonitor` reports the network came back,
- when the app returns to the foreground,
- and once at launch. The banner stays tappable as a manual retry, nothing more.

Requests that arrive while a sync is running are coalesced into one extra pass, so a remote change landing mid-sync is never dropped.

**Conflicts are last-write-wins on `updatedAt`, in both directions:**

- **Push**: `update` / `delete` are guarded server-side (Firestore transaction; mirrored in `MockTaskAPI`). Pushing an edit older than the server copy is a no-op instead of a clobber.
- **Pull**: a newer remote wins over any local row; a `.pending` / `.failed` local row survives only while it is still the newest edit (`BoardRules.shouldApplyRemote`). The pull after each push also repairs the device whose edit lost.

So when the same task is edited on two devices, both converge on the **latest edit** — which device synced first no longer matters (`ConflictResolutionTests` proves both orders). Deletes carry their tombstone time: a newer edit beats an older delete (the task comes back), a newer delete beats an older edit.

A failed `TaskAPI` call still becomes **Sync failed** (and a red `!` on the card). Writes still succeed locally while offline.

## UI

- Segmented **To Do / In Progress / Done** (not a paging swipe — that stole row swipes).
- Swipe a **row** left to Move or Delete; swipe right to go Back. Not cross-column drag.
- Tap a card to edit. Nav-bar **Edit** reorders inside one column.
- Banner: Offline / Syncing / Last synced / Sync failed — **status, not a required control**; sync runs by itself. Tapping it is just a manual retry. Orange ● = pending; red ! = failed (tap to retry).

## Demo

**One simulator:** ⌘R → seed cards (●) → Syncing → Last synced, all hands-off. Add/move/delete → the banner cycles by itself and dots clear. Airplane Mode → add a card → Offline → network on → syncs on its own → Last synced. Confirm in Firestore: project `offlinetaskdrmarrow`, `boards/demo/tasks`.

**Two simulators (live propagation):** run A and B side by side. Add or move a card on A → it appears on B in about a second, no taps on B (snapshot listener → pull).

**Conflict demo — the follow-up scenario:** put **both** simulators in Airplane Mode. Edit the *same task's* title on A, then edit it on B (B is now the later edit). Turn the network back on in either order — whichever device reconnects first no longer decides. Both devices and Firestore converge on **B's title**, because B's edit is newest. Swap the edit order and A wins instead.

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
- Last-write-wins compares **device wall clocks**; a device with a badly skewed clock wins or loses unfairly. Server-assigned timestamps or vector clocks would fix this.
- Conflict resolution is whole-task: two devices editing *different fields* of the same task still resolve to the newer edit, not a field merge.
- Server deletes are hard deletes, so there is no timestamp left to compare against: a not-yet-synced edit resurrects a concurrently deleted task even when the delete was newer. Server-side tombstone documents would close this edge.
- UI tests hit the real board and leave extra cards on that simulator.

## Time and AI

Built in about a day as a take-home, with Cursor used for scaffolding, Swift 6 isolation, Firestore adapter details, and tests. Domain rules, outbox shape, and merge policy were specified and reviewed by hand.
