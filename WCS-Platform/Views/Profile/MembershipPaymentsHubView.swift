//
//  MembershipPaymentsHubView.swift
//  WCS-Platform
//

import SwiftUI

struct MembershipPaymentsHubView: View {
    var body: some View {
        List {
            Section {
                Text("Membership information is managed through your organization.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Membership")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        MembershipPaymentsHubView()
    }
}
