//
//  MainTabView.swift
//  MeetingMind
//

import SwiftUI

struct MainTabView: View {
    @State private var router = NavigationRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Record", systemImage: "mic.fill", value: 0) {
                RecordingView(router: router)
            }

            Tab("History", systemImage: "clock.fill", value: 1) {
                SessionListView(router: router)
            }

            Tab("Settings", systemImage: "gear", value: 2) {
                SettingsView()
            }
        }
    }
}
