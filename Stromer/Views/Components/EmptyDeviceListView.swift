import SwiftUI

struct EmptyDeviceListView: View {
    let addAction: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Noch keine Victron-Geräte", systemImage: "dot.radiowaves.left.and.right")
        } description: {
            Text("Füge deinen SmartShunt oder MPPT mit dem Advertisement Key aus VictronConnect hinzu.")
        } actions: {
            Button(action: addAction) {
                Label("Gerät hinzufügen", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
