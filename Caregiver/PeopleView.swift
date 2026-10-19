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
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        DippedStage(fill: Color.ink, scheme: .dark) {
            VStack(spacing: 16) {
                Text("Sharing")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.card)
                Text("They add you. You don’t invite from here.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.mute)

                if let errorText {
                    Text(errorText)
                        .font(AppFont.captionMedium)
                        .foregroundStyle(Color.alert)
                    Button("Try again", action: load)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.flare)
                }

                if busy && caregivers.isEmpty {
                    Spacer()
                    Text("Wait")
                        .font(AppFont.poster)
                        .foregroundStyle(Color.card)
                        .tracking(AppTracking.poster)
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                    Spacer()
                } else if caregivers.isEmpty && errorText == nil {
                    Spacer()
                    Text("None")
                        .font(AppFont.poster)
                        .foregroundStyle(Color.card)
                        .tracking(AppTracking.poster)
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                    Text("Nobody is watching yet.")
                        .font(AppFont.body)
                        .foregroundStyle(Color.mute)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(caregivers.enumerated()), id: \.element.id) { index, person in
                                personSlab(person, index: index)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
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
        DippedStage(fill: Color.ink, scheme: .dark) {
            VStack(spacing: 16) {
                Text("Sharing")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.card)
                Text("They see this day.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.mute)

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
                    Text("Add a patient with their email.")
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
                note = "Linked. They get a mail if that address is already a patient."
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
