//
//  NavigationRouter.swift
//  MeetingMind
//

import Foundation

@Observable
final class NavigationRouter {
    var selectedTab = 0
    /// Session to auto-navigate to in the History tab after recording stops.
    var pendingSession: Session?
}
