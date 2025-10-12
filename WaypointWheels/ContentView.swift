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
        Group {
            if sessionViewModel.isAuthenticated, let name = sessionViewModel.userName {
                DashboardView(userName: name)
                    .transition(.opacity.combined(with: .scale))
            } else {
                NavigationStack {
                    ZStack {
                        LinearGradient(colors: [Color(red: 0.97, green: 0.94, blue: 0.86),
                                                 Color(red: 0.92, green: 0.97, blue: 0.98)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                            .ignoresSafeArea()

                        VStack(spacing: 32) {
                            VStack(spacing: 8) {
                                Text("Waypoint Wheels")
                                    .font(.largeTitle)
                                    .fontWeight(.heavy)
                                    .tracking(1.5)

                                Text("Camp In Style")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }

                            LoginView(viewModel: sessionViewModel)
                                .padding(24)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .padding(.horizontal, 24)
                        }
                        .padding()
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionViewModel.isAuthenticated)
    }
}

#Preview {
    ContentView()
}
