# IT Project Frontend

iPhone SwiftUI app for the IT Project backend. The Apple Watch writes HealthKit on the phone. This app reads HealthKit and talks to GraphQL. The Watch never calls the API.

## Talks to

`https://it-project-backend-aldq.onrender.com/graphql`

## Layout

- `App/` — `@main` and root (logged out vs logged in)
- `Config/` — API base URL
- `GraphQL/` — one POST client (Bearer JWT)
- `Auth/` — register, login, me
- `Caregiver/` — link + monitored patients
- `Activity/` — `syncActivity`
- `Graph/` — local SwiftData week (`Person` → `Day` → `Activity`)
- `Intelligence/` — on-device model on the local week graph
- `HealthKit/` — phone samples → `sourceId` payloads
- `Analysis/` — dashboard, including glucose the server fills in
- `Shared/` — API shapes (`User`, dashboard types)

Open `IT-Project-Frontend.xcodeproj` in Xcode. iPhone only.

## Run

Xcode → iPhone simulator or device. There is no Watch target in this repo.
