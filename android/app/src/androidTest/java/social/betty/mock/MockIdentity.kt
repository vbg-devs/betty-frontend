package social.betty.mock

import org.json.JSONObject

/**
 * Firebase Auth over REST — the Identity Toolkit v1 + securetoken endpoints the app talks to
 * directly (api-contract.md §1). All errors are 400 with the
 * `{"error":{"code":400,"message":"<CODE>", ...}}` envelope.
 */
fun BettyMockBackend.registerIdentityRoutes() {
    // 1.1 Email/password sign-in
    http.route("POST", "/v1/accounts:signInWithPassword") { request, _ ->
        val body = request.bodyJson ?: JSONObject()
        val email = body.optString("email", "")
        val password = body.optString("password", "")
        withScenario { scenario ->
            val user = scenario.userByEmail(email)
                ?: return@withScenario MockWire.firebaseError("EMAIL_NOT_FOUND")
            if (user.password != password) {
                return@withScenario MockWire.firebaseError("INVALID_LOGIN_CREDENTIALS")
            }
            MockHttpResponse.json(
                JSONObject().apply {
                    put("kind", "identitytoolkit#VerifyPasswordResponse")
                    put("localId", user.id)
                    put("email", user.email)
                    put("displayName", user.name)
                    put("idToken", idToken(user.id))
                    put("registered", true)
                    put("refreshToken", refreshToken(user.id))
                    put("expiresIn", "3600") // STRING of seconds
                },
            )
        }
    }

    // 1.2 Email/password sign-up
    http.route("POST", "/v1/accounts:signUp") { request, _ ->
        val body = request.bodyJson ?: JSONObject()
        val email = body.optString("email", "")
        val password = body.optString("password", "")
        withScenario { scenario ->
            if (scenario.userByEmail(email) != null) {
                return@withScenario MockWire.firebaseError("EMAIL_EXISTS")
            }
            if (password.length < 6) {
                return@withScenario MockWire.firebaseError("WEAK_PASSWORD : Password should be at least 6 characters")
            }
            val uid = "uid-signup-${scenario.nextSignupNumber}"
            scenario.nextSignupNumber += 1
            // New Firebase account: NO profile row yet → GET /user/me 404s
            // (onboarding gate), exactly like production.
            scenario.users.add(MockUser(id = uid, email = email, name = "", password = password, hasProfile = false))
            MockHttpResponse.json(
                JSONObject().apply {
                    put("kind", "identitytoolkit#SignupNewUserResponse")
                    put("idToken", idToken(uid))
                    put("email", email)
                    put("refreshToken", refreshToken(uid))
                    put("expiresIn", "3600")
                    put("localId", uid)
                },
            )
        }
    }

    // 1.3 Federated sign-in (Apple/Google). Instrumented tests cannot drive the OS sheets, so
    // e2e coverage stops at the boundary — this endpoint exists for completeness and for the
    // needConfirmation error path.
    http.route("POST", "/v1/accounts:signInWithIdp") { request, _ ->
        val body = request.bodyJson ?: JSONObject()
        val postBody = MockHttpRequest.parseForm(body.optString("postBody", ""))
        val providerId = postBody["providerId"] ?: "apple.com"
        withScenario { scenario ->
            if (scenario.idpNeedsConfirmation) {
                // 200 WITHOUT localId/idToken/refreshToken — sign-in did not complete.
                return@withScenario MockHttpResponse.json(
                    JSONObject().apply {
                        put("kind", "identitytoolkit#VerifyAssertionResponse")
                        put("needConfirmation", true)
                        put("email", scenario.users.firstOrNull()?.email ?: "")
                        put("providerId", providerId)
                    },
                )
            }
            val uid = scenario.idpUserId ?: scenario.users.firstOrNull()?.id ?: ""
            val user = scenario.user(uid)
                ?: return@withScenario MockWire.firebaseError("INVALID_IDP_RESPONSE")
            val response = JSONObject().apply {
                put("kind", "identitytoolkit#VerifyAssertionResponse")
                put("localId", user.id)
                put("federatedId", "$providerId/${user.id}")
                put("providerId", providerId)
                put("email", user.email)
                put("emailVerified", true)
                put("idToken", idToken(user.id))
                put("refreshToken", refreshToken(user.id))
                put("expiresIn", "3600")
                put("rawUserInfo", "{}")
            }
            if (user.name.isNotEmpty()) response.put("displayName", user.name)
            user.firebaseImageUrl?.let { response.put("photoUrl", it) }
            if (!user.hasProfile) response.put("isNewUser", true) // only present when true
            MockHttpResponse.json(response)
        }
    }

    // 1.4 Token refresh (securetoken.googleapis.com) — snake_case keys.
    http.route("POST", "/v1/token") { request, _ ->
        val form = request.bodyForm
        val token = form["refresh_token"]
        val uid = token?.let { uidFromRefreshToken(it) }
        val valid = form["grant_type"] == "refresh_token" &&
            uid != null &&
            withScenario { it.user(uid) != null }
        if (!valid || uid == null) {
            return@route MockWire.firebaseError("INVALID_REFRESH_TOKEN")
        }
        val id = idToken(uid)
        MockHttpResponse.json(
            JSONObject().apply {
                put("access_token", id)
                put("expires_in", "3600")
                put("token_type", "Bearer")
                put("refresh_token", refreshToken(uid)) // may rotate — same here
                put("id_token", id)
                put("user_id", uid)
                put("project_id", "406964826017")
            },
        )
    }
}
