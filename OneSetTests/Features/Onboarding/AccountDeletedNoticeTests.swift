import Testing
@testable import OneSet

@MainActor
struct AccountDeletedNoticeTests {
  @Test func noticeIsPendingOnlyAfterADeletionAndClearsOnDismiss() {
    let model = OnboardingModel(catalog: .bundled)
    #expect(!model.accountDeletedNoticePending)

    model.noteAccountDeleted()
    #expect(model.accountDeletedNoticePending)

    model.dismissAccountDeletedNotice()
    #expect(!model.accountDeletedNoticePending)
  }
}
