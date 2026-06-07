import Foundation
import Testing
@testable import Betty

private final class CoverStubTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token" }
    func tokenAfterAuthFailure() async throws -> String { "token-2" }
}

/// Pins the author cover-image flow against the wire: the presign → raw R2 PUT →
/// commit chain of `GroupStore.uploadHeaderImage`, the reload-after-mutation,
/// abort semantics on every failing leg (presign 401/413, storage 500, commit 400),
/// `deleteHeaderImage`, and the 401/403/413/415/503 error-copy mapping.
@Suite struct GroupCoverImageFlowTests {
    private static let groupID = 7
    private static let publicURL = "https://cdn.betty.social/groups/7/header/1.png"

    private static let presignJSON = """
    {
      "key": "groups/7/header/1.png",
      "upload_url": "https://r2.example/betty/groups/7/header/1.png?sig=abc",
      "method": "PUT",
      "headers": {
        "Content-Type": ["image/png"],
        "Content-Length": ["3"],
        "Host": ["r2.example"]
      },
      "public_url": "\(publicURL)",
      "expires_at": "2026-06-07T12:05:00Z"
    }
    """

    private static func groupsJSON(headerImageURL: String?) -> String {
        """
        [{
          "id": \(groupID),
          "name": "Sunday Roast XI",
          "tournament_id": 5,
          "tournament_name": "Euro 2028",
          "header_image_url": \(headerImageURL.map { "\"\($0)\"" } ?? "null"),
          "invite_code": "abc-123",
          "invite_url": "https://betty.social/dashboard/groups/join/abc-123",
          "welcome_message": null,
          "description": null,
          "correct_team_points": 2,
          "exact_result_points": 4,
          "allow_sneak_peek": true,
          "mode": 0,
          "public_at": null,
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z",
          "members": []
        }]
        """
    }

    private func makeStore(transport: MockTransport) -> GroupStore {
        GroupStore(api: APIClient(transport: transport, tokens: CoverStubTokens()))
    }

    private static func isPresign(_ request: URLRequest) -> Bool {
        request.url?.path.hasSuffix("/group/\(groupID)/header-image/upload-url") == true
    }

    private static func isCommit(_ request: URLRequest) -> Bool {
        request.httpMethod == "PUT"
            && request.url?.path.hasSuffix("/group/\(groupID)/header-image") == true
    }

    private static func isReload(_ request: URLRequest) -> Bool {
        request.httpMethod == "GET" && request.url?.path.hasSuffix("/groups") == true
    }

    // MARK: - Upload chain

    @Test func uploadRunsPresignStoragePutCommitThenReloads() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            if request.url?.host == "r2.example" {
                return MockTransport.json("", url: request.url)
            }
            if Self.isPresign(request) {
                return MockTransport.json(Self.presignJSON, url: request.url)
            }
            if Self.isCommit(request) {
                return MockTransport.json(#"{"header_image_url": "\#(Self.publicURL)"}"#, url: request.url)
            }
            return MockTransport.json(Self.groupsJSON(headerImageURL: Self.publicURL), url: request.url)
        }

        let committed = try await store.uploadHeaderImage(
            groupID: Self.groupID, data: Data([1, 2, 3]), contentType: "image/png"
        )

        #expect(committed == Self.publicURL)

        // Presign request carries the file metadata the backend validates (415/413).
        let presign = try #require(transport.requests.first { Self.isPresign($0) })
        #expect(presign.httpMethod == "POST")
        let presignBodyData = try #require(presign.httpBody)
        let presignBody = try #require(try JSONSerialization.jsonObject(with: presignBodyData) as? [String: Any])
        #expect(presignBody["content_type"] as? String == "image/png")
        #expect(presignBody["content_length"] as? Int == 3)

        // Raw storage PUT: bytes + presigned headers, outside the API base.
        let storagePut = try #require(transport.requests.first { $0.url?.host == "r2.example" })
        #expect(storagePut.httpMethod == "PUT")
        #expect(storagePut.httpBody == Data([1, 2, 3]))
        #expect(storagePut.value(forHTTPHeaderField: "Content-Type") == "image/png")

        // Commit body must be the presign `public_url` (the API 400s anything else).
        let commit = try #require(transport.requests.first { Self.isCommit($0) })
        let commitBodyData = try #require(commit.httpBody)
        let commitBody = try #require(try JSONSerialization.jsonObject(with: commitBodyData) as? [String: Any])
        #expect(commitBody["header_image_url"] as? String == Self.publicURL)

        // Chain order: presign → storage PUT → commit → GET /groups reload.
        let presignIndex = try #require(transport.requests.firstIndex { Self.isPresign($0) })
        let putIndex = try #require(transport.requests.firstIndex { $0.url?.host == "r2.example" })
        let commitIndex = try #require(transport.requests.firstIndex { Self.isCommit($0) })
        let reloadIndex = try #require(transport.requests.firstIndex { Self.isReload($0) })
        #expect(presignIndex < putIndex)
        #expect(putIndex < commitIndex)
        #expect(commitIndex < reloadIndex)

        // The reload landed in the store.
        #expect(store.isLoaded)
        #expect(store.byID(Self.groupID)?.headerImageURL == Self.publicURL)
    }

    @Test func nonAuthorPresign401AbortsBeforeAnyUpload() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        // Handler 401s are empty-bodied (authorization, not a token rejection) —
        // they must surface immediately: no retry, no storage PUT, no commit.
        transport.handler = { request in
            MockTransport.json("", status: 401, url: request.url)
        }

        do {
            try await store.uploadHeaderImage(groupID: Self.groupID, data: Data([1]), contentType: "image/png")
            Issue.record("expected 401")
        } catch let error as APIError {
            #expect(error.status == 401)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }

        #expect(transport.requests.count == 1) // no storage PUT, no commit, no reload
        #expect(transport.requests.allSatisfy { Self.isPresign($0) })
    }

    @Test func oversizedPresign413SurfacesWithoutUpload() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            MockTransport.json("", status: 413, url: request.url)
        }

        do {
            try await store.uploadHeaderImage(
                groupID: Self.groupID, data: Data(repeating: 1, count: 8), contentType: "image/png"
            )
            Issue.record("expected 413")
        } catch let error as APIError {
            #expect(error.status == 413)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }

        #expect(transport.requests.count == 1)
    }

    @Test func failedStoragePutNeverCommits() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            if request.url?.host == "r2.example" {
                return MockTransport.json("", status: 500, url: request.url)
            }
            if Self.isPresign(request) {
                return MockTransport.json(Self.presignJSON, url: request.url)
            }
            return MockTransport.json(Self.groupsJSON(headerImageURL: nil), url: request.url)
        }

        do {
            try await store.uploadHeaderImage(groupID: Self.groupID, data: Data([1]), contentType: "image/png")
            Issue.record("expected the storage PUT failure to surface")
        } catch let error as APIError {
            #expect(error.status == 500)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }

        #expect(!transport.requests.contains { Self.isCommit($0) }) // failed PUT must never commit
        #expect(!transport.requests.contains { Self.isReload($0) })
    }

    @Test func commitRejection400SurfacesWithoutReload() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            if request.url?.host == "r2.example" {
                return MockTransport.json("", url: request.url)
            }
            if Self.isPresign(request) {
                return MockTransport.json(Self.presignJSON, url: request.url)
            }
            if Self.isCommit(request) {
                // Contract: header_image_url not matching the presign public_url → 400.
                return MockTransport.json("", status: 400, url: request.url)
            }
            return MockTransport.json(Self.groupsJSON(headerImageURL: nil), url: request.url)
        }

        do {
            try await store.uploadHeaderImage(groupID: Self.groupID, data: Data([1]), contentType: "image/png")
            Issue.record("expected 400")
        } catch let error as APIError {
            #expect(error.status == 400)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }

        #expect(!transport.requests.contains { Self.isReload($0) })
    }

    // MARK: - Delete

    @Test func deleteHeaderImageSendsDeleteThenReloads() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            if request.httpMethod == "DELETE" {
                return MockTransport.json("", url: request.url)
            }
            return MockTransport.json(Self.groupsJSON(headerImageURL: nil), url: request.url)
        }

        try await store.deleteHeaderImage(groupID: Self.groupID)

        let delete = try #require(transport.requests.first { $0.httpMethod == "DELETE" })
        #expect(delete.url?.path.hasSuffix("/group/\(Self.groupID)/header-image") == true)
        let deleteIndex = try #require(transport.requests.firstIndex { $0.httpMethod == "DELETE" })
        let reloadIndex = try #require(transport.requests.firstIndex { Self.isReload($0) })
        #expect(deleteIndex < reloadIndex)
        #expect(store.isLoaded)
        #expect(store.byID(Self.groupID)?.headerImageURL == nil)
    }

    @Test func deleteHeaderImageNonAuthor401SurfacesWithoutReload() async throws {
        let transport = MockTransport()
        let store = makeStore(transport: transport)
        transport.handler = { request in
            MockTransport.json("", status: 401, url: request.url)
        }

        do {
            try await store.deleteHeaderImage(groupID: Self.groupID)
            Issue.record("expected 401")
        } catch let error as APIError {
            #expect(error.status == 401)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }

        #expect(transport.requests.count == 1)
        #expect(!transport.requests.contains { Self.isReload($0) })
    }

    // MARK: - Error copy mapping (web pin)

    @Test(arguments: [
        (401, GroupCoverPolicy.authorOnlyMessage),
        (403, GroupCoverPolicy.authorOnlyMessage),
        (503, GroupCoverPolicy.unavailableMessage),
        (413, ProfileImagePolicy.sizeMessage),
        (415, ProfileImagePolicy.typeMessage),
        (500, ProfileImagePolicy.genericUploadMessage),
    ])
    func coverErrorCopyMapsEveryPinnedStatus(status: Int, expected: String) {
        #expect(GroupCoverPolicy.errorMessage(status: status) == expected)
    }

    @Test func coverErrorCopyWithoutStatusFallsBackToGeneric() {
        #expect(GroupCoverPolicy.errorMessage(status: nil) == ProfileImagePolicy.genericUploadMessage)
    }
}
