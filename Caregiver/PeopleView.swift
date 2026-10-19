import SwiftUI
import UIKit

struct PeopleView: View {
    @EnvironmentObject private var session: SessionStore

    private var isCaregiver: Bool { session.user?.role == "CAREGIVER" }

    var body: some View {
        Group {
            if isCaregiver {
                CaregiverPeopleView()
            } else {
                PatientPeopleView()
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

private struct PatientPeopleView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var caregivers: [User] = []
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("People")
                    .font(AppFont.largeTitle)
                    .foregroundStyle(Color.ink)
                    .tracking(AppTracking.largeTitle)

                Text("Family who watch your day. They add you with your email. You don’t invite anyone from here.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .lineSpacing(4)

                if let errorText {
                    Text(errorText)
                        .font(AppFont.captionMedium)
                        .foregroundStyle(Color.alert)
                    Button("Try again", action: load)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.flare)
                }

                if busy && caregivers.isEmpty {
                    Text("Loading…")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.mute)
                } else if caregivers.isEmpty && errorText == nil {
                    Text("Nobody is watching yet.")
                        .font(AppFont.body)
                        .foregroundStyle(Color.mute)
                }

                ForEach(caregivers) { person in
                    personCard(person, accent: Color.acid, role: "Caregiver")
                }
            }
            .padding(20)
        }
        .onAppear(perform: load)
    }

    private func load() {
        errorText = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                caregivers = try await CaregiverService(client: session.client()).caregivers()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

private struct CaregiverPeopleView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var email = ""
    @State private var patients: [User] = []
    @State private var busy = false
    @State private var adding = false
    @State private var removingId: String?
    @State private var pendingRemove: User?
    @State private var errorText: String?
    @State private var note: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("People")
                    .font(AppFont.largeTitle)
                    .foregroundStyle(Color.ink)
                    .tracking(AppTracking.largeTitle)

                Text("Add a patient with their email. They must already have a Graph Health patient account. They get a mail after the link succeeds.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Patient email")
                        .font(AppFont.label)
                        .foregroundStyle(Color.mute)
                    TextField("", text: $email, prompt: Text("Email").foregroundStyle(Color.mute))
                        .font(AppFont.body)
                        .foregroundStyle(Color.ink)
                        .tint(Color.flare)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .padding(14)
                        .background(Color.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.hairline, lineWidth: 1)
                        )
                }

                if let errorText {
                    Text(errorText)
                        .font(AppFont.captionMedium)
                        .foregroundStyle(Color.alert)
                }
                if let note {
                    Text(note)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.mute)
                }

                Button(action: add) {
                    Text(adding ? "Working…" : "Add patient")
                        .font(AppFont.button)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.flare)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(adding || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if busy && patients.isEmpty {
                    Text("Loading…")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.mute)
                }

                if !patients.isEmpty {
                    Text("Watching")
                        .font(AppFont.section)
                        .foregroundStyle(Color.ink)
                        .tracking(AppTracking.section)
                        .padding(.top, 8)

                    ForEach(patients) { person in
                        personCard(
                            person,
                            accent: Color.flare,
                            role: "Patient",
                            removeTitle: removingId == person.id ? "Removing…" : "Stop watching",
                            onRemove: { pendingRemove = person }
                        )
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            UITextField.appearance().textColor = UIColor(Color.ink)
            UITextField.appearance().tintColor = UIColor(Color.flare)
            load()
        }
        .confirmationDialog(
            "Stop watching \(pendingRemove?.displayName ?? "this patient")?",
            isPresented: Binding(
                get: { pendingRemove != nil },
                set: { if !$0 { pendingRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Stop watching", role: .destructive) {
                if let person = pendingRemove { stop(person) }
                pendingRemove = nil
            }
            Button("Keep them", role: .cancel) { pendingRemove = nil }
        } message: {
            Text("You won’t see their day until you add them again.")
        }
    }

    private func load() {
        errorText = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                patients = try await CaregiverService(client: session.client()).monitoredPatients()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func add() {
        errorText = nil
        note = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == session.user?.email.lowercased() {
            errorText = "That’s your email. A patient needs their own."
            return
        }
        adding = true
        Task {
            defer { adding = false }
            do {
                let person = try await CaregiverService(client: session.client()).linkPatient(email: trimmed)
                if !patients.contains(where: { $0.id == person.id }) {
                    patients.append(person)
                }
                email = ""
                note = "Linked. They get a Graph Health email if that address is already a patient."
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func stop(_ person: User) {
        errorText = nil
        note = nil
        removingId = person.id
        Task {
            defer { removingId = nil }
            do {
                try await CaregiverService(client: session.client()).stopMonitoring(patientId: person.id)
                patients.removeAll { $0.id == person.id }
            } catch let err as GraphQLError where err.extensions?.code == "not_found" {
                patients.removeAll { $0.id == person.id }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

private func personCard(
    _ person: User,
    accent: Color,
    role: String,
    removeTitle: String? = nil,
    onRemove: (() -> Void)? = nil
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(person.displayName)
            .font(AppFont.cardTitle)
            .foregroundStyle(Color.ink)
            .tracking(AppTracking.section)
        Text(person.email)
            .font(AppFont.body)
            .foregroundStyle(Color.mute)
        Text(role)
            .font(AppFont.chip)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accent)
            .clipShape(Capsule())
        if let removeTitle, let onRemove {
            Button(removeTitle, action: onRemove)
                .font(AppFont.bodyMedium)
                .foregroundStyle(Color.alert)
        }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.card)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.hairline, lineWidth: 1)
    )
}
