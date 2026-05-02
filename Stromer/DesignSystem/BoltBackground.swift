import SwiftUI

public struct BoltBackground: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [Color.boltCream, Color.boltCreamDeep],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

public extension View {
    func boltBackground() -> some View {
        background(BoltBackground())
    }
}
