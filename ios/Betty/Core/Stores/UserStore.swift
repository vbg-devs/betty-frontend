import Foundation
import Observation

/// Profile holder + the boot ensure-profile flow.
///
/// Boot sequence: `loadMe()` — on a 404 the backend has no profile row yet, so
/// `needsProfile` flips true (present the blocking complete-profile UI, prefilled from
/// `AuthService.providerProfile`) and the caller saves via `createProfile(...)`.
@Observable
final class UserStore {
    private let api: APIClient

    private(set) var profile: UserProfile?
    /// True after `loadMe()` hit 404 — drives the CompleteProfile gate.
    private(set) var needsProfile = false

    /// Firebase UID STRING — every "is this mine" check compares against this
    /// (nil when logged out = "not mine").
    var id: String? { profile?.id }
    var isAdmin: Bool { profile?.isAdmin ?? false }

    init(api: APIClient) {
        self.api = api
    }

    /// Replaces the profile wholesale; `set(nil)` clears (sign-out).
    func set(_ profile: UserProfile?) {
        self.profile = profile
        if profile != nil { needsProfile = false }
    }

    /// `GET /user/me`. A 404 means "authenticated but no profile row yet" → sets
    /// `needsProfile` instead of throwing. Other errors rethrow.
    func loadMe() async throws {
        do {
            profile = try await api.getMe()
            needsProfile = false
        } catch APIError.notFound {
            profile = nil
            needsProfile = true
        }
    }

    /// `POST /user` then re-GET `/user/me` (the 201 echo has zero timestamps).
    /// Always pass a non-empty email AND name — the handler 500s when both the field and
    /// the token claim are missing (Apple sign-in without email scope).
    func createProfile(email: String, name: String, imageURL: String?) async throws {
        _ = try await api.createUser(email: email, name: name, imageURL: imageURL)
        try await loadMe()
    }

    /// `PUT /user/me` — backend applies ONLY name + country. Always send the full current
    /// name (an omitted name clears it server-side). Never send email.
    func updateProfile(name: String, country: String?) async throws {
        profile = try await api.updateMe(name: name, country: country)
    }

    /// Presigned upload flow: presign → raw PUT to R2 → commit. Client-side caps
    /// (matching the backend): jpeg/png/webp/gif, <= 1 MiB, non-empty.
    /// Errors: 413 too large, 415 bad type, 503 uploads unavailable.
    func uploadProfileImage(_ data: Data, contentType: String) async throws {
        let presigned = try await api.profileImageUploadURL(contentType: contentType, contentLength: data.count)
        try await api.upload(data, with: presigned, contentType: contentType)
        let committed = try await api.setProfileImage(imageURL: presigned.publicURL)
        profile?.imageURL = committed
    }

    /// `DELETE /user/me/profile-image` — reverts to the provider (Firebase) photo.
    func revertProfileImage() async throws {
        let reverted = try await api.deleteProfileImage()
        profile?.imageURL = reverted
    }

    /// `POST /user/me/add_push_token` (FCM registration tokens — see APIClient note).
    func addPushToken(_ token: String) async throws {
        try await api.addPushToken(token)
    }

    /// `DELETE /user/me` — anonymizes the row and deletes the Firebase account.
    /// The caller MUST follow up with `AuthService.signOut()`.
    func deleteAccount() async throws {
        try await api.deleteMe()
        profile = nil
    }

    /// `GET /user/:id/groups` — rich one-shot profile + placements payload.
    func userGroups(userID: String) async throws -> UserGroupsResponse {
        try await api.userGroups(userID: userID)
    }
}
