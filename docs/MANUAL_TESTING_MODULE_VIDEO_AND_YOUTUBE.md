# Manual testing: module lesson video backups and YouTube streaming

This checklist covers **manual HTTPS lesson video fallbacks** (admin) and **YouTube Data API companion streaming** aligned to modules/lessons (enrolled learners). It is intended for QA on device or simulator with a real Xcode scheme.

**Important:** “Manual module video” in this app means **pasting a valid `https://` playback URL** (MP4, HLS master such as `.m3u8`, or a signed CDN URL). There is **no in-app binary upload**; hosting is external (CDN, Supabase Storage, etc.).

---

## Preconditions

| Item | Action |
|------|--------|
| Admin access | **Profile** → enter admin access code (or set **Mock role** to **Org admin** and use **WCS AI Course Generation**). Unlock the creator screen if prompted. |
| YouTube companion (optional but required for YouTube sections) | **Recommended:** copy `LocalSecrets.xcconfig.example` at the repo root to **`LocalSecrets.xcconfig`** (gitignored), set `YOUTUBE_DATA_API_KEY`, attach under **Project → Info → Configurations** for the **WCS-Platform** target. **Or** target **Build Settings → User-Defined → `YOUTUBE_DATA_API_KEY`**. **Or** scheme **Environment Variables** (overrides plist when non-empty). Key needs [YouTube Data API v3](https://developers.google.com/youtube/v3) enabled. |
| Manual backup video URL | Must be **`https://` only**; `http://` is rejected when creating a manual backup draft. |
| Sample primary URLs | Use any stable **HTTPS** stream the app can play in `AVPlayer`, e.g. Apple sample HLS: `https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8` or a known MP4 URL. |
| Learner path | After publishing, open the course from the catalog as a **learner**, **enroll**, then open **Course detail** and a **video** lesson. |

---

## A. Manual backup draft (single form path)

**Navigation:** **Profile** → **WCS AI Course Generation** → section **“Manual backup authoring (upload fallback)”**.

| # | Step | Expected |
|---|------|----------|
| A1 | Fill **all** fields (title, summary, module title, **video lesson title**, **Video URL (HTTPS)**`, reading, quiz, assignment titles and bodies). Use a valid `https://` video URL in **Video URL (HTTPS)**. | **Create manual backup draft** enables when every field is non-empty. |
| A2 | Tap **Create manual backup draft**. | A new draft appears in **Drafts** with a video lesson; no validation error for HTTPS URL. |
| A3 | Open the draft card’s disclosure **“Manual lesson video backups (per module)”**. | The video lesson row shows the extracted URL (from draft notes / merge line `wcs.manualVideoURL:`). |
| A4 | **Publish** the draft (admin). | Publish succeeds for structured manual backup content. |
| A5 | As learner: enroll, open the published course, play the **video** lesson. | Playback uses the **manual HTTPS URL** (native/HLS path), not a random sample, when that URL was set in the form. |

---

## B. Per-lesson manual video backup (draft card)

**Navigation:** Same screen → **Drafts** → expand **“Manual lesson video backups (per module)”** on any draft that has **video** or **live** lessons.

| # | Step | Expected |
|---|------|----------|
| B1 | Paste a valid `https://` URL in a lesson row; tap **Save backup URL**. | No error; URL persists after leaving and returning (row reloads from `lesson.notes`). |
| B2 | Tap **Clear backup** for that lesson. | Field clears; manual line removed from notes; published course rebuild drops that pin when applicable. |
| B3 | Enter `http://insecure.example.com/video.mp4` (no `s`) and save. | Error: valid **https** playback URL required (store validation). |
| B4 | Publish (or already published), then change backup URL and save. | **MockLearningStore** prefers **manual backup** over AI-generated `playbackURL` when resolving `Lesson.videoURL`. |
| B5 | With manual backup set, trigger **Resume generation** / **Regenerate fresh** from the draft card. | **Manual pin wins:** generated assets must **not** overwrite `videoURL` for lessons that have a recorded manual backup (`applyGeneratedVideoAsset` skips when manual is pinned). |

---

## C. Course detail — Phase 4 companion YouTube block

**Navigation:** Enrolled course → **Course detail** (scroll below scholarship / hydration content).

| # | Step | Expected |
|---|------|----------|
| C1 | **With** `YOUTUBE_DATA_API_KEY` set; enrolled course with video lessons. | Section **“Build-up · Phase 4 — companion video from syllabus”** appears when companion results are non-empty. |
| C2 | Read helper copy under the block. | Mentions module titles, lesson names, live YouTube search, and opening a video lesson to switch sources. |
| C3 | Horizontal scroll of snippets. | Each snippet shows **embedded player** + title; queries relate to module/lesson script lines. |
| C4 | **Without** API key (remove env var, clean build/run). | **“Optional companion YouTube embeds”** panel explains key is only for Phase 4; core playback still uses `videoURL`. |

---

## D. In-lesson YouTube backup (module-aligned streaming)

**Navigation:** Enrolled → **Course detail** → tap a **video** lesson that has **companion snippets** (same pipeline as Phase 4).

| # | Step | Expected |
|---|------|----------|
| D1 | Lesson has **course** `videoURL` (HTTPS/HLS) **and** companion snippets. | **Segmented control**: **“Course video”** vs **“YouTube backup”**. Default is course feed when primary exists. |
| D2 | Switch to **YouTube backup**. | **“YouTube module backup”** header; **clip** picker lists Data API snippets; **embed** plays selected clip. |
| D3 | Change clip in the picker. | `UserDefaults` key `wcs.lessonYouTubeModuleBackup.<courseId>.<lessonId>.videoId` stores selection; reopen lesson → **same clip** restored. |
| D4 | Primary `videoURL` is itself a **YouTube** watch URL (if your catalog ever uses that). | App routes to **VideoPlayerView** embed path for primary; **no** duplicate “Course + YouTube backup” segmented tabs when primary already hosts YouTube. |
| D5 | No primary URL but snippets exist. | UI opens **YouTube backup** path (no dead “Course video” tab-only state without stream). |
| D6 | No primary URL **and** no snippets. | **Content unavailable**: guidance to configure YouTube or get an instructor URL. |

---

## E. SwiftUI previews (design / smoke)

| # | Step | Expected |
|---|------|----------|
| E1 | Xcode → `LessonVideoWithYouTubeBackupView.swift` → Canvas. | Two previews: **course video + YouTube backup** and **YouTube backup only**. |

---

## F. Regression touches

| # | Area | Quick check |
|---|------|-------------|
| F1 | Video lesson **without** companion snippets | Uses **VideoPlayerView** only (no segmented YouTube UI). |
| F2 | **Telemetry / duplicate loads** | Rapid navigate away and back to same course: no obvious duplicate spinner storms (fingerprint/coalesced `loadCourse` behavior). |
| F3 | **Admin diagnostics** | **Profile** → **Check generation APIs** (or pipeline check): YouTube row reflects key present/absent consistently with runtime. |

---

## Sign-off

| Section | Tester | Build / date | Pass / Fail | Notes |
|---------|--------|--------------|---------------|-------|
| A — Manual backup draft | | | | |
| B — Per-lesson backup row | | | | |
| C — Phase 4 course block | | | | |
| D — In-lesson YouTube backup | | | | |
| E — Previews | | | | |
| F — Regression | | | | |

---

## Reference (engineering)

- Manual URL storage: `LessonManualVideoBackup` (`wcs.manualVideoURL:` line in `AdminLessonDraft.notes`).
- Admin UI: `AdminCourseCreatorView` → `ManualLessonVideoBackupRow`, `DraftCard` disclosure **“Manual lesson video backups (per module)”**.
- Publish + catalog resolution: `AdminCourseDraftStore.setManualLessonVideoPlaybackURL`, `MockLearningStore.makeCourse` / `applyGeneratedVideoAsset`.
- YouTube client: `YouTubeSearchAPIClient` (`YOUTUBE_DATA_API_KEY` from **process environment**).
- Learner UI: `CourseDetailView` (`phaseFourCompanionVideoBlock`, `lessonDestination`), `LessonVideoWithYouTubeBackupView`, `CourseDetailViewModel.companionSnippets(forLessonId:)`.
