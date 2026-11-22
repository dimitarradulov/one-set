import SwiftUI

/// The OneSet parent screen around the embedded paywall. It owns Close, Restore Purchases,
/// Manage Subscription, and the verification states, so they work even without an offering.
struct PaywallSheetView: View {
  @Bindable var model: PaywallModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(spacing: 0) {
      topBar
      content
      footer
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(OneSetColors.background)
    .presentationBackground(OneSetColors.background)
    .task { await model.start() }
    .onChange(of: model.result) { _, result in
      if result != nil { dismiss() }
    }
    .onDisappear { model.dismiss() }
  }

  private var topBar: some View {
    HStack {
      Spacer()
      Button(action: model.close) {
        Image(systemName: "xmark")
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textPrimary)
          .frame(width: 44, height: 44)
          .background(OneSetColors.surfaceRaised, in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Close")
      .accessibilityIdentifier("paywall.close")
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
  }

  @ViewBuilder private var content: some View {
    switch model.phase {
    case .ready:
      if let offering = model.offering {
        model.host.makePaywall(for: offering, events: model.events)
          .frame(maxWidth: 640)
          .frame(maxWidth: .infinity)
          .accessibilityIdentifier("paywall.host")
      }
    default:
      statusContent
    }
  }

  private var statusContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 12) {
          Text("OneSet Pro")
            .font(OneSetTypography.display)
            .foregroundStyle(OneSetColors.textPrimary)
            .accessibilityAddTraits(.isHeader)
          Text("Start workouts from guided HIT programs and log your working sets.")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        phaseNotice
      }
      .frame(maxWidth: 560, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.top, 8)
      .padding(.bottom, 24)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
  }

  @ViewBuilder private var phaseNotice: some View {
    switch model.phase {
    case .loading:
      PaywallNotice(icon: .spinner, title: "Loading plans", message: "Checking the available subscriptions.")
    case .unavailable:
      PaywallNotice(
        icon: .symbol("exclamationmark.triangle"), title: "Plans are unavailable",
        message: "Try loading the plans again, or restore a previous purchase.")
    case .verifying(.purchase):
      PaywallNotice(
        icon: .spinner, title: "Verifying your purchase",
        message: "We are checking Pro access for this OneSet account.")
    case .verifying(.restore):
      PaywallNotice(
        icon: .spinner, title: "Restoring purchases", message: "Checking for an active Apple subscription.")
    case .verifyFailed(.purchase):
      PaywallNotice(
        icon: .symbol("exclamationmark.triangle"), title: "Purchase verification failed",
        message: "Apple confirmed your purchase. Try checking Pro access again.")
    case .verifyFailed(.restore):
      PaywallNotice(
        icon: .symbol("exclamationmark.triangle"), title: "Restore could not be verified",
        message: "Try checking Pro access again.")
    case .pending:
      PaywallNotice(
        icon: .symbol("clock"), title: "Waiting for purchase approval",
        message: "Check again after Apple approves the purchase.")
    case .active:
      PaywallNotice(
        icon: .symbol("checkmark.circle"), title: "OneSet Pro is active",
        message: "You can start a workout from your program.")
    case .ready:
      EmptyView()
    }
  }

  private var footer: some View {
    VStack(spacing: 4) {
      if let banner = model.banner {
        PaywallNotice(
          icon: .symbol("exclamationmark.triangle"), title: banner.title, message: banner.message,
          identifier: "paywall.banner"
        )
        .padding(.bottom, 8)
      }
      if let action = primaryAction {
        Button(action: action.run) {
          Text(action.title)
            .font(OneSetTypography.button)
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall.primaryAction")
      }
      billingTools
    }
    .frame(maxWidth: 560)
    .padding(.horizontal, 20)
    .padding(.top, 8)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity)
  }

  private var billingTools: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) { restoreButton; manageButton }
      VStack(spacing: 0) { restoreButton; manageButton }
    }
  }

  private var restoreButton: some View {
    Button("Restore Purchases") { Task { await model.restorePurchases() } }
      .font(OneSetTypography.label)
      .foregroundStyle(model.isBusy ? OneSetColors.textTertiary : OneSetColors.accent)
      .frame(minHeight: 44)
      .padding(.horizontal, 8)
      .disabled(model.isBusy)
      .accessibilityIdentifier("paywall.restore")
  }

  private var manageButton: some View {
    Button("Manage Subscription") {
      Task { await ManageSubscriptions.open(fallback: openURL) }
    }
    .font(OneSetTypography.label)
    .foregroundStyle(OneSetColors.accent)
    .frame(minHeight: 44)
    .padding(.horizontal, 8)
    .accessibilityIdentifier("paywall.manage")
  }

  private var primaryAction: (title: String, run: () -> Void)? {
    switch model.phase {
    case .unavailable, .verifyFailed: ("Try Again", { Task { await model.tryAgain() } })
    case .pending: ("Check status", { Task { await model.tryAgain() } })
    case .active: ("Done", model.done)
    default: nil
    }
  }
}

extension View {
  /// Presents the checkout sheet for `model`. The model's `onResult` receives the single
  /// outcome (verified Pro, closed, or unresolved) however the sheet is dismissed.
  func paywallSheet(model: Binding<PaywallModel?>) -> some View {
    sheet(item: model) { PaywallSheetView(model: $0) }
  }
}
