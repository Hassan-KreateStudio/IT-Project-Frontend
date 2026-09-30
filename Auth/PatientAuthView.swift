import SwiftUI

struct PatientAuthView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var isRegister = true
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(isRegister ? "Create account" : "Sign in")
                    .font(AppFont.largeTitle)
                    .foregroundStyle(Color.ink)
                    .tracking(AppTracking.largeTitle)

                Text(isRegister ? "This account keeps your activity and glucose." : "Welcome back.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)

                Picker("Mode", selection: $isRegister) {
                    Text("Create").tag(true)
                    Text("Sign in").tag(false)
                }
                .pickerStyle(.segmented)
                .font(AppFont.bodyMedium)

                VStack(spacing: 12) {
                    if isRegister {
                        field("Name", text: $displayName)
                    }
                    field("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    field("Password", text: $password, secure: true)
                }

                if let errorText {
                    Text(errorText)
                        .font(AppFont.captionMedium)
                        .foregroundStyle(Color.alert)
                }

                Button(action: submit) {
                    Text(isRegister ? "Create account" : "Sign in")
                        .font(AppFont.button)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.flare)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(busy)
            }
            .padding(20)
        }
        .background(Color.canvas.ignoresSafeArea())
        .preferredColorScheme(.light)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ title: String, text: Binding<String>, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(Color.mute)
            Group {
                if secure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                }
            }
            .font(AppFont.body)
            .padding(14)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
        }
    }

    private func submit() {
        errorText = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                let auth = AuthService(client: GraphQLClient())
                let payload: AuthPayload
                if isRegister {
                    payload = try await auth.register(
                        email: email,
                        password: password,
                        displayName: displayName,
                        role: "PATIENT"
                    )
                } else {
                    payload = try await auth.login(email: email, password: password)
                }
                if payload.user.role != "PATIENT" {
                    errorText = "This account isn't a patient. Go back and choose caregiver."
                    return
                }
                session.apply(payload)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
