import Foundation

/// Central error type for the Betty REST API. Carries the HTTP status so views can
/// reproduce the web's status-code branching (401/403/404/409/410/413/415/423/503, >=500).
///
/// Note: most error bodies are EMPTY — only the status carries meaning. The auth
/// middleware and a few validators return `{"error": "..."}`, surfaced via `serverMessage`.
nonisolated enum APIError: Error {
    /// Thrown before any network I/O when there is no signed-in user.
    case notAuthenticated
    /// 401 after the automatic token refresh + retry.
    case unauthorized(message: String?)
    /// 403 — blocked from group / non-admin / not a message-board member.
    case forbidden(message: String?)
    /// 404 — unknown resource (also: /user/me with no profile row yet).
    case notFound
    /// 409 — already a member.
    case conflict
    /// 410 Gone — game already evaluated.
    case gone
    /// 413 — upload larger than 1 MiB.
    case payloadTooLarge
    /// 415 — content type not in image/jpeg|png|webp|gif.
    case unsupportedMediaType
    /// 423 Locked — game already started (POST /bet, PUT /bet/:id).
    case locked
    /// 503 — R2 storage disabled / uploads temporarily unavailable.
    case serviceUnavailable
    /// 400 with the decoded `{"error": ...}`/`{"message": ...}` body when present.
    case badRequest(message: String?)
    /// Any 5xx.
    case server(status: Int, message: String?)
    /// Any other non-2xx status.
    case http(status: Int, message: String?)
    /// Request body could not be encoded — thrown before any network I/O.
    case encoding(Error)
    /// Body arrived but could not be decoded into the expected model.
    case decoding(Error)
    /// URLSession-level failure (offline, DNS, TLS, ...).
    case transport(Error)

    init(status: Int, data: Data) {
        let message = Self.extractMessage(from: data)
        switch status {
        case 401: self = .unauthorized(message: message)
        case 403: self = .forbidden(message: message)
        case 404: self = .notFound
        case 409: self = .conflict
        case 410: self = .gone
        case 413: self = .payloadTooLarge
        case 415: self = .unsupportedMediaType
        case 423: self = .locked
        case 503: self = .serviceUnavailable
        case 400: self = .badRequest(message: message)
        case 500...599: self = .server(status: status, message: message)
        default: self = .http(status: status, message: message)
        }
    }

    /// HTTP status, when one applies — mirrors the web's `response.status ?? statusCode`
    /// branching helper.
    var status: Int? {
        switch self {
        case .notAuthenticated, .encoding, .decoding, .transport: nil
        case .unauthorized: 401
        case .forbidden: 403
        case .notFound: 404
        case .conflict: 409
        case .gone: 410
        case .payloadTooLarge: 413
        case .unsupportedMediaType: 415
        case .locked: 423
        case .serviceUnavailable: 503
        case .badRequest: 400
        case .server(let status, _): status
        case .http(let status, _): status
        }
    }

    var serverMessage: String? {
        switch self {
        case .unauthorized(let m), .forbidden(let m), .badRequest(let m),
             .server(_, let m), .http(_, let m):
            m
        default:
            nil
        }
    }

    private static func extractMessage(from data: Data) -> String? {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return (object["error"] as? String) ?? (object["message"] as? String)
    }
}
