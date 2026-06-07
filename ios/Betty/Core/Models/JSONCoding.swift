import Foundation

/// Shared JSON coding configuration for the Betty wire format.
///
/// Conventions: explicit `CodingKeys` on every model (no `convertFromSnakeCase` — the wire
/// has non-snake outliers like `PushTokens` and the WS `"Games"` key). Dates are Go RFC 3339
/// (`2026-06-07T12:34:56Z`, zero time `0001-01-01T00:00:00Z`), with or without fractional
/// seconds.
nonisolated enum JSONCoding {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(string, strategy: Date.ISO8601FormatStyle()) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unparseable RFC3339 date: \(string)")
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
