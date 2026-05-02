import SwiftUI
import UIKit

struct RootView: View {
    @Environment(StromerAppViewModel.self) private var appViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var onboardingState = OnboardingState()
    @State private var isShowingAddDevice = false
    @State private var selectedTab: AppTab = .dashboard

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.boltPaper)
        appearance.shadowColor = UIColor(Color.boltHair)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(Color.boltInkSoft)
        itemAppearance.selected.iconColor = UIColor(Color.boltInk)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.boltInkSoft),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.boltInk),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        Group {
            if onboardingState.hasCompletedOnboarding {
                appTabs
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
                    await appViewModel.refreshDashboardData()
                    await appViewModel.refreshHistoryData()
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

    private var appTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView {
                    selectedTab = .devices
                }
            }
            .tabItem {
                Label("Dashboard", systemImage: "bolt.fill")
            }
            .tag(AppTab.dashboard)

            NavigationStack {
                HistoryView {
                    selectedTab = .devices
                }
            }
            .tabItem {
                Label("Verlauf", systemImage: "chart.xyaxis.line")
            }
            .tag(AppTab.history)

            NavigationStack {
                DeviceListView()
            }
            .tabItem {
                Label("Geräte", systemImage: "list.bullet")
            }
            .tag(AppTab.devices)
        }
        .tint(.boltInk)
    }
}

private enum AppTab {
    case dashboard
    case history
    case devices
}
