import SwiftUI

struct ConnectionStatusBadge: View {
    enum Variant {
        case compact
        case detailed
    }

    let status: ReceptionStatusObserver.ConnectionStatus
    var lastSeenText: String?
    var variant: Variant = .compact

    var body: some View {
        HStack(spacing: 6) {
            statusPill

            if variant == .detailed,
               let lastSeenText,
               status != .live {
                Text(lastSeenText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.boltInkSoft)
                    .lineLimit(1)
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(indicatorColor)
                .frame(width: 6, height: 6)

            Text(status.label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .overlay(Rectangle().stroke(borderColor, lineWidth: 1))
    }

    private var indicatorColor: Color {
        switch status {
        case .live:
            return .boltYellow
        case .recent:
            return .boltInk
        case .stale:
            return .boltWarn
        case .offline:
            return .boltBad
        case .waiting:
            return .boltInkSoft
        }
    }

    private var textColor: Color {
        switch status {
        case .live:
            return .boltCream
        case .recent:
            return .boltInk
        case .stale:
            return .boltWarn
        case .offline:
            return .boltBad
        case .waiting:
            return .boltInkSoft
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .live:
            return .boltTeal
        case .recent, .waiting:
            return .boltPaper
        case .stale:
            return .boltWarn.opacity(0.14)
        case .offline:
            return .boltBad.opacity(0.14)
        }
    }

    private var borderColor: Color {
        switch status {
        case .live:
            return .boltTeal
        case .recent:
            return .boltInk.opacity(0.3)
        case .stale:
            return .boltWarn.opacity(0.8)
        case .offline:
            return .boltBad.opacity(0.8)
        case .waiting:
            return .boltInkSoft.opacity(0.55)
        }
    }
}
