import SwiftUI

public struct BoltSection<Content: View>: View {
    let header: String?
    let footer: String?
    let content: Content

    public init(
        header: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                BoltEyebrow(header)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color.boltPaper)
            .overlay(
                Rectangle()
                    .stroke(Color.boltHair, lineWidth: 1)
            )

            if let footer {
                Text(footer)
                    .font(.system(size: 11).italic())
                    .foregroundStyle(Color.boltInkSoft)
                    .padding(.top, 8)
                    .padding(.horizontal, 22)
            }
        }
    }
}
