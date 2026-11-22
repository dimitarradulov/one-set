import StoreKit
import SwiftUI

/// Settings > Account > Subscription: access status, Restore Purchases, and Manage Subscription.
struct SubscriptionSettingsScreen: View {
  @Bindable var model: SubscriptionSettingsModel
  /// Reloads access when the signed-in account changes.
  let accountID: String?
  @Environment(\.openURL) private var openURL

  var body: some View {
    Form {
      Section {
        SubscriptionStatusRow(content: statusContent)
      } header: {
        Text("Access")
      }
      .listRowBackground(OneSetColors.surface)

      Section {
        Button { Task { await model.restorePurchases() } } label: {
          Label("Restore Purchases", systemImage: "arrow.clockwise")
        }
        .disabled(model.isBusy)
        .accessibilityIdentifier("subscription.restore")
        Button { Task { await openManagement() } } label: {
          Label("Manage Subscription", systemImage: "arrow.up.forward.square")
        }
        .accessibilityIdentifier("subscription.manage")
      } header: {
        Text("Apple subscription")
      } footer: {
        Text("Manage your plan or cancel in Apple’s subscription settings.")
      }
      .listRowBackground(OneSetColors.surface)

      if let action = model.primaryAction {
        Section {
          Button { run(action) } label: {
            Text(action.title)
              .font(OneSetTypography.button)
              .foregroundStyle(Color.black)
              .frame(maxWidth: .infinity, minHeight: 52)
              .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
              .contentShape(RoundedRectangle(cornerRadius: 12))
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("subscription.primaryAction")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
      }
    }
    .scrollContentBackground(.hidden)
    .background(OneSetColors.background)
    .navigationTitle("Subscription")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .tabBar)
    .paywallSheet(model: $model.paywall)
    .accessibilityIdentifier("subscription.screen")
    .task(id: accountID) {
      await model.load()
      #if DEBUG
      if AppLaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
        .subscriptionSettingsRoute?.restoresOnLaunch == true {
        await model.restorePurchases()
      }
      #endif
      await model.observeUpdates()
    }
  }

  private func run(_ action: SubscriptionSettingsModel.PrimaryAction) {
    Task {
      switch action {
      case .seePlans: await model.seePlans()
      case .tryAgain, .checkStatus: await model.refresh()
      }
    }
  }

  /// Opens Apple's subscriptions screen, or the App Store page when that cannot be shown.
  private func openManagement() async {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    if let scene {
      do {
        try await AppStore.showManageSubscriptions(in: scene)
        return
      } catch {}
    }
    if let url = PaywallModel.manageSubscriptionURL { openURL(url) }
  }

  private var statusContent: SubscriptionStatusRow.Content {
    switch model.restore {
    case .restoring:
      return .init(icon: .spinner, title: "Restoring purchases", message: "Checking for an active Apple subscription.")
    case .restored:
      return .init(icon: .symbol("checkmark.circle"), title: "Purchases restored", message: "OneSet Pro is active on this account.")
    case .noPurchase:
      return .init(
        icon: .symbol("exclamationmark.triangle"), title: "No active purchases found",
        message: "Check that you’re signed in to the Apple Account that made the purchase.")
    case .linkedToAnotherAccount:
      return .init(
        icon: .symbol("exclamationmark.triangle"), title: "Restore unavailable",
        message: "This subscription is linked to another OneSet account. Sign in to that account to use Pro.")
    case .failed:
      return .init(
        icon: .symbol("exclamationmark.triangle"), title: "Restore did not complete",
        message: "Nothing was charged. Please try again.")
    case .idle:
      return accessContent
    }
  }

  private var accessContent: SubscriptionStatusRow.Content {
    switch model.status {
    case .active:
      return .init(icon: .symbol("checkmark.circle"), title: "OneSet Pro is active", message: "New workouts are available.")
    case .inactive:
      return .init(icon: .symbol("lock"), title: "No active subscription", message: "OneSet Pro is required to start a new workout.")
    case .checking:
      return .init(icon: .spinner, title: "Checking subscription access", message: nil)
    case .unconfirmed:
      return .init(
        icon: .symbol("exclamationmark.triangle"), title: "Couldn’t verify subscription",
        message: "Connect to the internet and try again.")
    case .pending:
      return .init(
        icon: .symbol("clock"), title: "Waiting for purchase approval",
        message: "Check again after Apple approves the purchase.")
    }
  }
}

private struct SubscriptionStatusRow: View {
  struct Content {
    let icon: PaywallNotice.Icon
    let title: String
    let message: String?
  }

  let content: Content

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Group {
        switch content.icon {
        case .spinner: ProgressView().tint(OneSetColors.accent)
        case .symbol(let name): Image(systemName: name).foregroundStyle(OneSetColors.accent)
        }
      }
      .font(OneSetTypography.metric)
      .frame(width: 28, height: 28)
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(content.title)
          .font(OneSetTypography.bodyStrong)
          .foregroundStyle(OneSetColors.textPrimary)
        if let message = content.message {
          Text(message)
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textSecondary)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("subscription.status")
  }
}
