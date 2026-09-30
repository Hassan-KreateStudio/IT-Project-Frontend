import SwiftUI
import UIKit

struct EmailAuthView: View {
    let role: String

    @EnvironmentObject private var session: SessionStore
    @State private var displayName = ""
    @State private var email = ""
    @State private var code = ""
    @State private var sent = false
    @State private var needsName = false
    @State private var errorText: String?
    @State private var busy = false

    private var isPatient: Bool { role == "PATIENT" }
    private var accent: Color { isPatient ? Color.flare : Color.acid }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BrandMark(tiled: true)
                    .frame(width: 56, height: 56)

                Text(headline)
                    .font(AppFont.largeTitle)
                    .foregroundStyle(Color.ink)
                    .tracking(AppTracking.largeTitle)

                Text(subhead)
                    .font(AppFont.body)
                    .foregroundStyle(Color.mute)
                    .lineSpacing(4)

                VStack(spacing: 12) {
                    if sent {
                        field("Code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: code) { _, value in
                                let digits = value.filter(\.isNumber)
                                code = String(digits.prefix(6))
                            }
                    } else {
                        field("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                        if needsName {
                            field("Name", text: $displayName)
                                .textContentType(.name)
                        }
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(AppFont.captionMedium)
                        .foregroundStyle(Color.alert)
                }

                Button(action: sent ? verify : send) {
                    Text(busy ? "Working…" : (sent ? "Verify" : "Send code"))
                        .font(AppFont.button)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(busy || (sent && code.count != 6) || (needsName && !sent && displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                if sent {
                    Button("Use a different email") {
                        sent = false
                        needsName = false
                        displayName = ""
                        code = ""
                        errorText = nil
                    }
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.ink)

                    Button("Send a new code", action: send)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.mute)
                        .disabled(busy)
                }
            }
            .padding(20)
        }
        .background(Color.canvas.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .onAppear {
            UITextField.appearance().textColor = UIColor(Color.ink)
            UITextField.appearance().tintColor = UIColor(accent)
        }
    }

    private var headline: String {
        if sent { return "Check your email" }
        if needsName { return "What should we call you?" }
        return isPatient ? "Your health space" : "Here for them"
    }

    private var subhead: String {
        if sent {
            return "We sent a 6-digit code to \(email). Check spam if it isn’t there."
        }
        if needsName {
            return "This email is new. Your name stays on the account — we won’t ask again."
        }
        return isPatient
            ? "We’ll email you a code. This account keeps your activity and glucose."
            : "We’ll email you a code. They can add you with this same email."
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(Color.mute)
            TextField("", text: text, prompt: Text(title).foregroundStyle(Color.mute))
                .font(AppFont.body)
                .foregroundStyle(Color.ink)
                .tint(accent)
                .padding(14)
                .background(Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.hairline, lineWidth: 1)
                )
        }
    }

    private func send() {
        errorText = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                _ = try await AuthService(client: GraphQLClient()).requestAuthCode(
                    email: email,
                    role: role,
                    displayName: needsName ? displayName : ""
                )
                code = ""
                sent = true
            } catch let err as GraphQLError {
                if err.extensions?.code == "invalid_display_name" {
                    needsName = true
                    errorText = nil
                } else {
                    errorText = err.errorDescription
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func verify() {
        errorText = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                let payload = try await AuthService(client: GraphQLClient()).verifyAuthCode(
                    email: email,
                    code: code
                )
                if payload.user.role != role {
                    errorText = isPatient
                        ? "This account isn’t a patient. Go back and choose caregiver."
                        : "This account isn’t a caregiver. Go back and choose patient."
                    return
                }
                session.apply(payload)
            } catch let err as GraphQLError {
                errorText = err.errorDescription
                if err.extensions?.code == "too_many_attempts" {
                    sent = false
                    code = ""
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
