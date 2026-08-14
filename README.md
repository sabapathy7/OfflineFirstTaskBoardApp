# Offline First Task Board
Kanban board (To Do / In Progress / Done) that keeps working offline. Local Core Data is the source of truth. Firestore is a remote API behind an outbox, not the UI's database.
## Run
1. Clone this repo.
2. Open `OfflineFirstTaskBoard.xcodeproj` in Xcode 26+ (Swift 6, Approachable Concurrency).
3. Select the `OfflineFirstTaskBoard` scheme and an iOS 17 simulator.
4. ⌘R.
`GoogleService-Info.plist` is in the app target. No Firebase console setup.
## Notes for reviewers
- Firestore persistence is off. The app owns the outbox.
- Security rules are open on `boards/demo/tasks/{taskId}` so two devices can share one board. Take-home only; no Auth.
- Force-offline is a Debug flag in the app, not Airplane Mode.
## Status
Hour 0 scaffolding. Domain, sync engine, and board UI are next.
