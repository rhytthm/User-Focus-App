//
//  UserFocusApp.swift
//  UserFocus
//
//  Created by RAJEEV MAHAJAN on 06/03/25.
//

import SwiftUI

@main
struct UserFocusApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
