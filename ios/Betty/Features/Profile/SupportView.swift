import SwiftUI

/// Web `/support`: email card + feature-request form (`POST /feature-requests`,
/// <= 5000 chars, trimmed payload, success clears / failure keeps the text).
struct SupportView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var descriptionText = ""
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.cardGap) {
                    hero
                    emailCard
                    featureCard
                    Text("LAST UPDATED · SEPTEMBER 24, 2022")
                        .kicker(theme.colors.textMuted)
                        .frame(maxWidth: .infinity)
                }
                .padding(Space.m)
            }
        }
        .navigationTitle("Support")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("★ NEED A HAND?")
                .kicker(Palette.orange)
            VStack(alignment: .leading, spacing: 0) {
                Text("GET IN")
                    .font(.bettyDisplayL)
                    .displayKerning(40)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("TOUCH.")
                    .font(.bettyDisplayL)
                    .displayKerning(40)
                    .foregroundStyle(Palette.orange)
            }
            Text("Bug reports, feature requests, smack-talk about the math — Betty's listening.")
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var emailCard: some View {
        BettyInsetPanel(accent: Palette.orange, padding: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("★ EMAIL")
                    .kicker(Palette.orange)
                Link(destination: URL(string: "mailto:support@betty.social")!) {
                    HStack(spacing: Space.xs) {
                        Text("support@betty.social")
                            .font(.bettyTitle3)
                            .foregroundStyle(theme.colors.textPrimary)
                        Text("→")
                            .font(.bettyTitle3)
                            .foregroundStyle(Palette.orange)
                    }
                }
            }
        }
    }

    private var featureCard: some View {
        BettyInsetPanel(accent: theme.colors.accentPositive, padding: Space.l) {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("● FEATURE REQUEST")
                    .kicker(theme.colors.accentPositive)
                Text("PITCH BETTY AN IDEA.")
                    .font(.bettyTitle2)
                    .displayKerning(28)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("Something missing? A bet type, a stat, a rule tweak — tell us. We read every one.")
                    .font(.bettyBody)
                    .foregroundStyle(theme.colors.textSecondary)

                TextField("What would make Betty better?", text: $descriptionText, axis: .vertical)
                    .lineLimit(5...12)
                    .padding(Space.s)
                    .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
                    .foregroundStyle(theme.colors.textPrimary)
                    .disabled(isSubmitting)
                    .onChange(of: descriptionText) { _, newValue in
                        let clamped = SupportFormLogic.clamped(newValue)
                        if clamped != newValue {
                            descriptionText = clamped
                        }
                    }
                    .accessibilityIdentifier("profile.support.descriptionField")

                HStack {
                    // verbatim: Int interpolation in a LocalizedStringKey grouping-
                    // formats the number ("5,000 LEFT") — web shows "5000 LEFT".
                    Text(verbatim: "\(SupportFormLogic.remaining(descriptionText)) LEFT")
                        .kicker(SupportFormLogic.warnsLowBudget(descriptionText) ? Palette.orange : theme.colors.textMuted)
                        .accessibilityIdentifier("profile.support.counter")
                    Spacer()
                    Button(isSubmitting ? "SENDING…" : "SEND IT →") {
                        submit()
                    }
                    .buttonStyle(.bettyPrimary)
                    .disabled(!SupportFormLogic.canSubmit(text: descriptionText, isSubmitting: isSubmitting))
                    .accessibilityIdentifier("profile.support.submit")
                }
            }
        }
    }

    private func submit() {
        guard SupportFormLogic.canSubmit(text: descriptionText, isSubmitting: isSubmitting) else { return }
        let trimmed = SupportFormLogic.trimmed(descriptionText)
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                _ = try await env.api.createFeatureRequest(description: trimmed)
                descriptionText = ""
                env.toasts.alert(title: "Thanks!", message: "Your idea is in. Betty appreciates it.", state: .success)
            } catch {
                env.toasts.alert(title: "Hmm", message: "Couldn't send that just now. Try again in a moment?", state: .error)
            }
        }
    }
}
