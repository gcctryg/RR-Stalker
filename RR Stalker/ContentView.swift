//
//  ContentView.swift
//  RR Stalker
//
//  Created by Xuelu Feng on 5/18/26.
//

import SwiftUI
import Combine
import Foundation

struct ContentView: View {
    @StateObject private var bridge = PCBridgeClient()

    var body: some View {
        TabView {
            ProfileView(bridge: bridge)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }

            CollectionsView(bridge: bridge)
                .tabItem {
                    Label("Collections", systemImage: "square.grid.2x2")
                }

            FriendListView(bridge: bridge)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }

            EsportView()
                .tabItem {
                    Label("eSport", systemImage: "trophy")
                }
        }
        .task {
            await bridge.loadPlayer()
        }
    }
}

struct EsportView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("eSport", systemImage: "trophy", description: Text("This tab is empty for now."))
        }
    }
}
