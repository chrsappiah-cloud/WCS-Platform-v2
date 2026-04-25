//
//  StorageArchitecture.swift
//  WCS-Platform
//

import Foundation

enum StorageProvider: String, Codable, Hashable, CaseIterable {
    case cloudflare
    case iCloud
}

struct StorageProviderStatus: Codable, Hashable, Identifiable {
    let id: UUID
    let provider: StorageProvider
    let isHealthy: Bool
    let latencyMs: Int
    let replicationScope: String
    let capabilities: [String]
    let lastCheckedAt: Date
}

struct StorageBackendsStatus: Codable, Hashable {
    let providers: [StorageProviderStatus]
    let activeWriteProvider: StorageProvider
    let activeReadProvider: StorageProvider
    let failoverEnabled: Bool
    let uploadSafetyPolicy: String
}

struct DatabaseBlueprint: Codable, Hashable {
    struct TableDesign: Codable, Hashable, Identifiable {
        let id: UUID
        let tableName: String
        let partitionKey: String
        let indexes: [String]
        let retentionPolicy: String
        let purpose: String
    }

    let version: String
    let databaseEngine: String
    let tables: [TableDesign]
    let mediaStorageDesign: String
    let securityControls: [String]
}

enum StorageArchitectureMockFactory {
    static func makeStatus() -> StorageBackendsStatus {
        let now = Date()
        return StorageBackendsStatus(
            providers: [
                StorageProviderStatus(
                    id: UUID(),
                    provider: .cloudflare,
                    isHealthy: true,
                    latencyMs: 42,
                    replicationScope: "Global edge + R2 object durability",
                    capabilities: [
                        "Course media object storage",
                        "Signed upload URLs",
                        "Global cached reads"
                    ],
                    lastCheckedAt: now
                ),
                StorageProviderStatus(
                    id: UUID(),
                    provider: .iCloud,
                    isHealthy: true,
                    latencyMs: 67,
                    replicationScope: "Apple CloudKit private/public DB zones",
                    capabilities: [
                        "User profile sync metadata",
                        "Admin draft sync manifests",
                        "Conflict-safe record versioning"
                    ],
                    lastCheckedAt: now
                )
            ],
            activeWriteProvider: .cloudflare,
            activeReadProvider: .cloudflare,
            failoverEnabled: true,
            uploadSafetyPolicy: "HTTPS-only uploads, MIME validation, checksum verification, and moderation gate before module publication."
        )
    }

    static func makeBlueprint() -> DatabaseBlueprint {
        DatabaseBlueprint(
            version: "2026.04.wcs.storage.v1",
            databaseEngine: "PostgreSQL (transactional) + Cloudflare R2 (media) + CloudKit sync layer",
            tables: [
                .init(
                    id: UUID(),
                    tableName: "users",
                    partitionKey: "user_id",
                    indexes: ["email_unique_idx", "role_idx"],
                    retentionPolicy: "active + 24-month archive",
                    purpose: "Learner/admin identity, profile and access tier"
                ),
                .init(
                    id: UUID(),
                    tableName: "courses",
                    partitionKey: "course_id",
                    indexes: ["status_idx", "access_tier_idx", "updated_at_idx"],
                    retentionPolicy: "permanent with audit snapshots",
                    purpose: "Published course catalog and metadata"
                ),
                .init(
                    id: UUID(),
                    tableName: "course_modules_lessons",
                    partitionKey: "course_id",
                    indexes: ["module_order_idx", "lesson_type_idx", "lesson_id_unique_idx"],
                    retentionPolicy: "permanent with version history",
                    purpose: "Syllabus structure, lecture units, and lesson sequencing"
                ),
                .init(
                    id: UUID(),
                    tableName: "video_assets",
                    partitionKey: "course_id",
                    indexes: ["lesson_id_idx", "upload_safety_idx", "generated_at_idx"],
                    retentionPolicy: "permanent with regeneration supersession",
                    purpose: "Video generation outputs, safe upload metadata, playback pointers"
                ),
                .init(
                    id: UUID(),
                    tableName: "enrollments_progress",
                    partitionKey: "user_id",
                    indexes: ["course_id_idx", "progress_idx", "updated_at_idx"],
                    retentionPolicy: "active + 36-month learning archive",
                    purpose: "User enrollments, lesson completion, and progress tracking"
                ),
                .init(
                    id: UUID(),
                    tableName: "assignments_quizzes_submissions",
                    partitionKey: "user_id",
                    indexes: ["course_id_idx", "assessment_type_idx", "submitted_at_idx"],
                    retentionPolicy: "active + compliance archive",
                    purpose: "Assessment records and grading trail"
                ),
                .init(
                    id: UUID(),
                    tableName: "admin_drafts_audit",
                    partitionKey: "draft_id",
                    indexes: ["created_by_idx", "status_idx", "updated_at_idx"],
                    retentionPolicy: "permanent audit log",
                    purpose: "Admin generation drafts, revisions, and publication lineage"
                )
            ],
            mediaStorageDesign: "Video binaries stored in Cloudflare R2 with signed URLs; metadata mirrored to CloudKit-safe sync records for cross-device continuity.",
            securityControls: [
                "Row-level authorization for admin/learner role boundaries",
                "At-rest encryption and TLS in transit",
                "Signed URL expiry for upload/download",
                "Checksum + MIME gate before asset activation",
                "Immutable audit trail for admin publication actions"
            ]
        )
    }
}
