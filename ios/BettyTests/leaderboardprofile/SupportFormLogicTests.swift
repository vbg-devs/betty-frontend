import Foundation
import Testing
@testable import Betty

/// Pins the web `/support` feature-request form rules: 5000-char budget, the <200
/// warning threshold, trimmed payloads, and the in-flight submit guard.
@Suite struct SupportFormLogicTests {
    @Test func startsWithFullBudgetAndDisabledSubmit() {
        #expect(SupportFormLogic.remaining("") == 5000)
        #expect(!SupportFormLogic.canSubmit(text: "", isSubmitting: false))
    }

    @Test func remainingCountsDown() {
        #expect(SupportFormLogic.remaining("Hello") == 4995)
    }

    @Test func whitespaceOnlyInputCannotSubmit() {
        #expect(!SupportFormLogic.canSubmit(text: "   \n\t ", isSubmitting: false))
    }

    @Test func textEnablesSubmit() {
        #expect(SupportFormLogic.canSubmit(text: "More cowbell", isSubmitting: false))
    }

    @Test func inFlightSubmitIsIgnored() {
        #expect(!SupportFormLogic.canSubmit(text: "More cowbell", isSubmitting: true))
    }

    @Test func warnsOnlyWhenFewerThan200CharactersRemain() {
        let exactly200Left = String(repeating: "a", count: 4800)
        #expect(!SupportFormLogic.warnsLowBudget(exactly200Left)) // 200 left → no warn (strict <)
        let only199Left = String(repeating: "a", count: 4801)
        #expect(SupportFormLogic.warnsLowBudget(only199Left))
    }

    @Test func clampsPastedOverflowToMaxLength() {
        let oversized = String(repeating: "x", count: 5005)
        let clamped = SupportFormLogic.clamped(oversized)
        #expect(clamped.count == 5000)
        #expect(SupportFormLogic.clamped("short") == "short")
    }

    @Test func payloadIsTrimmed() {
        #expect(SupportFormLogic.trimmed("  An idea \n") == "An idea")
    }
}
