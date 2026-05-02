import SwiftUI

struct EmptyDeviceListView: View {
    let addAction: () -> Void

    var body: some View {
        StromerEmptyStateView(
            iconSystemName: "dot.radiowaves.left.and.right",
            title: "Noch keine Victron-Geräte",
            description: "Füge dein erstes Victron-Gerät hinzu. Stromer kann SmartShunt/BMV und MPPT live anzeigen.",
            action: .init(label: "Gerät hinzufügen", perform: addAction)
        )
    }
}
