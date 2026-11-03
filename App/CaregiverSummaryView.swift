import SwiftUI

/// The caregiver's own Summary tab: one status card per patient, coloured by
/// that patient's last daily glucose average.
struct CaregiverSummaryView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var cards: [WatchCard] = []
    @State private var waiting: [User] = []
    @State private var busy = true
    @State private var errorText: String?

    var body: some View {
        DippedStage(fill: Color.ink, scheme: .dark) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if let errorText {
                        Text(errorText)
                            .font(AppFont.captionMedium)
                            .foregroundStyle(Color.alert)
                            .padding(.bottom, 12)
                    }

                    if busy && cards.isEmpty {
                        Text("Reading…")
                            .font(AppFont.body)
                            .foregroundStyle(Color.mute)
                            .padding(.vertical, 30)
                    } else if cards.isEmpty {
                        emptyState
                    } else {
                        ForEach(cards) { card in
                            patientCard(card)
                                .padding(.bottom, 10)
                        }
                    }

                    if !warnings.isEmpty {
                        sectionLabel("Recent warnings").padding(.top, 8)
                        VStack(spacing: 0) {
                            ForEach(Array(warnings.enumerated()), id: \.offset) { _, entry in
                                warningRow(entry.0, entry.1)
                            }
                        }
                        .padding(.horizontal, 15)
                        .background(Color.night)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    if !waiting.isEmpty {
                        Text(waitingSentence)
                            .font(AppFont.chip)
                            .foregroundStyle(Color.mute)
                            .padding(.top, 14)
                    }
                }
            }
            .refreshable { await load() }
        }
        .onAppear { Task { await load() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Summary")
                .font(AppFont.largeTitle)
                .foregroundStyle(Color.card)
            Text(subtitle)
                .font(AppFont.caption)
                .foregroundStyle(Color.mute)
        }
        .padding(.bottom, 14)
    }

    private var subtitle: String {
        if cards.isEmpty { return waiting.isEmpty ? "Nobody yet" : "Waiting on \(waiting.count)" }
        return cards.count == 1 ? "1 person you watch" : "\(cards.count) people you watch"
    }

    private var waitingSentence: String {
        let names = waiting.map(\.displayName).joined(separator: ", ")
        return "Waiting for \(names) to accept."
    }

    private var warnings: [(String, CaregiverDashboard.Alert)] {
        cards.flatMap { card in card.warnings.map { (card.name, $0) } }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("None")
                .font(AppFont.poster)
                .foregroundStyle(Color.card)
                .tracking(AppTracking.poster)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
            Text("Ask a patient from Sharing. They approve before you see anything.")
                .font(AppFont.body)
                .foregroundStyle(Color.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }

    private func patientCard(_ card: WatchCard) -> some View {
        let ink = card.tinted ? Color.ink : Color.card
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(card.initials)
                    .font(.custom("BricolageGrotesque-ExtraBold", size: 13))
                    .foregroundStyle(card.tinted ? Color.ink : Color.card)
                    .frame(width: 38, height: 38)
                    .background(card.tinted ? Color.ink.opacity(0.14) : Color.dusk)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.name)
                        .font(.custom("BricolageGrotesque-ExtraBold", size: 17))
                        .foregroundStyle(ink)
                    Text("Today’s average")
                        .font(AppFont.chip)
                        .foregroundStyle(ink.opacity(0.6))
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(card.glucose.map { String(Int($0.rounded())) } ?? "—")
                    .font(.custom("BricolageGrotesque-ExtraBold", size: 48))
                    .tracking(-2.6)
                    .foregroundStyle(card.tinted ? Color.ink : card.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("mg/dL")
                    .font(AppFont.chip)
                    .foregroundStyle(ink.opacity(0.55))
                Spacer(minLength: 8)
                statusPill(card, ink: ink)
            }
            .padding(.top, 12)

            HStack(spacing: 7) {
                Circle()
                    .fill(card.tinted ? Color.ink : card.tint)
                    .frame(width: 7, height: 7)
                Text(card.detail)
                    .font(AppFont.chip)
                    .foregroundStyle(ink.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.top, 6)

            Text("\(card.stepsToday.map { $0.formatted() } ?? "—") steps today")
                .font(AppFont.chip)
                .foregroundStyle(ink.opacity(0.65))
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(ink.opacity(0.16))
                        .frame(height: 1)
                }
                .padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card.tinted ? card.tint : Color.night)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.name), glucose \(card.glucose.map { String(Int($0.rounded())) } ?? "none") milligrams per deciliter, \(card.detail)")
    }

    private func statusPill(_ card: WatchCard, ink: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(card.tinted ? Color.ink : card.tint)
                .frame(width: 6, height: 6)
            Text(card.status)
                .font(AppFont.chip)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(card.tinted ? Color.ink : card.tint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(card.tinted ? Color.ink.opacity(0.16) : card.tint.opacity(0.14))
        .clipShape(Capsule())
    }

    private func warningRow(_ name: String, _ alert: CaregiverDashboard.Alert) -> some View {
        let tint = alert.severity == "warning" ? Color.alert : Color.warn
        return HStack(spacing: 11) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.ink)
                .frame(width: 29, height: 29)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(alert.message.contains(name) ? alert.message : "\(alert.message) · \(name)")
                .font(AppFont.chip)
                .foregroundStyle(Color.card)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.chip)
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(Color.mute)
            .padding(.bottom, 8)
    }

    private func load() async {
        errorText = nil
        do {
            let service = CaregiverService(client: session.client())
            async let accepted = service.monitoredPatients()
            async let pending = service.pendingPatients()
            let patients = try await accepted
            waiting = try await pending

            var loaded: [WatchCard] = []
            for patient in patients {
                let dashboard = try? await service.dashboard(patientId: patient.id)
                loaded.append(card(for: patient, dashboard: dashboard))
            }
            cards = loaded
        } catch {
            errorText = error.localizedDescription
        }
        busy = false
    }

    private func card(for patient: User, dashboard: CaregiverDashboard?) -> WatchCard {
        let glucose = dashboard?.glucoseTrends.last?.averageValue
        let steps = dashboard?.activityTrends.last?.stepCount
        let alerts = dashboard?.alerts ?? []

        let status: String
        let tint: Color
        let detail: String
        let tinted: Bool

        switch glucose {
        case let value? where value < 70:
            status = "Low"
            tint = Color.alert
            detail = "Below 70 · check in"
            tinted = true
        case let value? where value > 180:
            status = "High"
            tint = Color.warn
            detail = "Above 180 · worth a look"
            tinted = true
        case let value?:
            status = "In range"
            tint = Color.acid
            detail = value >= 70 ? "Steady" : "No readings"
            tinted = false
        case nil:
            status = "No readings"
            tint = Color.mute
            detail = "Nothing logged yet"
            tinted = false
        }

        return WatchCard(
            id: patient.id,
            name: patient.displayName,
            initials: initials(patient.displayName),
            glucose: glucose,
            status: status,
            tint: tint,
            tinted: tinted,
            detail: detail,
            stepsToday: steps,
            warnings: alerts
        )
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

struct WatchCard: Identifiable {
    var id: String
    var name: String
    var initials: String
    var glucose: Double?
    var status: String
    var tint: Color
    var tinted: Bool
    var detail: String
    var stepsToday: Int?
    var warnings: [CaregiverDashboard.Alert]
}
