package social.betty.core.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

/**
 * Go `time.Time` JSON ↔ [Instant]. Timestamps are RFC 3339 UTC (api-contract.md
 * "Conventions"), e.g. `2026-06-07T12:34:56Z`; the Go zero time `0001-01-01T00:00:00Z`
 * also appears on the wire (POST /bet, POST /user echoes) and must round-trip. Tolerant of
 * fractional seconds.
 */
object InstantSerializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("Instant", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Instant) {
        encoder.encodeString(DateTimeFormatter.ISO_INSTANT.format(value))
    }

    override fun deserialize(decoder: Decoder): Instant {
        val raw = decoder.decodeString()
        return parse(raw)
    }

    fun parse(raw: String): Instant = runCatching { Instant.parse(raw) }
        .recoverCatching { OffsetDateTime.parse(raw).toInstant() }
        .getOrDefault(Instant.EPOCH)
}

/** Go's zero time, used to detect request-echo timestamps that aren't real. */
val GO_ZERO_TIME: Instant = InstantSerializer.parse("0001-01-01T00:00:00Z")

fun Instant.isZeroTime(): Boolean = this == GO_ZERO_TIME || this == Instant.EPOCH
