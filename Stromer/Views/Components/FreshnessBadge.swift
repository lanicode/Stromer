import StromerScanner
import SwiftUI

struct FreshnessBadge: View {
    let freshness: DeviceFreshness

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background {
                Capsule()
                    .fill(color.opacity(0.14))
            }
            .accessibilityLabel("Status: \(title)")
    }

    private var title: String {
        switch freshness {
        case .fresh:
            return "Aktuell"
        case .delayed:
            return "Verzögert"
        case .stale:
            return "Alt"
        case .missing:
            return "Fehlt"
        }
    }

    private var color: Color {
        switch freshness {
        case .fresh:
            return .green
        case .delayed:
            return .orange
        case .stale:
            return .secondary
        case .missing:
            return .red
        }
    }
}
