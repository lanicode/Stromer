import StromerScanner
import SwiftUI

struct DeviceListView: View {
    @Environment(StromerAppViewModel.self) private var appModel
    @Environment(VictronStore.self) private var store
    @State private var isShowingAddDevice = false
    @State private var isShowingSettings = false
    @State private var refreshFeedback = false

    var body: some View {
        Group {
            if appModel.registeredDevices.isEmpty {
                EmptyDeviceListView {
                    isShowingAddDevice = true
                }
            } else {
                List {
                    Section {
                        ForEach(appModel.registeredDevices) { device in
                            NavigationLink(value: device.id) {
                                DeviceRowView(
                                    device: device,
                                    reading: store.reading(for: device.id)
                                )
                            }
                        }
                    } footer: {
                        Text("Hintergrund-Updates sind opportunistisch. Stromer zeigt deshalb immer den letzten bekannten Wert mit Aktualitätsstatus.")
                    }
                }
                .refreshable {
                    await appModel.restartScanner()
                    refreshFeedback.toggle()
                }
            }
        }
        .navigationTitle("Stromer")
        .navigationDestination(for: UUID.self) { deviceID in
            DeviceDetailView(deviceID: deviceID)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingSettings = true
                } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddDevice = true
                } label: {
                    Label("Gerät hinzufügen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingAddDevice) {
            NavigationStack {
                AddDeviceView()
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: refreshFeedback)
    }
}
