import SwiftUI
import StromerScanner

@main
struct StromerApp: App {
    @State private var appModel = StromerAppViewModel.live()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(appModel.store)
                .task {
                    await appModel.start()
                }
        }
    }
}
