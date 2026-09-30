import SwiftUI

struct RoleSelectView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    Spacer()

                    BrandMark()
                        .frame(width: 64, height: 64)

                    Text("Who are you?")
                        .font(AppFont.largeTitle)
                        .foregroundStyle(Color.white)
                        .tracking(AppTracking.largeTitle)

                    Text("Here for your own health, or someone you care for?")
                        .font(AppFont.body)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineSpacing(4)

                    VStack(spacing: 12) {
                        NavigationLink {
                            EmailAuthView(role: "PATIENT")
                        } label: {
                            roleCard(
                                title: "I'm a patient",
                                subtitle: "Your activity and glucose.",
                                fill: Color.flare
                            )
                        }

                        NavigationLink {
                            EmailAuthView(role: "CAREGIVER")
                        } label: {
                            roleCard(
                                title: "I'm a caregiver",
                                subtitle: "See how they're doing.",
                                fill: Color.acid
                            )
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func roleCard(title: String, subtitle: String, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.cardTitle)
                .foregroundStyle(Color.ink)
                .tracking(AppTracking.section)
            Text(subtitle)
                .font(AppFont.body)
                .foregroundStyle(Color.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    RoleSelectView()
}
