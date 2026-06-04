//
//  ContentView.swift
//  Soniqo
//
//  Created by suica on 04/06/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Soniqo runs from the menu bar.", systemImage: "speaker.wave.2.fill")
                .font(.headline)
            Text("Use the menu bar icon to configure automatic system output switching.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 360)
    }
}
