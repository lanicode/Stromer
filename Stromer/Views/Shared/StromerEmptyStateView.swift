import SwiftUI

struct StromerEmptyStateView: View {
    let iconSystemName: String
    let title: String
    let description: String
    let action: EmptyStateAction?

    init(
        iconSystemName: String,
        title: String,
        description: String,
        action: EmptyStateAction? = nil
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.description = description
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: iconSystemName)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color.boltTeal)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)

            BoltEyebrow("Hinweis", color: .boltTealDeep)

            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Color.boltInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(description)
                .font(.system(size: 15))
                .foregroundStyle(Color.boltInkSoft)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let action {
                BoltPrimary(action.label, showsBolt: true, action: action.perform)
                    .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
    }
}

extension StromerEmptyStateView {
    struct EmptyStateAction {
        let label: String
        let perform: () -> Void
    }
}
