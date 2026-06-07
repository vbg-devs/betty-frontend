import Foundation
import Testing
@testable import Betty

@Suite struct JoinInviteOutcomeTests {
    @Test func conflictMeansAlreadyMember() {
        #expect(JoinInviteOutcome.map(APIError.conflict) == .alreadyMember)
    }

    @Test func notFoundMeansInvalidInvite() {
        #expect(JoinInviteOutcome.map(APIError.notFound) == .invalidInvite)
    }

    @Test func forbiddenMeansBlocked() {
        #expect(JoinInviteOutcome.map(APIError.forbidden(message: nil)) == .blocked)
    }

    @Test func otherStatusesAreGenericFailures() {
        #expect(JoinInviteOutcome.map(APIError.server(status: 500, message: nil)) == .failed)
        #expect(JoinInviteOutcome.map(APIError.unauthorized(message: nil)) == .failed)
        #expect(JoinInviteOutcome.map(APIError.locked) == .failed)
        #expect(JoinInviteOutcome.map(APIError.notAuthenticated) == .failed)
    }

    @Test func nonAPIErrorsAreGenericFailures() {
        #expect(JoinInviteOutcome.map(URLError(.notConnectedToInternet)) == .failed)
    }
}
