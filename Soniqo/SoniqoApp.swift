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
            Label("Soniqo", systemImage: controller.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
