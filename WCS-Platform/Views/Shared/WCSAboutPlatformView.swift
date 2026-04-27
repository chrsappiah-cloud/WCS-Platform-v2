//
//  WCSAboutPlatformView.swift
//  WCS-Platform
//

import SwiftUI

/// Surfaces build metadata, API configuration, and how `Core/Architecture` ties into the app shell.
struct WCSAboutPlatformView: View {
    private var marketingVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }

    private var buildNumber: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "—"
    }

    var body: some View {
        List {
            Section("This build") {
                LabeledContent("Version", value: marketingVersion)
                LabeledContent("Build", value: buildNumber)
                LabeledContent("API base", value: AppEnvironment.platformAPIBaseURL.absoluteString)
            }

            Section("Architecture") {
                Text(
                    "Domain protocols and `WCSLiveRepositories` live in `Core/Architecture/WCSDomainRepositories.swift`, backed by `NetworkClient`. `WCSAppContainer.shared` exposes typed repository slots to view models (for example `AppViewModel` uses `identity`)."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Section("Tabs") {
                featureRow(title: "Discover", detail: "Home feed, discovery, and entry into programs.")
                featureRow(title: "Programs", detail: "Course catalog and navigation into lessons and media.")
                featureRow(title: "Discussion", detail: "Community discussion feed backed by the community repository.")
                featureRow(title: "Profile", detail: "Account, membership, and subscription context.")
            }
        }
        .navigationTitle("About WCS")
    }

    private func featureRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        WCSAboutPlatformView()
    }
}
