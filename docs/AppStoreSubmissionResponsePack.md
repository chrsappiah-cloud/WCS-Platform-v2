# WCS App Store Submission Response Pack

Use this document as a copy-paste source for App Store Connect fields and review/compliance responses.

## 1) Final Metadata Copy

### App Name
World Class Scholars

### Subtitle (max 30)
AI-Powered Learning Paths

### Promotional Text
Build real skills with structured courses, guided videos, quizzes, assignments, and discussion communities.

### Description
World Class Scholars (WCS) is a modern learning platform that helps learners build practical mastery through guided, high-quality course experiences.

With WCS, you can:
- Discover curated learning programs
- Follow structured modules and lessons
- Watch guided learning videos
- Complete quizzes and assignments with progress tracking
- Join discussion spaces to collaborate with peers

For course creators and admins, WCS includes AI-assisted course generation workflows to design curriculum, outcomes, and publish-ready course structures.

Whether you are upskilling for career growth or building expertise in a new domain, WCS delivers a focused and measurable learning journey.

### Keywords
learning,online courses,education,ai learning,upskill,quiz,assignments,study

### Primary Category
Education

### Secondary Category
Productivity

### Support URL
Replace with your production support URL.

### Marketing URL
Replace with your production marketing URL.

### Privacy Policy URL
Replace with your production privacy policy URL.

---

## 2) App Review Notes (Copy/Paste)

Use this in the **Review Notes** field:

WCS is a learning platform focused on course discovery, enrollment, lesson viewing, quizzes, assignments, and community discussion.

Reviewer flow:
1. Open app
2. Discover courses on Home
3. Open course detail
4. Enroll and open lessons/modules
5. Submit assignment or quiz

Notes:
- Login is optional for core browsing flows (if this is still true in release build).
- Admin AI Course Studio exists for internal/admin workflows and is not required for standard learner validation.
- No special hardware is required.

If your current release requires login, replace the first note with reviewer demo credentials.

---

## 3) Compliance Responses

These are the standard App Store compliance prompts and ready responses. Keep only the one that matches your final implementation.

### Export Compliance (Encryption)

If you only use Apple system encryption (HTTPS/TLS, Keychain, URLSession) and no custom crypto:
- Response: **No**, app does not use non-exempt encryption.
- Optional note: App uses only exempt encryption provided by Apple OS frameworks.

If you implemented custom encryption algorithms or non-exempt crypto:
- Response: **Yes** and complete export compliance filing details.

### Content Rights
- Response: **Yes**, you have rights to all course text, media, branding assets, and generated content delivered in the app.

### Advertising Identifier (IDFA)

If app does not use ad attribution SDKs:
- Response: **No**, app does not use IDFA.

If ad SDKs are present:
- Response: **Yes**, select only the exact tracking/attribution purposes used.

### Sign-In Requirement

If users can browse before login:
- Response: Explain guest browsing and optional account creation.

If login required:
- Provide reviewer credentials and any 2FA bypass instructions.

---

## 4) Privacy Nutrition Label Draft

Use this as a drafting checklist when filling App Privacy. Confirm with your backend implementation and legal policy before submission.

- Contact Info: only if account/support contact is collected.
- User Content: assignments, discussion posts, uploaded text/media.
- Identifiers: account/user ID if authenticated.
- Usage Data: analytics/events only if analytics SDK is enabled.
- Diagnostics: crash logs if crash reporting is enabled.

Data use flags to confirm:
- Linked to user: yes/no per data type.
- Used for tracking: expected **No** unless cross-app tracking/ad networks are used.

---

## 5) Icon and Launch Image Submission Notes

Use in internal release notes or reviewer clarification if requested:

- App icon set is configured in `WCS-Platform/Assets.xcassets/AppIcon.appiconset`.
- All App Store icon variants were re-exported without alpha channel to satisfy App Store validation.
- Launch branding is configured in `WCS-Platform/Assets.xcassets/LaunchBrand.imageset` and referenced via `WCS-Platform/Info.plist`.
- Assets are original brand assets for World Class Scholars (WCS).

---

## 6) Build/Version Statement

Use this in release notes or review communication:

- Bundle ID: `wcs.WCS-Platform`
- Version: `1.0.1`
- Build: `4`
- Numeric App Store Connect Apple ID (for `altool --build-status`, not Team ID): see `docs/AppStoreNumericAppleId.txt` (refresh with `bash scripts/fetch-appstore-apple-id.sh` after setting `ASC_API_KEY_ID` and `ASC_API_ISSUER_ID`). To copy the ID to the clipboard on macOS: `COPY_TO_CLIPBOARD=1 bash scripts/fetch-appstore-apple-id.sh`

---

## 7) Final Submission Checklist (Quick)

- Metadata fields complete with production URLs
- Privacy Policy URL resolves publicly
- App Privacy questionnaire completed
- Export compliance answer matches actual crypto behavior
- Build selected under iOS version in App Store Connect
- Reviewer notes added (and credentials if required)
- Submit for Review

---

## 8) Upload Command (CLI)

If using App Store Connect API keys:

```bash
ASC_API_KEY_ID=<KEY_ID> ASC_API_ISSUER_ID=<ISSUER_ID> bash scripts/upload-appstore.sh
```

Default IPA path expected:

`build/AppStoreExport/WCS-Platform.ipa`

### Numeric Apple ID (automate, save, copy)

- Saved in-repo: `docs/AppStoreNumericAppleId.txt` (digits-only line is the ID).
- Refresh from App Store Connect:

```bash
ASC_API_KEY_ID=<KEY_ID> ASC_API_ISSUER_ID=<ISSUER_ID> bash scripts/fetch-appstore-apple-id.sh
```

- Copy ID to clipboard (macOS): `COPY_TO_CLIPBOARD=1 ASC_API_KEY_ID=... ASC_API_ISSUER_ID=... bash scripts/fetch-appstore-apple-id.sh`
