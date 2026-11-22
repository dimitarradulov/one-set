#if DEBUG
import SwiftUI

extension PaywallOffering {
  static let complete = PaywallOffering(
    identifier: PaywallCatalog.offeringID, packageIDs: PaywallCatalog.requiredPackageIDs)
}

/// Fake host for previews, simulator routes, and tests. It never touches RevenueCat.
@MainActor
final class FakePaywallHost: PaywallHost {
  var offering: Result<PaywallOffering, PaywallOfferingError>
  private(set) var loadCount = 0

  init(offering: Result<PaywallOffering, PaywallOfferingError> = .success(.complete)) {
    self.offering = offering
  }

  func loadOffering() async throws(PaywallOfferingError) -> PaywallOffering {
    loadCount += 1
    return try offering.get()
  }

  func makePaywall(for offering: PaywallOffering, events: PaywallEvents) -> AnyView {
    AnyView(FakePaywallPlans(events: events))
  }
}

/// Stand-in for RevenueCatUI's plan picker, wired to the same events.
private struct FakePaywallPlans: View {
  let events: PaywallEvents
  @State private var selected = PaywallCatalog.annualPackageID

  private let plans = [
    (PaywallCatalog.monthlyPackageID, "Monthly", "$4.99", "per month"),
    (PaywallCatalog.annualPackageID, "Yearly", "$49.99", "per year")
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 12) {
          Text("OneSet Pro")
            .font(OneSetTypography.display)
            .foregroundStyle(OneSetColors.textPrimary)
          Text("Start workouts from guided HIT programs and log your working sets.")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textSecondary)
        }
        ForEach(plans, id: \.0) { plan in
          Button { selected = plan.0 } label: {
            HStack {
              Image(systemName: selected == plan.0 ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(selected == plan.0 ? OneSetColors.accent : OneSetColors.textTertiary)
              Text(plan.1).font(OneSetTypography.bodyStrong)
              Spacer()
              VStack(alignment: .trailing) {
                Text(plan.2).font(OneSetTypography.bodyStrong)
                Text(plan.3).font(OneSetTypography.caption).foregroundStyle(OneSetColors.textSecondary)
              }
            }
            .foregroundStyle(OneSetColors.textPrimary)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(selected == plan.0 ? OneSetColors.accentSubtle : OneSetColors.surface,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
              RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected == plan.0 ? OneSetColors.accent : OneSetColors.border)
            }
          }
          .buttonStyle(.plain)
        }
        Text("7 days free, then \(selected == PaywallCatalog.annualPackageID ? "$49.99 per year" : "$4.99 per month") until canceled. Manage or cancel in Apple subscriptions.")
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
        Button {
          Task {
            guard await events.purchaseInitiated(SubscriptionPackage(id: selected)) else { return }
            events.purchaseCompleted()
          }
        } label: {
          Text("Start 7-day trial")
            .font(OneSetTypography.button)
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall.fake.purchase")
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
    }
    .scrollIndicators(.hidden)
  }
}

/// Approves everything. Previews and simulator routes use it until the account owner exists.
@MainActor
struct PreviewPaywallApproval: PaywallApproving {
  func approvePurchase(_ package: SubscriptionPackage, for selection: AccountSelection) async
    -> PaywallApprovalDecision { .approved }
  func approveRestore(for selection: AccountSelection) async -> PaywallApprovalDecision { .approved }
  func release(for selection: AccountSelection) {}
}

enum PaywallPreviewState: String, CaseIterable {
  case ready, unavailable, verifying, verifyFailed, pending
}

/// Simulator route that opens the checkout sheet in a fixed state with fakes only.
struct PaywallPreviewRoute: View {
  let state: PaywallPreviewState
  @State private var model: PaywallModel?
  private let selection = AccountSelection(accountID: "preview", generation: 1)

  var body: some View {
    OneSetColors.background
      .ignoresSafeArea()
      .paywallSheet(model: $model)
      .task {
        let preset: SubscriptionAccessPreset = switch state {
        case .verifying: .checking
        case .verifyFailed: .failed
        case .pending: .pending
        default: .inactive
        }
        let host = FakePaywallHost(offering: state == .unavailable ? .failure(.missingOffering) : .success(.complete))
        let paywall = PaywallModel(
          selection: selection, currentSelection: { selection },
          access: PreviewSubscriptionAccessService(preset: preset),
          host: host, approval: PreviewPaywallApproval(), onResult: { _ in })
        model = paywall
        await paywall.start()
        switch state {
        case .verifying, .verifyFailed: paywall.events.purchaseCompleted()
        case .pending: paywall.events.purchasePending()
        default: break
        }
      }
  }
}
#endif
