//
//  ContentView.swift
//  WaypointWheels
//
//  Created by Daniel Francis on 10/9/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HealthViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)

            if viewModel.isLoading {
                Text("Status: (loading…)")
            } else if let errorMessage = viewModel.errorMessage {
                Text("Status: \(errorMessage)")
            } else {
                Text("Status: \(viewModel.status)")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
