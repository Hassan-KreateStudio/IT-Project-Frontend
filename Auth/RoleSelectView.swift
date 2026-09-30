import SwiftUI

struct RoleSelectView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.forest.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    Spacer()

                    Text("Who are you?")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(Color.volt)
                        .tracking(-0.4)

                    Text("Patient first. Caregiver is a different account, linked later by email.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.volt.opacity(0.85))
                        .lineSpacing(4)

                    VStack(spacing: 12) {
                        NavigationLink {
                            PatientAuthView()
                        } label: {
                            roleCard(title: "I'm a patient", subtitle: "Track activity and glucose.")
                        }

                        NavigationLink {
                            CaregiverGateView()
                        } label: {
                            roleCard(title: "I'm a caregiver", subtitle: "Watch a linked patient. Not yet.")
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func roleCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Color.mute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.volt)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    RoleSelectView()
}
