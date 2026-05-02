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
        ContentUnavailableView {
            Label(title, systemImage: iconSystemName)
        } description: {
            Text(description)
        } actions: {
            if let action {
                Button(action.label, action: action.perform)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

extension StromerEmptyStateView {
    struct EmptyStateAction {
        let label: String
        let perform: () -> Void
    }
}
