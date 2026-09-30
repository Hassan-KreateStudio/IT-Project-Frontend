import SwiftUI

struct RoleSelectView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.forest.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    Spacer()

                    Text("Who are you?")
                        .font(AppFont.largeTitle)
                        .foregroundStyle(Color.volt)
                        .tracking(AppTracking.largeTitle)

                    Text("Here for your own health, or someone you care for?")
                        .font(AppFont.body)
                        .foregroundStyle(Color.volt.opacity(0.85))
                        .lineSpacing(4)

                    VStack(spacing: 12) {
                        NavigationLink {
                            PatientAuthView()
                        } label: {
                            roleCard(title: "I'm a patient", subtitle: "Your activity and glucose.")
                        }

                        NavigationLink {
                            CaregiverGateView()
                        } label: {
                            roleCard(title: "I'm a caregiver", subtitle: "See how they're doing.")
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
                .font(AppFont.cardTitle)
                .foregroundStyle(Color.ink)
                .tracking(AppTracking.section)
            Text(subtitle)
                .font(AppFont.body)
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
