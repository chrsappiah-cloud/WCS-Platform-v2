//
//  ProfileView.swift
//  WCS-Platform
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var pipelineStatus: PipelineHealthStatus?
    @State private var generationStatus: GenerationCapabilityStatus?
    @State private var isCheckingPipeline = false
    @State private var isCheckingGenerationAPIs = false
    @State private var cloudAIRepositoryGroups: [CloudAIRepositoryGroup] = []
    @State private var cloudAILocations: [String] = []
    @State private var cloudAIParentIndexResource = "projects/wcs-platform/locations/global/codeRepositoryIndexes/default-index"
    @State private var cloudAIGroupName = "projects/wcs-platform/locations/global/codeRepositoryIndexes/default-index/repositoryGroups/default-group"
    @State private var cloudAIRepositoryResource = "https://github.com/chrsappiah-cloud/WCSArtGalleryApp"
    @State private var cloudAIBranchPattern = "main|release/.*"
    @State private var cloudAIErrorMessage: String?
    @State private var isLoadingCloudAI = false
    @State private var isCreatingCloudAIGroup = false
    @State private var isAutomatingCloudAI = false
    @State private var cloudAIAutomationMessage: String?

    var body: some View {
        List {
            Section {
                if let user = appViewModel.user {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(DesignTokens.brandMuted)
                                .frame(width: 56, height: 56)
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.title2.weight(.bold))
                                .foregroundStyle(DesignTokens.brand)
                        }
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(user.name)
                                .font(.headline.weight(.semibold))
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xs)

                    LabeledContent("Premium", value: user.isPremium ? "Active" : "Not active")
                } else {
                    Text("Sign-in will connect to your identity provider and populate this profile.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Account")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Section {
                if let enrollments = appViewModel.user?.enrollments, !enrollments.isEmpty {
                    ForEach(enrollments) { enrollment in
                        NavigationLink {
                            CourseDetailView(courseId: enrollment.courseId)
                        } label: {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                Text(MockCourseCatalog.displayTitle(for: enrollment.courseId))
                                    .font(.subheadline.weight(.semibold))
                                ProgressView(value: enrollment.progressPercentage)
                                    .tint(DesignTokens.brandAccent)
                                Text(enrollment.progressPercentage, format: .percent.precision(.fractionLength(0)))
                                    .font(.caption2.weight(.medium).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, DesignTokens.Spacing.xs)
                        }
                    }
                } else {
                    Text("Enroll from a program page to see it here with live progress.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("My programs")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Section {
                SubscriptionBadgeView(subscriptions: appViewModel.user?.subscriptions ?? [])
                NavigationLink {
                    MembershipPaymentsHubView()
                } label: {
                    Label("Membership, subscriptions, and payouts", systemImage: "creditcard")
                }
            } header: {
                Text("Subscriptions")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Section {
                if BrandOutboundLinks.current.socialPairs.isEmpty {
                    Text(
                        "Configure SOCIAL_INSTAGRAM_URL, SOCIAL_TIKTOK_URL, SOCIAL_FACEBOOK_URL, SOCIAL_X_URL, SOCIAL_YOUTUBE_CHANNEL_URL, or SOCIAL_LINKEDIN_URL for learners, faculty, and staff."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(BrandOutboundLinks.current.socialPairs.enumerated()), id: \.offset) { _, pair in
                        Link(pair.label, destination: pair.url)
                    }
                }
            } header: {
                Text("Community & social")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Section {
                Toggle("Use mock API", isOn: Binding(
                    get: { NetworkClient.shared.useMocks },
                    set: { newValue in
                        NetworkClient.shared.useMocks = newValue
                        Task { @MainActor in
                            NotificationCenter.default.post(name: .wcsLearningStateDidChange, object: nil)
                            await appViewModel.bootstrapUser()
                        }
                    }
                ))
                if NetworkClient.shared.useMocks {
                    Toggle("Mock premium mode", isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "wcs.mockPremiumMode") },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: "wcs.mockPremiumMode")
                            Task { @MainActor in
                                NotificationCenter.default.post(name: .wcsLearningStateDidChange, object: nil)
                                await appViewModel.bootstrapUser()
                            }
                        }
                    ))
                    Picker("Mock role", selection: Binding(
                        get: { UserDefaults.standard.string(forKey: "wcs.mockRole") ?? UserRole.learner.rawValue },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: "wcs.mockRole")
                            UserDefaults.standard.set(newValue == UserRole.orgAdmin.rawValue || newValue == UserRole.admin.rawValue, forKey: "wcs.mockAdminMode")
                            Task { @MainActor in
                                NotificationCenter.default.post(name: .wcsLearningStateDidChange, object: nil)
                                await appViewModel.bootstrapUser()
                            }
                        }
                    )) {
                        Text("Learner").tag(UserRole.learner.rawValue)
                        Text("Instructor").tag(UserRole.instructor.rawValue)
                        Text("Org admin").tag(UserRole.orgAdmin.rawValue)
                    }
                }
                Toggle("Debug safe mode (simulator)", isOn: Binding(
                    get: { AppEnvironment.debugSafeMode },
                    set: { newValue in
                        AppEnvironment.setDebugSafeMode(newValue)
                        Task { @MainActor in
                            NotificationCenter.default.post(name: .wcsLearningStateDidChange, object: nil)
                        }
                    }
                ))
                NavigationLink {
                    AdminCourseCreatorView()
                } label: {
                    Label("WCS AI Course Generation", systemImage: "lock.shield")
                }
                Button {
                    Task { await checkPipeline() }
                } label: {
                    if isCheckingPipeline {
                        ProgressView()
                    } else {
                        Label("Check API Pipeline", systemImage: "dot.radiowaves.up.forward")
                    }
                }
                if let status = pipelineStatus {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API: \(status.apiReachable ? "online" : "offline") · Middleware: \(status.middlewareReachable ? "online" : "offline")")
                        Text("Realtime: \(status.realtimeReachable ? "online" : "offline") · Database: \(status.databaseReachable ? "online" : "offline")")
                        Text(status.message)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2)
                }
                Button {
                    Task { await checkGenerationAPIs() }
                } label: {
                    if isCheckingGenerationAPIs {
                        ProgressView()
                    } else {
                        Label("Check generation APIs", systemImage: "wand.and.stars")
                    }
                }
                if let generationStatus {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Generation API check: \(generationStatus.checkedAt.formatted(date: .omitted, time: .shortened))")
                            .foregroundStyle(.secondary)
                        ForEach(generationStatus.checks) { check in
                            Text("• \(check.system): \(check.state.rawValue) — \(check.detail)")
                        }
                    }
                    .font(.caption2)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cloud AI Companion repository groups")
                        .font(.caption.weight(.semibold))
                    TextField("Parent index resource", text: $cloudAIParentIndexResource)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.caption2)
                    TextField("Repository group full name", text: $cloudAIGroupName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.caption2)
                    TextField("Repository URL / resource", text: $cloudAIRepositoryResource)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.caption2)
                    TextField("Branch pattern (RE2)", text: $cloudAIBranchPattern)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.caption2)
                    HStack {
                        Button {
                            Task { await loadCloudAIRepositoryGroups() }
                        } label: {
                            if isLoadingCloudAI {
                                ProgressView()
                            } else {
                                Label("List groups", systemImage: "list.bullet")
                            }
                        }
                        .buttonStyle(.bordered)
                        Button {
                            Task { await createCloudAIRepositoryGroup() }
                        } label: {
                            if isCreatingCloudAIGroup {
                                ProgressView()
                            } else {
                                Label("Create group", systemImage: "plus.circle")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            Task { await automateCloudAISetup() }
                        } label: {
                            if isAutomatingCloudAI {
                                ProgressView()
                            } else {
                                Label("Automate setup", systemImage: "bolt.fill")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    if !cloudAILocations.isEmpty {
                        Text("Locations: \(cloudAILocations.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !cloudAIRepositoryGroups.isEmpty {
                        ForEach(Array(cloudAIRepositoryGroups.enumerated()), id: \.offset) { _, group in
                            Text("• \(group.name) · repos: \(group.repositories.count)")
                                .font(.caption2)
                        }
                    }
                    if let cloudAIErrorMessage {
                        Text(cloudAIErrorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    if let cloudAIAutomationMessage {
                        Text(cloudAIAutomationMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("API base") {
                    Text(AppEnvironment.platformAPIBaseURL.absoluteString)
                        .font(.caption2)
                        .simulatorStableTextSelection()
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Developer")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            } footer: {
                Text("Set WCSPlatformAPIBaseURL in Info.plist. Live mode uses the same NetworkClient entry points.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task {
            await appViewModel.bootstrapUser()
        }
    }

    private func checkPipeline() async {
        isCheckingPipeline = true
        defer { isCheckingPipeline = false }
        pipelineStatus = try? await NetworkClient.shared.fetchPipelineHealthStatus()
    }

    private func checkGenerationAPIs() async {
        isCheckingGenerationAPIs = true
        defer { isCheckingGenerationAPIs = false }
        generationStatus = await NetworkClient.shared.fetchGenerationCapabilityStatus()
    }

    private func loadCloudAIRepositoryGroups() async {
        isLoadingCloudAI = true
        defer { isLoadingCloudAI = false }
        cloudAIErrorMessage = nil
        cloudAIAutomationMessage = nil
        do {
            cloudAILocations = try await NetworkClient.shared.fetchCloudAICompanionLocations()
            cloudAIRepositoryGroups = try await NetworkClient.shared.listCloudAIRepositoryGroups(
                parentIndexResource: cloudAIParentIndexResource
            )
        } catch {
            cloudAIErrorMessage = error.localizedDescription
        }
    }

    private func createCloudAIRepositoryGroup() async {
        isCreatingCloudAIGroup = true
        defer { isCreatingCloudAIGroup = false }
        cloudAIErrorMessage = nil
        cloudAIAutomationMessage = nil
        let group = CloudAIRepositoryGroup(
            name: cloudAIGroupName,
            createTime: nil,
            updateTime: nil,
            labels: ["source": "ios-admin", "system": "wcs"],
            repositories: [
                .init(resource: cloudAIRepositoryResource, branchPattern: cloudAIBranchPattern)
            ]
        )
        do {
            _ = try await NetworkClient.shared.createCloudAIRepositoryGroup(
                parentIndexResource: cloudAIParentIndexResource,
                group: group
            )
            await loadCloudAIRepositoryGroups()
        } catch {
            cloudAIErrorMessage = error.localizedDescription
        }
    }

    private func automateCloudAISetup() async {
        isAutomatingCloudAI = true
        defer { isAutomatingCloudAI = false }
        cloudAIErrorMessage = nil
        cloudAIAutomationMessage = nil
        let targetGroup = CloudAIRepositoryGroup(
            name: cloudAIGroupName,
            createTime: nil,
            updateTime: nil,
            labels: ["source": "ios-admin", "system": "wcs", "automation": "true"],
            repositories: [.init(resource: cloudAIRepositoryResource, branchPattern: cloudAIBranchPattern)]
        )
        do {
            let result = try await NetworkClient.shared.ensureCloudAIRepositoryGroup(
                parentIndexResource: cloudAIParentIndexResource,
                targetGroup: targetGroup
            )
            cloudAILocations = result.locations
            cloudAIRepositoryGroups = result.groups
            cloudAIAutomationMessage = result.action == "created"
                ? "Automation complete: repository group created and synchronized."
                : "Automation complete: repository group already existed and status synchronized."
            generationStatus = await NetworkClient.shared.fetchGenerationCapabilityStatus()
        } catch {
            cloudAIErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppViewModel())
    }
}
