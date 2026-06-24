import Foundation
import Testing
@testable import Betty

private final class StubTokens: TokenProviding {
    var isSignedIn = true
    func validIDToken() async throws -> String { "token" }
    func tokenAfterAuthFailure() async throws -> String { "token" }
}

/// Pins the complete-profile gate: error-message precedence (web `CompleteProfileModal`),
/// canSave/country-label rules, and the POST /user → GET /user/me → optional PUT /user/me
/// submit sequence.
@Suite struct CompleteProfileTests {
    // MARK: message(for:) precedence

    @Test func sessionExpiredWinsOver401And403ServerMessages() {
        #expect(CompleteProfileView.message(for: .unauthorized(message: "Invalid API token"))
            == "Your session expired. Please sign in again.")
        #expect(CompleteProfileView.message(for: .forbidden(message: "blocked"))
            == "Your session expired. Please sign in again.")
    }

    @Test func fiveHundredsGetFriendlyRetryCopy() {
        let retry = "Something went wrong on our end. We're looking into it — please try again in a moment."
        #expect(CompleteProfileView.message(for: .server(status: 500, message: "panic: nil deref")) == retry)
        #expect(CompleteProfileView.message(for: .server(status: 502, message: nil)) == retry)
        #expect(CompleteProfileView.message(for: .serviceUnavailable) == retry)
    }

    @Test func serverMessageWinsForOtherStatuses() {
        #expect(CompleteProfileView.message(for: .badRequest(message: "name is required")) == "name is required")
        #expect(CompleteProfileView.message(for: .http(status: 418, message: "teapot")) == "teapot")
    }

    @Test func genericFallbackWhenNoMessage() {
        let fallback = "Couldn't save your profile. Please try again."
        #expect(CompleteProfileView.message(for: .badRequest(message: nil)) == fallback)
        #expect(CompleteProfileView.message(for: .notFound) == fallback)
        #expect(CompleteProfileView.message(for: .conflict) == fallback)
        #expect(CompleteProfileView.message(for: .transport(URLError(.notConnectedToInternet))) == fallback)
        #expect(CompleteProfileView.message(for: .decoding(URLError(.cannotDecodeRawData))) == fallback)
    }

    // MARK: form rules

    @Test func canSaveRequiresNonWhitespaceName() {
        #expect(!CompleteProfileView.canSave(name: ""))
        #expect(!CompleteProfileView.canSave(name: "   "))
        #expect(!CompleteProfileView.canSave(name: " \n\t"))
        #expect(CompleteProfileView.canSave(name: " Ada "))
        #expect(CompleteProfileView.canSave(name: "B"))
    }

    @Test func countryLabelPrefixesFlagOnlyWhenPresent() {
        #expect(CompleteProfileView.countryLabel(for: Country(code: "SE", name: "Sweden", flagEmoji: "🇸🇪"))
            == "🇸🇪 Sweden")
        #expect(CompleteProfileView.countryLabel(for: Country(code: "XX", name: "Nowhere", flagEmoji: nil))
            == "Nowhere")
        #expect(CompleteProfileView.countryLabel(for: Country(code: "YY", name: "Empty", flagEmoji: ""))
            == "Empty")
    }

    // MARK: submit flow

    private static func profileJSON(country: String? = nil) -> String {
        let countryField = country.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "id": "uid-1",
          "email": "ada@b.co",
          "name": "Ada",
          "image_url": null,
          "firebase_image_url": null,
          "country": \(countryField),
          "created_at": "2026-01-01T10:00:00Z",
          "updated_at": "2026-01-01T10:00:00Z",
          "is_admin": false
        }
        """
    }

    /// POST /user 201 echo — zero timestamps (year 1), which is why UserStore re-GETs.
    private static let createEchoJSON = """
    {
      "id": "uid-1",
      "email": "ada@b.co",
      "name": "Ada",
      "image_url": null,
      "firebase_image_url": null,
      "country": null,
      "created_at": "0001-01-01T00:00:00Z",
      "updated_at": "0001-01-01T00:00:00Z",
      "is_admin": false
    }
    """

    private func makeStore(transport: MockTransport) -> UserStore {
        UserStore(api: APIClient(transport: transport, tokens: StubTokens()))
    }

    @Test func submitCreatesProfileThenAppliesCountry() async throws {
        let transport = MockTransport()
        transport.handler = { request in
            switch (request.httpMethod, request.url!.path) {
            case ("POST", "/api/v1/user"):
                return MockTransport.json(Self.createEchoJSON, status: 201, url: request.url)
            case ("GET", "/api/v1/user/me"):
                return MockTransport.json(Self.profileJSON(), url: request.url)
            case ("PUT", "/api/v1/user/me"):
                return MockTransport.json(Self.profileJSON(country: "SE"), url: request.url)
            default:
                Issue.record("unexpected request \(request.httpMethod ?? "?") \(request.url!.path)")
                return MockTransport.json("{}", status: 500, url: request.url)
            }
        }
        let store = makeStore(transport: transport)

        let outcome = await CompleteProfileFlow.submit(
            userStore: store, email: "ada@b.co", name: "Ada", imageURL: nil, country: "SE"
        )

        #expect(outcome == CompleteProfileFlow.Outcome())
        #expect(transport.requests.map { "\($0.httpMethod!) \($0.url!.path)" } == [
            "POST /api/v1/user",
            "GET /api/v1/user/me",
            "PUT /api/v1/user/me",
        ])
        // PUT body carries name + country (only fields the backend applies).
        let putBody = try #require(transport.requests[2].httpBody)
        let payload = try #require(try JSONSerialization.jsonObject(with: putBody) as? [String: Any])
        #expect(payload["name"] as? String == "Ada")
        #expect(payload["country"] as? String == "SE")
        #expect(store.profile?.country == "SE")
        #expect(!store.needsProfile)
    }

    @Test func submitWithoutCountrySkipsTheUpdate() async {
        let transport = MockTransport()
        transport.handler = { request in
            switch (request.httpMethod, request.url!.path) {
            case ("POST", "/api/v1/user"):
                return MockTransport.json(Self.createEchoJSON, status: 201, url: request.url)
            case ("GET", "/api/v1/user/me"):
                return MockTransport.json(Self.profileJSON(), url: request.url)
            default:
                Issue.record("unexpected request \(request.url!.path)")
                return MockTransport.json("{}", status: 500, url: request.url)
            }
        }
        let store = makeStore(transport: transport)

        let outcome = await CompleteProfileFlow.submit(
            userStore: store, email: "ada@b.co", name: "Ada", imageURL: nil, country: nil
        )

        #expect(outcome == CompleteProfileFlow.Outcome())
        #expect(transport.requests.count == 2)
        #expect(store.profile?.id == "uid-1")
    }

    @Test func createFailureIsBlockingAndSkipsCountryStep() async {
        let transport = MockTransport()
        transport.handler = { request in
            MockTransport.json(#"{"error": "name is required"}"#, status: 400, url: request.url)
        }
        let store = makeStore(transport: transport)

        let outcome = await CompleteProfileFlow.submit(
            userStore: store, email: "ada@b.co", name: "Ada", imageURL: nil, country: "SE"
        )

        #expect(outcome.blockingErrorMessage == "name is required")
        #expect(outcome.countryWarningMessage == nil)
        #expect(transport.requests.count == 1) // POST only — no GET, no PUT
        #expect(store.profile == nil)
    }

    @Test func countryUpdateFailureIsNonBlockingWarning() async {
        let transport = MockTransport()
        transport.handler = { request in
            switch (request.httpMethod, request.url!.path) {
            case ("POST", "/api/v1/user"):
                return MockTransport.json(Self.createEchoJSON, status: 201, url: request.url)
            case ("GET", "/api/v1/user/me"):
                return MockTransport.json(Self.profileJSON(), url: request.url)
            default: // PUT /user/me fails
                return MockTransport.json("{}", status: 500, url: request.url)
            }
        }
        let store = makeStore(transport: transport)

        let outcome = await CompleteProfileFlow.submit(
            userStore: store, email: "ada@b.co", name: "Ada", imageURL: nil, country: "SE"
        )

        #expect(outcome.blockingErrorMessage == nil)
        #expect(outcome.countryWarningMessage == CompleteProfileFlow.countryWarning)
        // The created profile survives — the gate still comes down.
        #expect(store.profile?.id == "uid-1")
        #expect(store.profile?.country == nil)
        #expect(!store.needsProfile)
    }
}
