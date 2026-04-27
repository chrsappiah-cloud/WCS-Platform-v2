//
//  AppRootView.swift
//  WCS-Platform
//

import SwiftUI

struct AppRootView: View {
    @StateObject private var appViewModel = AppViewModel()

    var body: some View {
        TabView(selection: $appViewModel.selectedTab) {
            Tab("Discover", systemImage: "sparkles", value: .discover) {
                NavigationStack {
                    HomeTabView()
                }
            }

            Tab("Programs", systemImage: "square.grid.2x2.fill", value: .programs) {
                NavigationStack {
                    CourseListView()
                }
            }

            Tab("Discussion", systemImage: "bubble.left.and.bubble.right.fill", value: .discussion) {
                NavigationStack {
                    DiscussionView()
                }
            }

            Tab("Profile", systemImage: "person.crop.circle.fill", value: .profile) {
                NavigationStack {
                    ProfileView()
                }
            }

            Tab("About", systemImage: "info.circle", value: .about) {
                NavigationStack {
                    WCSAboutPlatformView()
                }
            }
        }
        .tint(DesignTokens.brandAccent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .environmentObject(appViewModel)
        .task {
            await appViewModel.bootstrapUser()
        }
    }
}

#Preview {
    AppRootView()
}
