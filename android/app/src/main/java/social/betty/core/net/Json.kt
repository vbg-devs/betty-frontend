package social.betty.core.net

import kotlinx.serialization.json.Json

/**
 * Tolerant decoder for the Go backend: ignores unknown keys (e.g. the always-null
 * `PushTokens`), coerces wire `null` arrays to the property default (`null` → `emptyList()`
 * for `/groups`, `/teams`, `/tournaments`, `reactions`, …), and omits nulls when encoding
 * request bodies. Request bodies that require an explicit `null` (nickname/settings clears)
 * are built with `buildJsonObject` instead.
 */
val BettyJson: Json = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
    explicitNulls = false
    isLenient = true
}
