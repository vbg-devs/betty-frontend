import SwiftUI

/// Blocking profile completion (web `CompleteProfileModal`) — shown when `GET /user/me`
/// 404'd. Prefilled from the auth provider; save = `POST /user {email, name, image_url}`,
/// then (iOS extra) `PUT /user/me {name, country}` when a country was picked.
/// Not dismissable until saved.
struct CompleteProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var name = ""
    @State private var countryCode: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Text("★ ONE LAST STEP")
                        .kicker(Palette.orange)
                        .padding(.top, Space.xl)
                    Text("COMPLETE YOUR PROFILE")
                        .font(.bettyTitle1)
                        .displayKerning(32)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("Pick a name your friends will recognize when you land in the standings.")
                        .font(.bettySubhead)
                        .foregroundStyle(theme.colors.textSecondary)

                    AvatarView(
                        name: name.isEmpty ? env.auth.providerProfile?.displayName : name,
                        nickname: nil,
                        imageURL: env.auth.providerProfile?.photoURL,
                        size: .large
                    )
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("YOUR NAME")
                            .kicker(theme.colors.textMuted)
                        styledField(
                            TextField("Betty", text: $name)
                                .textContentType(.name)
                                .accessibilityIdentifier("auth.completeProfile.nameField")
                        )
                    }

                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("COUNTRY")
                            .kicker(theme.colors.textMuted)
                        styledField(countryPicker)
                    }

                    if let errorMessage {
                        BettyInsetPanel(accent: Palette.orange) {
                            Text(errorMessage)
                                .font(.bettySubhead)
                                .foregroundStyle(theme.colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityIdentifier("auth.completeProfile.error")
                    }

                    Button(isSaving ? "SAVING…" : "SAVE PROFILE") {
                        save()
                    }
                    .buttonStyle(.bettyPrimaryBlock)
                    .disabled(isSaving || !Self.canSave(name: name))
                    .accessibilityIdentifier("auth.completeProfile.saveButton")
                }
                .padding(Space.m)
            }
        }
        .task {
            if name.isEmpty {
                name = env.auth.providerProfile?.displayName ?? ""
            }
            await env.countries.load()
        }
    }

    private var countryPicker: some View {
        Picker("Country", selection: $countryCode) {
            Text("— Not set —").tag(String?.none)
            ForEach(env.countries.countries) { country in
                Text(Self.countryLabel(for: country)).tag(String?.some(country.code))
            }
        }
        .pickerStyle(.menu)
        .tint(theme.colors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("auth.completeProfile.countryPicker")
    }

    private func styledField(_ field: some View) -> some View {
        field
            .padding(Space.s)
            .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sharp)
                    .strokeBorder(theme.colors.overlay10, lineWidth: 1)
            }
            .foregroundStyle(theme.colors.textPrimary)
    }

    private func save() {
        let provider = env.auth.providerProfile
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = countryCode
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            let outcome = await CompleteProfileFlow.submit(
                userStore: env.userStore,
                email: provider?.email ?? "",
                name: trimmed,
                imageURL: provider?.photoURL,
                country: selected
            )
            errorMessage = outcome.blockingErrorMessage
            if let warning = outcome.countryWarningMessage {
                env.toasts.alert(message: warning, state: .warning)
            }
        }
    }

    // MARK: - Pure helpers (pinned by tests)

    /// Web `canSave`: trimmed name non-empty (whitespace-only disables).
    static func canSave(name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Picker row label: flag emoji prefix when present (web UpdateProfileModal rule).
    static func countryLabel(for country: Country) -> String {
        guard let flag = country.flagEmoji, !flag.isEmpty else { return country.name }
        return "\(flag) \(country.name)"
    }

    /// Pinned error precedence: 401/403 → session expired (even over a server message);
    /// >= 500 → friendly retry; server message; generic fallback.
    static func message(for error: APIError) -> String {
        switch error.status {
        case 401, 403:
            return "Your session expired. Please sign in again."
        case .some(let status) where status >= 500:
            return "Something went wrong on our end. We're looking into it — please try again in a moment."
        default:
            return error.serverMessage ?? "Couldn't save your profile. Please try again."
        }
    }
}

/// Submit flow for the complete-profile gate, extracted from the view for testability.
///
/// `POST /user` (+ re-GET, via `UserStore.createProfile`) is the blocking step — its
/// failure keeps the gate up. The optional `PUT /user/me {country}` afterwards is
/// best-effort: the profile already exists (the gate is coming down), so a failure only
/// produces a warning the caller can toast.
enum CompleteProfileFlow {
    struct Outcome: Equatable {
        var blockingErrorMessage: String? = nil
        var countryWarningMessage: String? = nil
    }

    static let countryWarning =
        "Profile saved, but your country didn't stick. You can set it anytime from Profile."

    static func submit(
        userStore: UserStore,
        email: String,
        name: String,
        imageURL: String?,
        country: String?
    ) async -> Outcome {
        do {
            // Always send a non-empty email — the handler 500s when both the body field
            // and the token claim are missing (Apple without email scope).
            try await userStore.createProfile(email: email, name: name, imageURL: imageURL)
        } catch let error as APIError {
            return Outcome(blockingErrorMessage: CompleteProfileView.message(for: error))
        } catch {
            return Outcome(blockingErrorMessage: "Couldn't save your profile. Please try again.")
        }
        guard let country, !country.isEmpty else { return Outcome() }
        do {
            try await userStore.updateProfile(name: name, country: country)
            return Outcome()
        } catch {
            return Outcome(countryWarningMessage: countryWarning)
        }
    }
}
