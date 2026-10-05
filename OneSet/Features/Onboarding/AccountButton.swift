import SwiftUI

struct AccountButton: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let title: String
  let systemImage: String
  let identifier: String
  let prominent: Bool
  let showsDemo: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 4) {
            titleLabel
            if showsDemo {
              demoLabel.padding(.leading, 36)
            }
          }
        } else {
          HStack(spacing: 12) {
            Image(systemName: systemImage)
              .font(.system(size: 19, weight: .semibold))
              .frame(width: 24)
            Text(title)
              .font(OneSetTypography.button)
              .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if showsDemo {
              demoLabel
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity, minHeight: 52)
      .foregroundStyle(prominent ? Color.black : OneSetColors.textPrimary)
      .background {
        RoundedRectangle(cornerRadius: 12)
          .fill(prominent ? OneSetColors.accent : Color.black.opacity(0.42))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(prominent ? Color.clear : Color.white.opacity(0.48), lineWidth: 1)
      }
      .onboardingGlass(in: RoundedRectangle(cornerRadius: 12), tint: prominent ? .white : nil)
      .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(showsDemo ? "\(title), demo only" : title)
    .accessibilityHint(showsDemo
      ? "Opens training preferences. No account or credentials are used."
      : "Opens the email verification flow.")
    .accessibilityIdentifier(identifier)
  }

  private var titleLabel: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 19, weight: .semibold))
        .frame(width: 24)
      Text(title)
        .font(OneSetTypography.button)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var demoLabel: some View {
    Text("Demo")
      .font(OneSetTypography.caption)
      .foregroundStyle(prominent ? Color.black.opacity(0.7) : OneSetColors.textSecondary)
  }
}
