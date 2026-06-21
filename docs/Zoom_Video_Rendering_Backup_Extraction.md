# Zoom Video Rendering Backup Extraction

This extraction maps Zoom-hosted lesson recording into the existing WCS lesson-video fallback path.

## Existing WCS Seams

- Primary remote render: `WCS-Platform/Learning/VideoPipeline/InstructionalLessonVideoPipeline.swift`
- Remote BFF endpoint setting: `WCSLessonTextToVideoEndpoint`
- Manual playback override: `AdminCourseDraftStore.setManualLessonVideoPlaybackURL(...)`
- Machine-readable backup marker: `wcs.manualVideoURL: https://...`
- Optional provenance marker: `wcs.externalVideoSource: ...`
- Learner playback preference: `MockLearningStore.resolvedManualBackupVideoURL(...)`
- Admin UI: `AdminCourseCreatorView` section `Manual lesson video backups (per module)`

## Zoom Backup Role

Zoom should be a server-side backup renderer, not an in-app payment or browser checkout feature.

Recommended flow:

1. Admin requests backup video for a lesson.
2. Backend creates or identifies a Zoom meeting/session for recording.
3. Instructor or automation records the lesson in Zoom cloud.
4. Backend polls Zoom cloud recordings.
5. Backend copies the MP4 into app-owned storage, preferably Supabase Storage `lesson-videos` or Cloudflare R2.
6. Backend returns a signed `https://...` playback URL.
7. iOS calls `setManualLessonVideoPlaybackURL(...)` with provenance `zoom-cloud-recording`.

## Zoom API Surface

Use Zoom Server-to-Server OAuth from the backend only. Do not ship Zoom client secrets in iOS.

Token:

```http
POST https://zoom.us/oauth/token?grant_type=account_credentials&account_id={ZOOM_ACCOUNT_ID}
Authorization: Basic base64({ZOOM_CLIENT_ID}:{ZOOM_CLIENT_SECRET})
```

Create a recording session as a meeting:

```http
POST https://api.zoom.us/v2/users/{userId}/meetings
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "topic": "WCS lesson recording",
  "type": 2,
  "start_time": "2026-06-19T02:00:00Z",
  "duration": 30,
  "settings": {
    "auto_recording": "cloud",
    "join_before_host": false,
    "approval_type": 0
  }
}
```

Fetch meeting recordings:

```http
GET https://api.zoom.us/v2/meetings/{meetingId}/recordings
Authorization: Bearer {access_token}
```

Fetch user recordings by date window:

```http
GET https://api.zoom.us/v2/users/{userId}/recordings?from=2026-06-19&to=2026-06-19&page_size=30
Authorization: Bearer {access_token}
```

Expected recording file selection:

```ts
const mp4 = recording.recording_files.find((file) =>
  file.file_type === "MP4" &&
  file.status === "completed" &&
  typeof file.download_url === "string"
);
```

## WCS Backend Contract

Add a backend function such as:

```http
POST /functions/v1/wcs-zoom-video-backup
Authorization: Bearer {admin_or_function_secret}
Content-Type: application/json

{
  "draftId": "uuid",
  "moduleId": "uuid",
  "lessonId": "uuid",
  "courseTitle": "string",
  "moduleTitle": "string",
  "lessonTitle": "string",
  "meetingId": "optional existing Zoom meeting id",
  "zoomUserId": "me"
}
```

Response:

```json
{
  "status": "completed",
  "provider": "zoom-cloud-recording",
  "meetingId": "123456789",
  "recordingId": "recording-file-id",
  "playbackURL": "https://signed-storage-url.example/lesson.mp4",
  "expiresAt": "2026-06-26T00:00:00Z"
}
```

## Supabase Edge Adapter Skeleton

```ts
type ZoomBackupRequest = {
  draftId: string;
  moduleId: string;
  lessonId: string;
  courseTitle: string;
  moduleTitle: string;
  lessonTitle: string;
  meetingId?: string;
  zoomUserId?: string;
};

async function zoomAccessToken(): Promise<string> {
  const accountId = Deno.env.get("ZOOM_ACCOUNT_ID")!;
  const clientId = Deno.env.get("ZOOM_CLIENT_ID")!;
  const clientSecret = Deno.env.get("ZOOM_CLIENT_SECRET")!;
  const basic = btoa(`${clientId}:${clientSecret}`);

  const response = await fetch(
    `https://zoom.us/oauth/token?grant_type=account_credentials&account_id=${encodeURIComponent(accountId)}`,
    {
      method: "POST",
      headers: { Authorization: `Basic ${basic}` }
    }
  );
  if (!response.ok) throw new Error(`Zoom OAuth failed: ${response.status}`);
  const json = await response.json();
  return json.access_token;
}

async function fetchZoomRecordingMP4(meetingId: string, token: string) {
  const response = await fetch(`https://api.zoom.us/v2/meetings/${encodeURIComponent(meetingId)}/recordings`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  if (!response.ok) throw new Error(`Zoom recordings lookup failed: ${response.status}`);
  const json = await response.json();
  const mp4 = json.recording_files?.find((file: any) =>
    file.file_type === "MP4" &&
    file.status === "completed" &&
    typeof file.download_url === "string"
  );
  if (!mp4) throw new Error("No completed Zoom MP4 recording found.");
  return mp4;
}

async function downloadZoomFile(downloadURL: string, token: string): Promise<Uint8Array> {
  const response = await fetch(downloadURL, {
    headers: { Authorization: `Bearer ${token}` }
  });
  if (!response.ok) throw new Error(`Zoom recording download failed: ${response.status}`);
  return new Uint8Array(await response.arrayBuffer());
}
```

Store to Supabase Storage:

```ts
const path = `zoom-backups/${body.draftId}/${body.lessonId}-${Date.now()}.mp4`;
const bytes = await downloadZoomFile(mp4.download_url, token);

await admin.storage.from("lesson-videos").upload(path, bytes, {
  contentType: "video/mp4",
  upsert: true
});

const { data } = await admin.storage
  .from("lesson-videos")
  .createSignedUrl(path, 60 * 60 * 24 * 7);

return json({
  status: "completed",
  provider: "zoom-cloud-recording",
  meetingId: body.meetingId,
  recordingId: mp4.id,
  playbackURL: data.signedUrl
});
```

Required backend secrets:

```sh
ZOOM_ACCOUNT_ID=...
ZOOM_CLIENT_ID=...
ZOOM_CLIENT_SECRET=...
WCS_ZOOM_BACKUP_SECRET=...
SUPABASE_SERVICE_ROLE_KEY=...
```

## Swift Client Adapter Skeleton

```swift
struct ZoomVideoBackupRequest: Encodable {
    let draftId: UUID
    let moduleId: UUID
    let lessonId: UUID
    let courseTitle: String
    let moduleTitle: String
    let lessonTitle: String
    let meetingId: String?
    let zoomUserId: String?
}

struct ZoomVideoBackupResponse: Decodable, Sendable {
    let status: String
    let provider: String
    let meetingId: String?
    let recordingId: String?
    let playbackURL: URL
    let expiresAt: Date?
}

actor ZoomVideoBackupClient {
    let endpoint: URL
    let bearerToken: String
    let session: URLSession

    init(endpoint: URL, bearerToken: String, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.bearerToken = bearerToken
        self.session = session
    }

    func requestBackup(_ request: ZoomVideoBackupRequest) async throws -> ZoomVideoBackupResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ZoomVideoBackupResponse.self, from: data)
    }
}
```

Apply returned Zoom backup URL to the existing WCS lesson path:

```swift
let response = try await zoomBackupClient.requestBackup(
    ZoomVideoBackupRequest(
        draftId: draft.id,
        moduleId: module.id,
        lessonId: lesson.id,
        courseTitle: draft.title,
        moduleTitle: module.title,
        lessonTitle: lesson.title,
        meetingId: existingZoomMeetingId,
        zoomUserId: "me"
    )
)

try await AdminCourseDraftStore.shared.setManualLessonVideoPlaybackURL(
    draftId: draft.id,
    moduleId: module.id,
    lessonId: lesson.id,
    urlString: response.playbackURL.absoluteString,
    externalVideoSource: ExternalLessonVideoSource(storageToken: "zoom-cloud-recording")
)
```

## Native Zoom Camera-Motion Rendering

The existing native renderer already supports zoom-style motion plans for fallback video generation:

```swift
MotionPlan(type: .slowZoomIn, speed: 0.55, pathControlPoints: nil)
```

Relevant file:

```text
WCS-Platform/Learning/VideoPipeline/LessonVideoStoryboard+MotionKit.swift
```

Use this when Zoom platform recording is unavailable and the app must still produce a deterministic local MP4:

```swift
let pipeline = InstructionalLessonVideoPipeline()
let result = try await pipeline.renderInstructionalLessonVideo(
    draft: draft,
    module: module,
    lesson: lesson,
    settings: .default
)
```

## Safety Rules

- Never ship Zoom client secrets in iOS.
- iOS receives only app-owned signed playback URLs.
- Store Zoom recordings in app-owned storage before publishing to learners.
- Keep Zoom download URLs server-side; treat them as sensitive.
- Preserve provenance using `wcs.externalVideoSource: zoom-cloud-recording`.
- Validate final playback through `LessonVideoSafetyPolicy.validatePlaybackURLString(...)`.

