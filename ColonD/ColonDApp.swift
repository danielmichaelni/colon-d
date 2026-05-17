//
//  ColonDApp.swift
//  ColonD
//
//  Created by Daniel Ni on 5/15/26.
//

import SwiftUI

@main
struct ColonDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
