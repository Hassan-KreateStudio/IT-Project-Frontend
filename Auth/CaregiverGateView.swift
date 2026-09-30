import SwiftUI

struct CaregiverGateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Caregiver")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.ink)

            Text("There is no invite code. A patient signs in, then links you with your email. We build that after patient login works.")
                .font(.system(size: 15))
                .foregroundStyle(Color.mute)
                .lineSpacing(4)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
