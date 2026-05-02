import SwiftUI

public struct BoltRowItem<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing
    let isLast: Bool
    let isDestructive: Bool
    let onTap: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        isLast: Bool = false,
        isDestructive: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.isLast = isLast
        self.isDestructive = isDestructive
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isDestructive ? Color.boltBad : Color.boltInk
                            )

                        if let subtitle {
                            Text(subtitle)
                                .font(.boltMono(11))
                                .tracking(0.2)
                                .foregroundStyle(Color.boltInkSoft)
                        }
                    }
                    Spacer()
                    trailing
                        .font(.system(size: 14))
                        .foregroundStyle(Color.boltInkSoft)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)

                if !isLast {
                    Rectangle()
                        .fill(Color.boltHair2)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

public extension BoltRowItem where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        isLast: Bool = false,
        isDestructive: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            isLast: isLast,
            isDestructive: isDestructive,
            onTap: onTap
        ) {
            EmptyView()
        }
    }
}
