import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Web HeaderBar dropdown + `UpdateProfileModal` as a full tab screen: avatar with the
/// presigned photo upload, name + country edit (PUT /user/me applies ONLY those two —
/// email is never sent), appearance toggle, links, sign out and account deletion.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme

    @State private var name = ""
    @State private var country: String?
    @State private var isSaving = false
    @State private var hasPrefilled = false

    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var imageError: String?

    @State private var showsPrivacy = false

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    Text("★ ACCOUNT")
                        .kicker(Palette.orange)
                    Text("EDIT PROFILE")
                        .font(.bettyDisplayL)
                        .displayKerning(40)
                        .foregroundStyle(theme.colors.textPrimary)

                    avatarSection

                    if let imageError {
                        BettyInsetPanel(accent: Palette.orange) {
                            Text(imageError)
                                .font(.bettySubhead)
                                .foregroundStyle(theme.colors.textPrimary)
                        }
                        .accessibilityIdentifier("profile.edit.imageError")
                    }

                    formCard
                    linksCard
                    accountCard
                }
                .padding(Space.m)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsPrivacy) {
            NavigationStack {
                PrivacyView()
            }
        }
        .task { await prefill() }
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            photoItem = nil
            Task { await handlePickedPhoto(newValue) }
        }
    }

    // MARK: - Avatar + photo upload

    private var avatarSection: some View {
        VStack(spacing: Space.s) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    AvatarView(
                        name: name.isEmpty ? env.userStore.profile?.name : name,
                        nickname: nil,
                        imageURL: env.userStore.profile?.imageURL,
                        size: .large
                    )
                    if isUploadingImage {
                        Circle().fill(Palette.modalBackdrop)
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(width: AvatarSize.large.rawValue, height: AvatarSize.large.rawValue)
                .overlay(alignment: .bottom) {
                    if !isUploadingImage {
                        // Inline kicker styling — the custom .kicker() extension is
                        // MainActor-isolated and can't be called from this closure.
                        Text("CHANGE")
                            .font(.bettyKicker)
                            .kerning(1.6)
                            .foregroundStyle(.white)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 7)
                            .background(Palette.pillDark, in: RoundedRectangle(cornerRadius: Radius.sharp))
                            .offset(y: 4)
                    }
                }
            }
            .disabled(isUploadingImage)
            .accessibilityIdentifier("profile.edit.avatar")

            if let profile = env.userStore.profile {
                VStack(spacing: 2) {
                    Text(profile.name)
                        .font(.bettyHeadline)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(profile.email)
                        .font(.bettySubhead)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                if ProfileImagePolicy.hasCustomImage(imageURL: profile.imageURL, firebaseImageURL: profile.firebaseImageURL) {
                    Button("REVERT TO DEFAULT PHOTO") {
                        revertImage()
                    }
                    .buttonStyle(.bettyGhost)
                    .disabled(isUploadingImage)
                    .accessibilityIdentifier("profile.edit.revertPhoto")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        guard !isUploadingImage else { return }
        imageError = nil
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            imageError = ProfileImagePolicy.genericUploadMessage
            return
        }

        var payload = data
        var contentType = ProfileImagePolicy.sniffContentType(data)
            ?? item.supportedContentTypes.first?.preferredMIMEType
            ?? "application/octet-stream"
        if !ProfileImagePolicy.allowedTypes.contains(contentType) || payload.count > ProfileImagePolicy.maxBytes {
            // The photo library mostly hands over HEIC / multi-MB originals — transcode
            // to a JPEG that fits the backend cap instead of bouncing the pick.
            if let transcoded = Self.jpegPayload(from: data) {
                payload = transcoded
                contentType = "image/jpeg"
            }
        }
        if let message = ProfileImagePolicy.validationError(contentType: contentType, byteCount: payload.count) {
            imageError = message
            return
        }

        isUploadingImage = true
        defer { isUploadingImage = false }
        do {
            try await env.userStore.uploadProfileImage(payload, contentType: contentType)
        } catch let error as APIError {
            imageError = ProfileImagePolicy.uploadErrorMessage(status: error.status)
        } catch {
            imageError = ProfileImagePolicy.genericUploadMessage
        }
    }

    private func revertImage() {
        guard !isUploadingImage else { return }
        imageError = nil
        isUploadingImage = true
        Task {
            defer { isUploadingImage = false }
            do {
                try await env.userStore.revertProfileImage()
            } catch {
                imageError = ProfileImagePolicy.revertFailedMessage
            }
        }
    }

    private static func jpegPayload(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        if let direct = image.jpegData(compressionQuality: 0.85), direct.count <= ProfileImagePolicy.maxBytes {
            return direct
        }
        let maxDimension: CGFloat = 1280
        let largest = max(image.size.width, image.size.height)
        guard largest > 0 else { return nil }
        let scale = min(1, maxDimension / largest)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Edit form

    private var formCard: some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.m) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("USER NAME")
                        .kicker(theme.colors.textMuted)
                    TextField("Betty", text: $name)
                        .padding(Space.s)
                        .background(theme.colors.overlay06, in: RoundedRectangle(cornerRadius: Radius.sharp))
                        .foregroundStyle(theme.colors.textPrimary)
                        .accessibilityIdentifier("profile.edit.nameField")
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("COUNTRY")
                        .kicker(theme.colors.textMuted)
                    Picker("Country", selection: $country) {
                        Text("— Not set —").tag(String?.none)
                        ForEach(env.countries.countries) { country in
                            Text(countryLabel(country)).tag(String?.some(country.code))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(theme.colors.textPrimary)
                    .accessibilityIdentifier("profile.edit.countryPicker")
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("APPEARANCE")
                        .kicker(theme.colors.textMuted)
                    Picker("Theme", selection: themeBinding) {
                        Text("Dark").tag(ThemeMode.dark)
                        Text("Light").tag(ThemeMode.light)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("profile.edit.themePicker")
                }

                Button(isSaving ? "SAVING…" : "SAVE PROFILE") {
                    save()
                }
                .buttonStyle(.bettyPrimaryBlock)
                .disabled(isSaving || name.isEmpty)
                .accessibilityIdentifier("profile.edit.save")
            }
        }
    }

    private func countryLabel(_ country: Country) -> String {
        if let flag = country.flagEmoji, !flag.isEmpty {
            return "\(flag)  \(country.name)"
        }
        return country.name
    }

    private func save() {
        guard !name.isEmpty, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await env.userStore.updateProfile(name: name, country: country)
                env.toasts.alert(title: "Profile updated", message: "All saved — looking sharp.", state: .success)
            } catch {
                env.toasts.alert(
                    title: "Could not update profile",
                    message: "Your profile could not be updated, please try again.",
                    state: .critical
                )
            }
        }
    }

    private func prefill() async {
        await env.countries.load()
        guard !hasPrefilled else { return }
        try? await env.userStore.loadMe()
        if let profile = env.userStore.profile {
            name = profile.name
            country = (profile.country?.isEmpty == false) ? profile.country : nil
        }
        hasPrefilled = true
    }

    // MARK: - Links

    private var linksCard: some View {
        BettyCard {
            VStack(alignment: .leading, spacing: Space.s) {
                NavigationLink(value: Destination.support) {
                    linkRow("Support")
                }
                .accessibilityIdentifier("profile.links.support")
                NavigationLink(value: Destination.about) {
                    linkRow("About")
                }
                .accessibilityIdentifier("profile.links.about")
                Button {
                    showsPrivacy = true
                } label: {
                    linkRow("Privacy")
                }
                .accessibilityIdentifier("profile.links.privacy")
                if env.userStore.isAdmin {
                    NavigationLink(value: Destination.adminEvaluate) {
                        linkRow("Admin")
                    }
                    .accessibilityIdentifier("profile.links.admin")
                }
            }
        }
    }

    private func linkRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.bettyBody)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(theme.colors.textSecondary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Account actions

    private var accountCard: some View {
        VStack(spacing: Space.s) {
            Button("SIGN OUT") {
                env.signOut()
            }
            .buttonStyle(BettyButtonStyle(variant: .destructive, isBlock: true))
            .accessibilityIdentifier("profile.account.signOut")

            Button("DELETE ACCOUNT") {
                confirmDeleteAccount()
            }
            .buttonStyle(BettyButtonStyle(variant: .outline, isBlock: true))
            .accessibilityIdentifier("profile.account.delete")
        }
    }

    private func confirmDeleteAccount() {
        env.toasts.confirm(
            title: "Delete account",
            question: "Delete your Betty account? Your profile and bets are removed for good — this cannot be undone."
        ) {
            await deleteAccount()
        }
    }

    private func deleteAccount() async {
        do {
            try await env.userStore.deleteAccount()
            env.signOut()
        } catch {
            env.toasts.alert(
                title: "Could not delete account",
                message: "Please try again in a moment.",
                state: .error
            )
        }
    }

    private var themeBinding: Binding<ThemeMode> {
        Binding(
            get: { env.theme.mode },
            set: { env.theme.mode = $0 }
        )
    }
}
