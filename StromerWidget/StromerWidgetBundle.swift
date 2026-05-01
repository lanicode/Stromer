import AppIntents
import StromerScanner
import SwiftUI
import WidgetKit

@main
struct StromerWidgetBundle: WidgetBundle {
    var body: some Widget {
        StromerWidget()
        StromerWidgetLiveActivity()
    }
}

struct StromerWidgetAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [StromerScannerAppIntentsPackage.self]
    }
}
