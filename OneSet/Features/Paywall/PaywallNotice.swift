import SwiftUI

/// A status card for the parent screen: spinner or symbol, title, and message.
struct PaywallNotice: View {
  enum Icon {
    case spinner
    case symbol(String)
  }

  let icon: Icon
  let title: String
  let message: String?
  var identifier = "paywall.notice"

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Group {
        switch icon {
        case .spinner:
          ProgressView().tint(OneSetColors.accent)
        case .symbol(let name):
          Image(systemName: name).foregroundStyle(OneSetColors.accent)
        }
      }
      .font(OneSetTypography.metric)
      .frame(width: 28, height: 28)
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(OneSetTypography.bodyStrong)
          .foregroundStyle(OneSetColors.textPrimary)
        if let message {
          Text(message)
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textSecondary)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(OneSetColors.border, lineWidth: 1) }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(identifier)
  }
}
