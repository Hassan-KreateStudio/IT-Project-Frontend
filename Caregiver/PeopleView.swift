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

private struct PatientPeopleView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var caregivers: [User] = []
    @State private var requests: [CaregiverRequest] = []
    @State private var busy = false
    @State private var answering: String?
    @State private var errorText: String?

    var body: some View {
        DippedStage(fill: Color.ink, scheme: .dark) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sharing")
                            .font(AppFont.largeTitle)
                            .foregroundStyle(Color.card)
                        Text("You decide who sees your day.")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.mute)
                    }
                    .padding(.bottom, 16)

                    if let errorText {
                        Text(errorText)
                            .font(AppFont.captionMedium)
                            .foregroundStyle(Color.alert)
                            .padding(.bottom, 12)
                        Button("Try again", action: load)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.flare)
                            .padding(.bottom, 12)
                    }

                    if !requests.isEmpty {
                        sectionLabel("Waiting on you")
                        ForEach(requests) { request in
                            requestCard(request)
                                .padding(.bottom, 10)
                        }
                    }

                    sectionLabel(requests.isEmpty ? "Watching you" : "Already watching")

                    if busy && caregivers.isEmpty {
                        Text("Checking…")
                            .font(AppFont.body)
                            .foregroundStyle(Color.mute)
                            .padding(.vertical, 20)
                    } else if caregivers.isEmpty {
                        Text("Nobody is watching yet.")
                            .font(AppFont.body)
                            .foregroundStyle(Color.mute)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(caregivers) { person in
                            caregiverRow(person)
                                .padding(.bottom, 8)
                        }
                        Text("Hold a name to stop sharing.")
                            .font(AppFont.chip)
                            .foregroundStyle(Color.mute)
                            .padding(.top, 6)
                    }
                }
            }
        }
        .onAppear(perform: load)
    }

    private func requestCard(_ request: CaregiverRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(initials(request.caregiver.displayName))
                    .font(.custom("BricolageGrotesque-ExtraBold", size: 13))
                    .foregroundStyle(Color.ink)
                    .frame(width: 38, height: 38)
                    .background(Color.acid)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.caregiver.displayName)
                        .font(.custom("BricolageGrotesque-ExtraBold", size: 17))
                        .foregroundStyle(Color.card)
                    Text(askedPhrase(request))
                        .font(AppFont.chip)
                        .foregroundStyle(Color.mute)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    answer(request, accept: false)
                } label: {
                    Text("Decline")
                        .font(AppFont.button)
                        .foregroundStyle(Color.card)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.dusk)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(answering != nil)

                Button {
                    answer(request, accept: true)
                } label: {
                    Text(answering == request.id ? "Saving…" : "Accept")
                        .font(AppFont.button)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.acid)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(answering != nil)
            }
        }
        .padding(15)
        .background(Color.night)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func caregiverRow(_ person: User) -> some View {
        HStack(spacing: 10) {
            Text(initials(person.displayName))
                .font(.custom("BricolageGrotesque-ExtraBold", size: 12))
                .foregroundStyle(Color.card)
                .frame(width: 34, height: 34)
                .background(Color.dusk)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(person.displayName)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.card)
                Text("Can see your day")
                    .font(AppFont.chip)
                    .foregroundStyle(Color.mute)
            }
            Spacer()
            Button(role: .destructive) {
                revoke(person)
            } label: {
                Text("Remove")
                    .font(AppFont.chip)
                    .foregroundStyle(Color.alert)
            }
            .buttonStyle(.plain)
        }
        .padding(13)
        .background(Color.night)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button("Stop sharing", role: .destructive) { revoke(person) }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.chip)
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(Color.mute)
            .padding(.bottom, 8)
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

    var body: some View {
        DippedStage(fill: Color.ink, scheme: .dark) {
            VStack(spacing: 16) {
                Text("Sharing")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.card)
                Text("They approve before you see anything.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.mute)

                if !waiting.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(waiting) { person in
                            Text("\(person.displayName) hasn’t answered yet")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.mute)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if busy && patients.isEmpty {
                    Spacer()
                    Text("Wait")
                        .font(AppFont.poster)
                        .foregroundStyle(Color.card)
                        .tracking(AppTracking.poster)
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                    Spacer()
                } else if patients.isEmpty {
                    Spacer()
                    Text("None")
                        .font(AppFont.poster)
                        .foregroundStyle(Color.card)
                        .tracking(AppTracking.poster)
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                    Text("Ask a patient with their email.")
                        .font(AppFont.body)
                        .foregroundStyle(Color.mute)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(patients.enumerated()), id: \.element.id) { index, person in
                                personSlab(person, index: index)
                                    .contextMenu {
                                        Button("Stop watching", role: .destructive) {
                                            pendingRemove = person
                                        }
                                    }
                                    .disabled(removingId == person.id)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    Text("Hold a name to stop.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.mute)
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

                TextField("", text: $email, prompt: Text("Patient email").foregroundStyle(Color.mute))
                    .font(AppFont.body)
                    .foregroundStyle(Color.card)
                    .tint(Color.flare)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .padding(14)
                    .background(Color.night)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button(action: add) {
                    Text(adding ? "Working…" : "Add")
                        .font(AppFont.button)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.flare)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(adding || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            UITextField.appearance().textColor = UIColor(Color.card)
            UITextField.appearance().tintColor = UIColor(Color.flare)
            load()
        }
        .onDisappear {
            UITextField.appearance().textColor = UIColor(Color.ink)
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

private func personSlab(_ person: User, index: Int) -> some View {
    Text(person.displayName.firstName)
        .font(AppFont.slab)
        .foregroundStyle(Color.ink)
        .tracking(AppTracking.slab)
        .minimumScaleFactor(0.3)
        .lineLimit(1)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .padding(.horizontal, 24)
        .background(fanFill(index))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityLabel(person.displayName)
}

private func fanFill(_ index: Int) -> Color {
    switch index % 3 {
    case 0: return Color.flare
    case 1: return Color.acid
    default: return Color.card
    }
}
