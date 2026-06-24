import Foundation
import Testing
@testable import Betty

/// Pins the `<strong>`-only HTML handling of toast messages (web renders `useNotify`
/// messages with `v-html`; bold is the only markup in product copy).
@Suite struct ToastMessageTextTests {
    private func segments(_ text: AttributedString) -> [(text: String, strong: Bool)] {
        text.runs.map { run in
            (
                text: String(text.characters[run.range]),
                strong: run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
            )
        }
    }

    @Test func plainTextPassesThrough() {
        let result = segments(ToastMessageText.attributed("Profile updated"))
        #expect(result.count == 1)
        #expect(result.first?.text == "Profile updated")
        #expect(result.first?.strong == false)
    }

    @Test func strongSegmentIsEmphasizedAndTagsStripped() {
        let result = segments(ToastMessageText.attributed("Join <strong>Office League</strong>?"))
        #expect(result.map(\.text) == ["Join ", "Office League", "?"])
        #expect(result.map(\.strong) == [false, true, false])
    }

    @Test func multipleStrongSegments() {
        let result = segments(ToastMessageText.attributed("<strong>A</strong> vs <strong>B</strong>"))
        #expect(result.map(\.text) == ["A", " vs ", "B"])
        #expect(result.map(\.strong) == [true, false, true])
    }

    @Test func bTagAlsoBolds() {
        let result = segments(ToastMessageText.attributed("a <b>c</b> d"))
        #expect(result.map(\.text) == ["a ", "c", " d"])
        #expect(result.map(\.strong) == [false, true, false])
    }

    @Test func unclosedStrongBoldsTheRemainder() {
        let result = segments(ToastMessageText.attributed("Already a member of <strong>X"))
        #expect(result.map(\.text) == ["Already a member of ", "X"])
        #expect(result.map(\.strong) == [false, true])
    }

    @Test func strayCloseTagStaysPlain() {
        let result = segments(ToastMessageText.attributed("a</strong>b"))
        #expect(result.count == 1)
        #expect(result.first?.text == "ab")
        #expect(result.first?.strong == false)
    }

    @Test func tagsAreCaseInsensitive() {
        let result = segments(ToastMessageText.attributed("<STRONG>x</STRONG> y"))
        #expect(result.map(\.text) == ["x", " y"])
        #expect(result.map(\.strong) == [true, false])
    }

    @Test func emptyMessageStaysEmpty() {
        #expect(ToastMessageText.attributed("").characters.isEmpty)
    }
}
