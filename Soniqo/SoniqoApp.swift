//
//  SoniqoApp.swift
//  Soniqo
//
//  Created by suica on 04/06/2026.
//

import SwiftUI

@main
struct SoniqoApp: App {
    @StateObject private var controller = SoniqoController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller)
        } label: {
            Label("Soniqo", systemImage: "rectangle.2.swap")
        }
        .menuBarExtraStyle(.window)
    }
}
