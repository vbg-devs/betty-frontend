import Foundation
import Testing
@testable import Betty

private final class StubTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token" }
    func tokenAfterAuthFailure() async throws -> String { "token" }
}

/// Pins the profile screen flows against the wire: PUT /user/me sends ONLY name+country
/// (never email), the presign → raw PUT → commit upload chain (with the pinned header
/// filtering), revert-to-null handling, account deletion, and the 404 onboarding gate.
@Suite struct ProfileFlowsTests {
    private static let meJSON = """
    {
      "id": "uid-1", "email": "ada@b.c", "name": "Ada",
      "image_url": "https://cdn.betty.social/users/uid-1/profile/old.png",
      "firebase_image_url": "https://lh3.googleusercontent.com/p.png",
      "country": "SE",
      "created_at": "2026-06-07T12:00:00Z", "updated_at": "2026-06-07T12:00:00Z",
      "is_admin": false
    }
    """

    private func makeStore(transport: MockTransport) -> UserStore {
        UserStore(api: APIClient(transport: transport, tokens: StubTokens()))
    }

    // MARK: - PUT /user/me

    @Test func updateProfileSendsOnlyNameAndCountryNeverEmail() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            MockTransport.json(Self.meJSON, url: request.url)
        }

        try await store.updateProfile(name: "Ada", country: "SE")

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path.hasSuffix("/user/me") == true)
        let body = try #require(request.httpBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["name"] as? String == "Ada")
        #expect(object["country"] as? String == "SE")
        #expect(object["email"] == nil) // an empty email used to wipe the stored address
        #expect(object["image_url"] == nil) // images only via the presigned flow
        #expect(store.profile?.name == "Ada")
    }

    @Test func updateProfileEncodesExplicitNullToClearCountry() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            MockTransport.json(Self.meJSON, url: request.url)
        }

        try await store.updateProfile(name: "Ada", country: nil)

        let body = try #require(transport.requests.first?.httpBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object.keys.contains("country"))
        #expect(object["country"] is NSNull)
    }

    // MARK: - Profile image upload chain

    @Test func uploadRunsPresignPutCommitAndPatchesProfile() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        let presignJSON = """
        {
          "key": "users/uid-1/profile/1.png",
          "upload_url": "https://r2.example/bucket/users/uid-1/profile/1.png?sig=abc",
          "method": "PUT",
          "headers": {
            "Content-Type": ["image/png"],
            "Content-Length": ["3"],
            "Host": ["r2.example"],
            "x-amz-meta-tags": ["a", "b"]
          },
          "public_url": "https://cdn.betty.social/users/uid-1/profile/1.png",
          "expires_at": "2026-06-07T12:05:00Z"
        }
        """
        transport.handler = { request in
            let path = request.url?.path ?? ""
            if request.url?.host == "r2.example" {
                return MockTransport.json("", url: request.url)
            }
            if path.hasSuffix("/user/me/profile-image/upload-url") {
                return MockTransport.json(presignJSON, url: request.url)
            }
            if path.hasSuffix("/user/me/profile-image") {
                return MockTransport.json(#"{"image_url": "https://cdn.betty.social/users/uid-1/profile/1.png"}"#, url: request.url)
            }
            return MockTransport.json(Self.meJSON, url: request.url)
        }

        try await store.loadMe()
        try await store.uploadProfileImage(Data([1, 2, 3]), contentType: "image/png")

        #expect(store.profile?.imageURL == "https://cdn.betty.social/users/uid-1/profile/1.png")

        let r2Put = try #require(transport.requests.first { $0.url?.host == "r2.example" })
        #expect(r2Put.httpMethod == "PUT")
        #expect(r2Put.httpBody == Data([1, 2, 3]))
        #expect(r2Put.value(forHTTPHeaderField: "Content-Type") == "image/png")
        #expect(r2Put.value(forHTTPHeaderField: "Host") == nil) // skipped (URLSession owns it)
        #expect(r2Put.value(forHTTPHeaderField: "Content-Length") == nil) // skipped
        #expect(r2Put.value(forHTTPHeaderField: "x-amz-meta-tags") == "a, b") // multi-values joined

        // Commit happens AFTER the storage PUT.
        let paths = transport.requests.map { ($0.httpMethod ?? "", $0.url?.path ?? "", $0.url?.host ?? "") }
        let putIndex = try #require(paths.firstIndex { $0.2 == "r2.example" })
        let commitIndex = try #require(paths.firstIndex { $0.0 == "PUT" && $0.1.hasSuffix("/user/me/profile-image") })
        #expect(putIndex < commitIndex)
    }

    @Test func oversizedPresignRejectionSurfacesThePinned413Copy() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            MockTransport.json("", status: 413, url: request.url)
        }

        do {
            try await store.uploadProfileImage(Data(repeating: 1, count: 10), contentType: "image/png")
            Issue.record("expected 413")
        } catch let error as APIError {
            #expect(error.status == 413)
            #expect(ProfileImagePolicy.uploadErrorMessage(status: error.status) == ProfileImagePolicy.sizeMessage)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    // MARK: - Revert

    @Test func revertReturningNullClearsTheImage() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            if request.httpMethod == "DELETE" {
                return MockTransport.json(#"{"image_url": null}"#, url: request.url)
            }
            return MockTransport.json(Self.meJSON, url: request.url)
        }

        try await store.loadMe()
        #expect(store.profile?.imageURL != nil)

        try await store.revertProfileImage()

        #expect(store.profile?.imageURL == nil)
        let deleteRequest = try #require(transport.requests.first { $0.httpMethod == "DELETE" })
        #expect(deleteRequest.url?.path.hasSuffix("/user/me/profile-image") == true)
    }

    // MARK: - Account deletion

    @Test func deleteAccountCallsDeleteMeAndClearsProfile() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            if request.httpMethod == "DELETE" {
                return MockTransport.json("null", url: request.url)
            }
            return MockTransport.json(Self.meJSON, url: request.url)
        }

        try await store.loadMe()
        try await store.deleteAccount()

        #expect(store.profile == nil)
        let deleteRequest = try #require(transport.requests.first { $0.httpMethod == "DELETE" })
        #expect(deleteRequest.url?.path.hasSuffix("/user/me") == true)
    }

    // MARK: - Onboarding gate

    @Test func loadMe404FlipsNeedsProfileWithoutThrowing() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            MockTransport.json("", status: 404, url: request.url)
        }

        try await store.loadMe()

        #expect(store.needsProfile)
        #expect(store.profile == nil)
    }
}
