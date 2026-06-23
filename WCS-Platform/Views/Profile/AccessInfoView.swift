//
//  AccessInfoView.swift
//  WCS-Platform
//

import SwiftUI

struct AccessInfoView: View {
    var body: some View {
        List {
            Section {
                Text("Your learning access is assigned by your organization.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Access")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        AccessInfoView()
    }
}
