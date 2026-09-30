import SwiftUI
import UIKit

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
                BrandMark(tiled: true)
                    .frame(width: 56, height: 56)

                Text(isRegister ? "Create account" : "Sign in")
                    .font(AppFont.largeTitle)
                    .foregroundStyle(Color.ink)
                    .tracking(AppTracking.largeTitle)

                Text(isRegister ? "This account keeps your activity and glucose." : "Welcome back.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)

                HStack(spacing: 0) {
                    modeTab("Create", selected: isRegister) { isRegister = true }
                    modeTab("Sign in", selected: !isRegister) { isRegister = false }
                }
                .padding(4)
                .background(Color.mist)
                .clipShape(Capsule())

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
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.flare)
        .onAppear {
            UITextField.appearance().textColor = UIColor(Color.ink)
            UITextField.appearance().tintColor = UIColor(Color.flare)
        }
    }

    private func field(_ title: String, text: Binding<String>, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(Color.mute)
            Group {
                if secure {
                    SecureField("", text: text, prompt: Text(title).foregroundStyle(Color.mute))
                } else {
                    TextField("", text: text, prompt: Text(title).foregroundStyle(Color.mute))
                }
            }
            .font(AppFont.body)
            .foregroundStyle(Color.ink)
            .tint(Color.flare)
            .padding(14)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
        }
    }

    private func modeTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.bodyMedium)
                .foregroundStyle(selected ? Color.ink : Color.mute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color.flare : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
