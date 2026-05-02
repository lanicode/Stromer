import SwiftUI

struct RootView: View {
    @Environment(StromerAppViewModel.self) private var appViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var onboardingState = OnboardingState()
    @State private var isShowingAddDevice = false

    var body: some View {
        Group {
            if onboardingState.hasCompletedOnboarding {
                NavigationStack {
                    DeviceListView()
                }
            } else {
                OnboardingFlowView { action in
                    onboardingState.complete()
                    if action == .addDevice {
                        isShowingAddDevice = true
                    }
                }
                .transition(.opacity)
            }
        }
        .environment(onboardingState)
        .animation(.easeInOut(duration: 0.25), value: onboardingState.hasCompletedOnboarding)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await appViewModel.runOpportunisticAggregation()
                    await appViewModel.checkDeviceLossNotifications()
                }
            case .background:
                appViewModel.widgetRefreshCoordinator.requestReload(reason: .background)
                Task {
                    await appViewModel.runOpportunisticAggregation()
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .sheet(isPresented: $isShowingAddDevice) {
            NavigationStack {
                AddDeviceView()
            }
        }
    }
}
