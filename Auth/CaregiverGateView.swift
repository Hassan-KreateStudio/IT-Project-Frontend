import SwiftUI

struct CaregiverGateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrandMark(tiled: true)
                .frame(width: 56, height: 56)

            Text("Caregiver")
                .font(AppFont.largeTitle)
                .foregroundStyle(Color.ink)
                .tracking(AppTracking.largeTitle)

            Text("Ask them to sign in first. They'll add you with your email.")
                .font(AppFont.body)
                .foregroundStyle(Color.mute)
                .lineSpacing(4)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.canvas.ignoresSafeArea())
        .preferredColorScheme(.light)
        .navigationBarTitleDisplayMode(.inline)
    }
}
