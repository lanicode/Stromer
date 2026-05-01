import SwiftUI
import StromerScanner

@main
struct StromerApp: App {
    @State private var store = VictronStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
