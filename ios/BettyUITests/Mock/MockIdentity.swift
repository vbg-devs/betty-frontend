import Foundation

/// Firebase Auth over REST — the Identity Toolkit v1 + securetoken endpoints the app
/// talks to directly (api-contract.md §1). All errors are 400 with the
/// `{"error":{"code":400,"message":"<CODE>", ...}}` envelope.
extension BettyMockBackend {
    func registerIdentityRoutes() {
        // 1.1 Email/password sign-in
        http.route("POST", "/v1/accounts:signInWithPassword") { [weak self] request, _ in
            guard let self else { return .empty(500) }
            let body = request.bodyJSON ?? [:]
            let email = body["email"] as? String ?? ""
            let password = body["password"] as? String ?? ""
            return self.withScenario { scenario in
                guard let user = scenario.userByEmail(email) else {
                    return MockWire.firebaseError("EMAIL_NOT_FOUND")
                }
                guard user.password == password else {
                    return MockWire.firebaseError("INVALID_LOGIN_CREDENTIALS")
                }
                return .json([
                    "kind": "identitytoolkit#VerifyPasswordResponse",
                    "localId": user.id,
                    "email": user.email,
                    "displayName": user.name,
                    "idToken": self.idToken(for: user.id),
                    "registered": true,
                    "refreshToken": self.refreshToken(for: user.id),
                    "expiresIn": "3600", // STRING of seconds
                ])
            }
        }

        // 1.2 Email/password sign-up
        http.route("POST", "/v1/accounts:signUp") { [weak self] request, _ in
            guard let self else { return .empty(500) }
            let body = request.bodyJSON ?? [:]
            let email = body["email"] as? String ?? ""
            let password = body["password"] as? String ?? ""
            return self.withScenario { scenario in
                guard scenario.userByEmail(email) == nil else {
                    return MockWire.firebaseError("EMAIL_EXISTS")
                }
                guard password.count >= 6 else {
                    return MockWire.firebaseError("WEAK_PASSWORD : Password should be at least 6 characters")
                }
                let uid = "uid-signup-\(scenario.nextSignupNumber)"
                scenario.nextSignupNumber += 1
                // New Firebase account: NO profile row yet → GET /user/me 404s
                // (onboarding gate), exactly like production.
                scenario.users.append(MockUser(id: uid, email: email, name: "",
                                               password: password, hasProfile: false))
                return .json([
                    "kind": "identitytoolkit#SignupNewUserResponse",
                    "idToken": self.idToken(for: uid),
                    "email": email,
                    "refreshToken": self.refreshToken(for: uid),
                    "expiresIn": "3600",
                    "localId": uid,
                ])
            }
        }

        // 1.3 Federated sign-in (Apple/Google). XCUITest cannot drive the OS sheets, so
        // e2e coverage stops at the boundary — this endpoint exists for completeness and
        // for the needConfirmation error path.
        http.route("POST", "/v1/accounts:signInWithIdp") { [weak self] request, _ in
            guard let self else { return .empty(500) }
            let body = request.bodyJSON ?? [:]
            let postBody = MockHTTPRequest.parseForm(body["postBody"] as? String ?? "")
            let providerID = postBody["providerId"] ?? "apple.com"
            return self.withScenario { scenario in
                if scenario.idpNeedsConfirmation {
                    // 200 WITHOUT localId/idToken/refreshToken — sign-in did not complete.
                    return .json([
                        "kind": "identitytoolkit#VerifyAssertionResponse",
                        "needConfirmation": true,
                        "email": scenario.users.first?.email ?? "",
                        "providerId": providerID,
                    ])
                }
                let uid = scenario.idpUserID ?? scenario.users.first?.id ?? ""
                guard let user = scenario.user(uid) else {
                    return MockWire.firebaseError("INVALID_IDP_RESPONSE")
                }
                var response: [String: Any] = [
                    "kind": "identitytoolkit#VerifyAssertionResponse",
                    "localId": user.id,
                    "federatedId": "\(providerID)/\(user.id)",
                    "providerId": providerID,
                    "email": user.email,
                    "emailVerified": true,
                    "idToken": self.idToken(for: user.id),
                    "refreshToken": self.refreshToken(for: user.id),
                    "expiresIn": "3600",
                    "rawUserInfo": "{}",
                ]
                if !user.name.isEmpty { response["displayName"] = user.name }
                if let photo = user.firebaseImageURL { response["photoUrl"] = photo }
                if !user.hasProfile { response["isNewUser"] = true } // only present when true
                return .json(response)
            }
        }

        // 1.4 Token refresh (securetoken.googleapis.com) — snake_case keys.
        http.route("POST", "/v1/token") { [weak self] request, _ in
            guard let self else { return .empty(500) }
            let form = request.bodyForm
            guard form["grant_type"] == "refresh_token",
                  let token = form["refresh_token"],
                  let uid = self.uid(fromRefreshToken: token),
                  self.withScenario({ $0.user(uid) != nil })
            else {
                return MockWire.firebaseError("INVALID_REFRESH_TOKEN")
            }
            let idToken = self.idToken(for: uid)
            return .json([
                "access_token": idToken,
                "expires_in": "3600",
                "token_type": "Bearer",
                "refresh_token": self.refreshToken(for: uid), // may rotate — same here
                "id_token": idToken,
                "user_id": uid,
                "project_id": "406964826017",
            ])
        }
    }
}
