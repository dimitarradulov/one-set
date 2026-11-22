import SwiftUI

/// Placeholder checkout entry point shown by "See plans". Ticket #99 replaces this view with the
/// paywall. The seam stays the same: the sheet is presented for a `PlansRequest`, purchases and
/// restores go through the subscription service, and the outcome returns through
/// `OnboardingModel.finishCheckout`. Closing the sheet calls `OnboardingModel.dismissPlans`.
struct SubscriptionPlansSheet: View {
  let model: OnboardingModel
  let request: PlansRequest

  @State private var isPurchasing = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("OneSet Pro")
          .font(OneSetTypography.h1)
          .foregroundStyle(OneSetColors.textPrimary)
        Text("Plans are on the way. Start a new workout once Pro is active.")
          .font(OneSetTypography.body)
          .foregroundStyle(OneSetColors.textSecondary)
          .multilineTextAlignment(.center)
        if let errorMessage {
          Text(errorMessage)
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.error)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("plans.error")
        }
        Button {
          Task { await purchase() }
        } label: {
          Text(isPurchasing ? "Working…" : "Choose Monthly")
            .font(OneSetTypography.button)
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
        .accessibilityIdentifier("plans.choose")
      }
      .frame(maxWidth: 480)
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(OneSetColors.background)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") { model.dismissPlans() }
            .accessibilityIdentifier("plans.close")
        }
      }
    }
    .preferredColorScheme(.dark)
    .presentationDetents([.medium, .large])
  }

  private func purchase() async {
    isPurchasing = true
    errorMessage = nil
    defer { isPurchasing = false }
    do {
      try await model.purchasePlan(SubscriptionPackage(id: "$rc_monthly"), request: request)
    } catch SubscriptionOperationError.cancelled {
      return
    } catch {
      errorMessage = "Plans aren’t available right now. Try again later."
    }
  }
}
