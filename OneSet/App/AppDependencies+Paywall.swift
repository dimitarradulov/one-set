import Foundation

extension AppDependencies {
  /// Approval backed by the account owner. Falls back to a refusing approval when
  /// `subscriptionAccess` is a preview or test fake, so those never reach RevenueCat.
  var paywallApproval: any PaywallApproving {
    OwnerPaywallApproval.make(for: subscriptionAccess)
  }

  /// The live RevenueCatUI host with the owner, and a fake host for previews and tests.
  var paywallHost: any PaywallHost {
    #if DEBUG
    if !(subscriptionAccess is any SubscriptionOperationOwner) { return FakePaywallHost() }
    #endif
    return RevenueCatPaywallHost()
  }

  /// Builds the checkout model for the selection the screen is showing. `currentSelection`
  /// reports the app's selection now, so a changed account closes the sheet.
  func makePaywallModel(
    selection: AccountSelection,
    currentSelection: @escaping @MainActor () -> AccountSelection?,
    onResult: @escaping @MainActor (PaywallResult) -> Void
  ) -> PaywallModel {
    PaywallModel(
      selection: selection, currentSelection: currentSelection, access: subscriptionAccess,
      host: paywallHost, approval: paywallApproval, onResult: onResult)
  }
}
