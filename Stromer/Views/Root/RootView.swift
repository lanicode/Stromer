import SwiftUI

struct RootView: View {
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
        .sheet(isPresented: $isShowingAddDevice) {
            NavigationStack {
                AddDeviceView()
            }
        }
    }
}
