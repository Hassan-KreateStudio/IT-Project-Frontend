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
    }
}

// MARK: - Patient

private struct PatientPeopleView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var caregivers: [User] = []
    @State private var requests: [CaregiverRequest] = []
    @State private var busy = false
    @State private var answering: String?
    @State private var errorText: String?

    var body: some View {
        LightStage {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sharing")
                    .font(AppFont.largeTitle)
                    .tracking(AppTracking.largeTitle)
                    .foregroundStyle(Color.ink)
                Text("You decide who sees your day.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
            }

            if let errorText {
                HStack(spacing: 8) {
                    Text(errorText)
                        .font(AppFont.captionMedium)
                        .foregroundStyle(Color.alert)
                    Spacer(minLength: 0)
                    Button("Try again", action: load)
                        .font(AppFont.chip)
                        .foregroundStyle(Color.flare)
                }
                .panel(padding: 12)
            }

            if !requests.isEmpty {
                Text("Waiting on you").sectionHeading()

                ForEach(requests) { request in
                    requestCard(request)
                }
            }

            Text(requests.isEmpty ? "Watching you" : "Already watching")
                .sectionHeading()
                .padding(.top, requests.isEmpty ? 0 : 4)

            if busy && caregivers.isEmpty {
                Text("Checking…")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .panel(padding: 16)
            } else if caregivers.isEmpty {
                Text("Nobody is watching yet. A caregiver asks, and they appear here for you to accept.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .fixedSize(horizontal: false, vertical: true)
                    .panel(padding: 16)
            } else {
                ForEach(caregivers) { person in
                    caregiverRow(person)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func requestCard(_ request: CaregiverRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                initialsBadge(request.caregiver.displayName, fill: Color.acid)
                VStack(alignment: .leading, spacing: 1) {
                    Text(request.caregiver.displayName)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.ink)
                    Text(askedPhrase(request))
                        .font(AppFont.chip)
                        .foregroundStyle(Color.mute)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    answer(request, accept: false)
                } label: {
                    Text("Decline")
                        .font(AppFont.chip)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.mist)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(answering != nil)

                Button {
                    answer(request, accept: true)
                } label: {
                    Text(answering == request.id ? "Saving…" : "Accept")
                        .font(AppFont.chip)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.acid)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(answering != nil)
            }
        }
        .panel()
    }

    private func caregiverRow(_ person: User) -> some View {
        HStack(spacing: 10) {
            initialsBadge(person.displayName, fill: Color.mist, ink: Color.ink)
            VStack(alignment: .leading, spacing: 1) {
                Text(person.displayName)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.ink)
                Text("Can see your day")
                    .font(AppFont.chip)
                    .foregroundStyle(Color.mute)
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                revoke(person)
            } label: {
                Text("Remove")
                    .font(AppFont.chip)
                    .foregroundStyle(Color.alert)
            }
            .buttonStyle(.plain)
        }
        .panel(padding: 13, radius: 16)
        .contextMenu {
            Button("Stop sharing", role: .destructive) { revoke(person) }
        }
    }

    private func initialsBadge(_ name: String, fill: Color, ink: Color = Color.ink) -> some View {
        Text(initials(name))
            .font(.custom("BricolageGrotesque-ExtraBold", size: 12))
            .foregroundStyle(ink)
            .frame(width: 34, height: 34)
            .background(fill)
            .clipShape(Circle())
    }

    private func askedPhrase(_ request: CaregiverRequest) -> String {
        guard let date = request.askedAt else { return "Wants to see your day" }
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 60 { return "Asked \(max(minutes, 1))m ago" }
        let hours = minutes / 60
        if hours < 24 { return "Asked \(hours)h ago" }
        return "Asked \(hours / 24)d ago"
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func load() {
        errorText = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                let service = CaregiverService(client: session.client())
                async let watchers = service.caregivers()
                async let pending = service.caregiverRequests()
                caregivers = try await watchers
                requests = try await pending
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func answer(_ request: CaregiverRequest, accept: Bool) {
        errorText = nil
        answering = request.id
        Task {
            defer { answering = nil }
            do {
                try await CaregiverService(client: session.client())
                    .respond(caregiverId: request.caregiver.id, accept: accept)
                requests.removeAll { $0.id == request.id }
                if accept {
                    caregivers.append(request.caregiver)
                    caregivers.sort { $0.displayName < $1.displayName }
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func revoke(_ person: User) {
        errorText = nil
        Task {
            do {
                try await CaregiverService(client: session.client()).revoke(caregiverId: person.id)
                caregivers.removeAll { $0.id == person.id }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

// MARK: - Caregiver

private struct CaregiverPeopleView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var email = ""
    @State private var patients: [User] = []
    @State private var waiting: [User] = []
    @State private var busy = false
    @State private var adding = false
    @State private var removingId: String?
    @State private var pendingRemove: User?
    @State private var errorText: String?
    @State private var note: String?
    @FocusState private var emailFocused: Bool

    var body: some View {
        LightStage {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sharing")
                    .font(AppFont.largeTitle)
                    .tracking(AppTracking.largeTitle)
                    .foregroundStyle(Color.ink)
                Text("They approve before you see anything.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
            }

            if let errorText {
                Text(errorText)
                    .font(AppFont.captionMedium)
                    .foregroundStyle(Color.alert)
                    .panel(padding: 12)
            }
            if let note {
                Text(note)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.mute)
                    .panel(padding: 12)
            }

            Text("Ask a patient").sectionHeading()

            VStack(alignment: .leading, spacing: 10) {
                TextField("", text: $email, prompt: Text("Patient email").foregroundStyle(Color.mute))
                    .focused($emailFocused)
                    .submitLabel(.send)
                    .onSubmit { add() }
                    .font(AppFont.body)
                    .foregroundStyle(Color.ink)
                    .tint(Color.flare)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .padding(12)
                    .background(Color.mist)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(action: add) {
                    Text(adding ? "Working…" : "Send request")
                        .font(AppFont.button)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.flare)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(adding || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .panel()

            if !waiting.isEmpty {
                Text("Waiting on them").sectionHeading().padding(.top, 4)
                ForEach(waiting) { person in
                    HStack(spacing: 10) {
                        InitialsDot(name: person.displayName, fill: Color.mist)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(person.displayName)
                                .font(AppFont.bodyMedium)
                                .foregroundStyle(Color.ink)
                            Text("Hasn’t answered yet")
                                .font(AppFont.chip)
                                .foregroundStyle(Color.mute)
                        }
                        Spacer(minLength: 0)
                    }
                    .panel(padding: 13, radius: 16)
                }
            }

            Text("Watching").sectionHeading().padding(.top, 4)

            if busy && patients.isEmpty {
                Text("Loading…")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .panel(padding: 16)
            } else if patients.isEmpty {
                Text("Nobody yet. Send a request above and it starts once they accept.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .fixedSize(horizontal: false, vertical: true)
                    .panel(padding: 16)
            } else {
                ForEach(patients) { person in
                    HStack(spacing: 10) {
                        InitialsDot(name: person.displayName, fill: Color.acid)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(person.displayName)
                                .font(AppFont.bodyMedium)
                                .foregroundStyle(Color.ink)
                            Text(person.email)
                                .font(AppFont.chip)
                                .foregroundStyle(Color.mute)
                        }
                        Spacer(minLength: 0)
                        if removingId == person.id {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .panel(padding: 13, radius: 16)
                    .contextMenu {
                        Button("Stop watching", role: .destructive) { pendingRemove = person }
                    }
                }

                Text("Hold a name to stop watching.")
                    .font(AppFont.chip)
                    .foregroundStyle(Color.mute)
                    .padding(.top, 2)
            }
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
            Text("You won’t see their day until they accept you again.")
        }
    }

    private func load() {
        errorText = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                let service = CaregiverService(client: session.client())
                async let accepted = service.monitoredPatients()
                async let pending = service.pendingPatients()
                patients = try await accepted
                waiting = try await pending
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func add() {
        emailFocused = false
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
                let person = try await CaregiverService(client: session.client()).requestAccess(email: trimmed)
                if !waiting.contains(where: { $0.id == person.id }) {
                    waiting.append(person)
                }
                email = ""
                note = "Asked. \(person.displayName) approves before you can see their day."
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

private struct InitialsDot: View {
    var name: String
    var fill: Color

    var body: some View {
        Text(initials)
            .font(.custom("BricolageGrotesque-ExtraBold", size: 12))
            .foregroundStyle(Color.ink)
            .frame(width: 34, height: 34)
            .background(fill)
            .clipShape(Circle())
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
