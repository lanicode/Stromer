import SwiftUI
import StromerScanner

@main
struct StromerApp: App {
    @State private var appModel = StromerAppViewModel.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(appModel.store)
                .task {
                    await appModel.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else {
                        return
                    }

                    Task {
                        await appModel.resumeForeground()
                    }
                }
        }
    }
}
