//
//  ContentView.swift
//  WaypointWheels
//
//  Created by Daniel Francis on 10/9/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var sessionViewModel = SessionViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)

            if let name = sessionViewModel.userName {
                Text("Status: OK — Hello, \(name)")
            }

            LoginView(viewModel: sessionViewModel)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
