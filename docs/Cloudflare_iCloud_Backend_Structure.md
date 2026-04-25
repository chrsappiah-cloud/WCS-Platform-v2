# WCS Backend Storage Structure (Cloudflare + iCloud)

## Objective
Design a backend storage system that supports:
- fast global delivery for course/media workloads (Cloudflare),
- Apple ecosystem synchronization for user/admin records (iCloud/CloudKit),
- strict safety controls for AI-generated module videos before publication.

## Recommended System Design
- **Primary transactional database**: PostgreSQL (or equivalent relational engine) for source-of-truth records.
- **Object/media storage**: Cloudflare R2 for module videos, narration assets, thumbnails, and supporting binaries.
- **Edge/security layer**: Cloudflare Workers + API gateway for signed upload URLs, token validation, and policy checks.
- **Apple sync layer**: CloudKit (private/public zones) for iOS-facing synchronization metadata (not raw large video binaries).

## Data Domains
- **Admin domain**
  - Course drafts and AI generation traces
  - Publishing decisions and audit events
  - Video generation jobs and upload safety reports
- **User domain**
  - Profiles, enrollment state, and lesson progress
  - Quiz/assignment submissions and certificate state
  - Discussion participation and notifications

## Database Table Structure (Relational Core)
1. `users`
   - `user_id` (PK), `email`, `display_name`, `role`, `access_tier`, `created_at`, `updated_at`
   - Indexes: unique email, role
2. `courses`
   - `course_id` (PK), `title`, `description`, `status`, `access_tier`, `published_at`, `updated_at`
   - Indexes: status, access tier, updated_at
3. `course_modules_lessons`
   - `lesson_id` (PK), `course_id` (FK), `module_id`, `order_no`, `kind`, `title`, `video_asset_id`, `updated_at`
   - Indexes: `(course_id, module_id, order_no)`, lesson kind
4. `video_assets`
   - `video_asset_id` (PK), `course_id` (FK), `lesson_id` (FK), `r2_object_key`, `playback_url`, `checksum_sha256`, `mime_type`, `upload_safety_status`, `generated_at`
   - Indexes: lesson id, safety status, generated_at
5. `enrollments_progress`
   - `enrollment_id` (PK), `user_id` (FK), `course_id` (FK), `progress_percent`, `last_lesson_id`, `updated_at`
   - Indexes: `(user_id, course_id)`, progress
6. `assignments_quizzes_submissions`
   - `submission_id` (PK), `user_id` (FK), `course_id` (FK), `assessment_type`, `score`, `payload_json`, `submitted_at`
   - Indexes: user, course, submitted_at
7. `admin_drafts_audit`
   - `event_id` (PK), `draft_id`, `admin_user_id`, `event_type`, `snapshot_json`, `created_at`
   - Indexes: draft id, admin id, event_type, created_at

## Cloudflare Responsibilities
- Store large video/audio/course binary artifacts in R2.
- Generate short-lived signed upload and download URLs.
- Enforce upload policy:
  - HTTPS only
  - expected MIME whitelist (e.g. `video/mp4`)
  - checksum validation (`sha256`)
  - malware/moderation checks before activation
- Cache published playback manifests at edge for low-latency streaming.

## iCloud (CloudKit) Responsibilities
- Sync learner/admin lightweight records needed across Apple devices:
  - progress checkpoints
  - draft metadata pointers
  - last-opened course/module state
- Keep references to canonical backend records (`course_id`, `lesson_id`, `video_asset_id`), not full media blobs.
- Use record versioning and conflict resolution (`serverRecordChanged`) to prevent data loss.

## Backend API Contract (already mirrored in app code)
- `GET /system/storage-backends`
  - Returns health/latency/capabilities for Cloudflare + iCloud and active read/write provider.
- `GET /system/database-blueprint`
  - Returns canonical schema blueprint so clients/admin tools can validate compatibility.

## Safety and Compliance Controls
- Role-based authorization (admin vs learner).
- Encryption in transit (TLS 1.2+) and at rest.
- Signed URL expiry + one-time upload tokens.
- Immutable admin publish audit events.
- Data retention policies:
  - learner progress: 36 months archive
  - admin audit: permanent
  - media metadata: permanent, with superseded versions retained

## Failover Strategy
- Normal mode: write/read primary through Cloudflare-backed backend API.
- Degraded mode:
  - if Cloudflare object operations fail, queue job and mark asset `pending_upload`.
  - keep iCloud sync operational for user progress metadata.
- Recovery:
  - replay queued media uploads,
  - verify checksum and publish only after safety gate passes.

## Implementation Note for This Repository
The iOS app now includes typed contracts for:
- `StorageBackendsStatus`
- `DatabaseBlueprint`

and client methods:
- `NetworkClient.fetchStorageBackendsStatus()`
- `NetworkClient.fetchDatabaseBlueprint()`

These return mock values now and can be switched to your live backend by setting `useMocks = false` and implementing the two endpoints.
