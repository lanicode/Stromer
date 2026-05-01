import SwiftUI
import StromerScanner

struct ContentView: View {
    @Environment(VictronStore.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text("Stromer")
                .font(.largeTitle.bold())
            Text("Phase 3.2b – Bootstrap OK")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
