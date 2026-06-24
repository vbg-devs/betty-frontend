import Foundation

/// `storage.PresignedUpload` — both upload-url endpoints.
///
/// `headers` is Go `http.Header`: map of string → ARRAY of strings. Upload flow: PUT the
/// raw bytes to `uploadURL` with exactly the declared Content-Type and byte count (both
/// are baked into the signature), then commit `publicURL` via the matching PUT endpoint.
nonisolated struct PresignedUpload: Decodable, Hashable, Sendable {
    let key: String
    let uploadURL: String
    let method: String
    let headers: [String: [String]]
    let publicURL: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case key, method, headers
        case uploadURL = "upload_url"
        case publicURL = "public_url"
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        uploadURL = try c.decode(String.self, forKey: .uploadURL)
        method = try c.decodeIfPresent(String.self, forKey: .method) ?? "PUT"
        headers = try c.decodeIfPresent([String: [String]].self, forKey: .headers) ?? [:]
        publicURL = try c.decode(String.self, forKey: .publicURL)
        expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt) ?? .distantFuture
    }
}

/// Body for both presign endpoints. Limits: jpeg/png/webp/gif, <= 1 MiB
/// (415 bad type, 413 too large, 503 storage disabled).
nonisolated struct UploadURLRequest: Encodable, Sendable {
    var contentType: String
    var contentLength: Int

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case contentLength = "content_length"
    }
}
