import Foundation

/// Web `UpdateProfileModal` image rules — validation order, byte caps, and the exact
/// user-facing copy are pinned by the web test suite.
nonisolated enum ProfileImagePolicy {
    static let allowedTypes = ["image/png", "image/jpeg", "image/webp", "image/gif"]
    /// 1 MiB — exactly 1 MiB is OK (backend cap).
    static let maxBytes = 1_048_576

    static let typeMessage = "Please choose a PNG, JPG, WEBP, or GIF image."
    static let sizeMessage = "That image is over 1 MB — please pick a smaller one."
    static let emptyMessage = "That file looks empty. Please choose another image."
    static let genericUploadMessage = "Couldn't upload your photo. Please try again."
    static let revertFailedMessage = "Couldn't revert your photo. Please try again."

    /// Pre-upload validation: type first, then size, then emptiness (web order).
    static func validationError(contentType: String, byteCount: Int) -> String? {
        if !allowedTypes.contains(contentType) { return typeMessage }
        if byteCount > maxBytes { return sizeMessage }
        if byteCount == 0 { return emptyMessage }
        return nil
    }

    /// Upload/commit failure mapping: 413 → size copy, 415 → type copy, anything else generic.
    static func uploadErrorMessage(status: Int?) -> String {
        switch status {
        case 413: sizeMessage
        case 415: typeMessage
        default: genericUploadMessage
        }
    }

    /// Revert button visibility: a non-empty image that isn't the provider (Firebase) photo.
    static func hasCustomImage(imageURL: String?, firebaseImageURL: String?) -> Bool {
        guard let imageURL, !imageURL.isEmpty else { return false }
        guard let firebaseImageURL, !firebaseImageURL.isEmpty else { return true }
        return imageURL != firebaseImageURL
    }

    /// Magic-byte sniffing for the picked asset (PhotosPicker has no reliable MIME).
    static func sniffContentType(_ data: Data) -> String? {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "image/gif" }
        if data.count >= 12,
           data.starts(with: [0x52, 0x49, 0x46, 0x46]),
           data.subdata(in: data.startIndex.advanced(by: 8)..<data.startIndex.advanced(by: 12))
               .elementsEqual([0x57, 0x45, 0x42, 0x50]) {
            return "image/webp"
        }
        return nil
    }
}

/// Web `/support` feature-request form rules.
nonisolated enum SupportFormLogic {
    static let maxLength = 5000
    /// Counter turns orange when fewer than this many characters remain (strict <).
    static let lowBudgetThreshold = 200

    /// The web textarea enforces `maxlength` — clamp pasted overflow the same way.
    static func clamped(_ text: String) -> String {
        text.count <= maxLength ? text : String(text.prefix(maxLength))
    }

    static func remaining(_ text: String) -> Int {
        maxLength - text.count
    }

    static func warnsLowBudget(_ text: String) -> Bool {
        remaining(text) < lowBudgetThreshold
    }

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Submit enabled only when not in flight and the trimmed text is non-empty.
    static func canSubmit(text: String, isSubmitting: Bool) -> Bool {
        !isSubmitting && !trimmed(text).isEmpty
    }
}

/// Web `/leaderboard/[id]` hero + picker rules.
nonisolated enum GlobalLeaderboardLogic {
    /// Hero title split: two or fewer words stay on one line; otherwise the first
    /// ceil(n/2) words take line one and the rest line two. Empty/missing name falls
    /// back to "TOURNAMENT". Always uppercased.
    static func titleParts(_ name: String?) -> (String, String) {
        let base = ((name?.isEmpty == false) ? name! : "TOURNAMENT").uppercased()
        let words = base.components(separatedBy: " ")
        if words.count <= 2 { return (base, "") }
        let mid = (words.count + 1) / 2
        return (
            words[0..<mid].joined(separator: " "),
            words[mid...].joined(separator: " ")
        )
    }

    /// Ended = end date strictly in the past; no end date or ending exactly now is NOT ended.
    static func isEnded(_ tournament: Tournament, at now: Date = Date()) -> Bool {
        guard let end = tournament.endDate else { return false }
        return end < now
    }

    static func pickerLabel(for tournament: Tournament, at now: Date = Date()) -> String {
        isEnded(tournament, at: now) ? "\(tournament.name) · ENDED" : tournament.name
    }

    /// Web prints the raw JSON number: integer-valued scores have no decimal point.
    static func scoreText(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
