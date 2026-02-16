//
//  MainTabView.swift
//  MeetingMind
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Record", systemImage: "mic.fill", value: 0) {
                RecordingView()
            }

            Tab("History", systemImage: "clock.fill", value: 1) {
                SessionListView()
            }

            Tab("Settings", systemImage: "gear", value: 2) {
                SettingsView()
            }
        }
    }
}
