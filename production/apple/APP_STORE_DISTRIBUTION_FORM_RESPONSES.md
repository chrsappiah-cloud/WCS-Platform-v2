# WCS Platform — App Store Connect Distribution Form Responses

Copy-paste source for **App Store Connect → App → Distribution / App Information / Pricing and Availability / App Privacy / Version** fields and review questionnaires.

**Release line (from `WCS-Platform/project.yml`):**

| Field | Value |
|-------|--------|
| App name (store) | WCS Platform |
| Bundle ID | `wcs.WCS-Platform` |
| Marketing version | `1.1.0` |
| Build | `2` |
| SKU (example) | `wcs-platform-ios` |
| Primary language | English (U.S.) |
| Team ID | `TM2WG7HH96` |

> **Note:** Production docs also reference `org.worldclassscholars.platform`. Before final submission, align **Bundle ID** in `project.yml`, Xcode signing, and App Store Connect to a single identifier.

---

## 1) App Information

| Field | Response |
|-------|----------|
| **Name** | WCS Platform |
| **Subtitle** (≤30 chars) | Structured learning paths |
| **Category — Primary** | Education |
| **Category — Secondary** | Productivity |
| **Content Rights** | Yes — we have rights to all in-app text, media, branding, and course materials shown in this version. |
| **Age Rating** | Complete the questionnaire; expect **4+** / low maturity (education app, no graphic violence). Adjust if user-generated discussion content is rated higher in your jurisdiction. |

### Promotional text (170 chars max)

Structured programs, guided video lessons, quizzes, assignments, and discussion—built for learners and teams who want measurable progress.

### Description

WCS Platform is a structured learning app for discovering programs, enrolling in courses, and completing modules with video lessons, quizzes, assignments, and peer discussion.

**Learners can:**
- Browse curated programs and featured courses
- Enroll and track progress across modules and lessons
- Watch guided lesson video with companion resources where available
- Complete quizzes and assignments
- Participate in course discussions

**Admins** (restricted access) can use AI-assisted course authoring workflows; this path is not required for standard App Review.

WCS is designed for clarity, progress you can trust, and privacy-conscious defaults.

### Keywords

learning,courses,education,modules,quiz,assignments,discussion,professional development,WCS

### URLs

| Field | Value |
|-------|--------|
| **Support URL** | `https://worldclassscholars.org/support` *(replace with live URL before submit)* |
| **Marketing URL** | `https://worldclassscholars.org` *(optional)* |
| **Privacy Policy URL** | `https://worldclassscholars.org/privacy` *(replace with live URL before submit)* |

---

## 2) Version information (1.1.0)

### What’s New

- Stability and discovery improvements for programs, media playback, and offline-tolerant networking.
- Privacy manifest and compliance alignment for App Store requirements.
- Expanded automated test coverage for release confidence.

### Copyright

© 2026 World Class Scholars. All rights reserved.

### Routing app coverage file

Not applicable (not a routing app).

---

## 3) Screenshots & previews

Upload PNGs from:

`production/apple/promotional/distribution/`

| Device class in App Store Connect | Folder | Size (portrait) |
|-----------------------------------|--------|-----------------|
| **iPhone 6.7" Display** | `distribution/iphone-6.7/` | 1290 × 2796 |
| **iPad Pro (12.9-inch) (3rd generation)** | `distribution/ipad-12.9/` | 2048 × 2732 |
| **iPad Pro (12.9-inch) (2nd gen) landscape** (optional hero) | `distribution/ipad-12.9-landscape/` | 2732 × 2048 |

Manifest: `production/apple/promotional/distribution-manifest.json`

**Regenerate:**

```bash
bash scripts/capture-appstore-screenshots.sh
# or, if raw captures already exist:
python3 scripts/generate-appstore-distribution-assets.py
```

---

## 4) App Review Information

### Contact

| Field | Suggested value |
|-------|-----------------|
| First name | Christopher |
| Last name | Appiah-Thompson |
| Phone | *(your production support number)* |
| Email | *(your App Store review contact email)* |

### Notes for reviewer

WCS Platform is an education app: course discovery → course detail → enroll → lessons (video), quizzes, assignments, and discussion.

**Suggested path:**
1. Open app (mock/demo catalog loads without login if configured for review build).
2. **Discover** tab — browse featured programs.
3. **Programs** tab — open a course → view modules/lessons.
4. **Discussion** tab — view course threads.
5. **Profile** tab — membership and settings.

- **Login:** Optional for browsing in review configuration; if login is required in your production build, add demo credentials here.
- **Admin / AI Course Studio:** Restricted to admin users; not required for learner validation.
- **Payments:** External hosted checkout links are opened only after explicit user tap and are labeled as hosted checkout (see compliance packet). No in-app card entry.
- **Hardware:** None required.

### Demo account (if login required)

| Field | Value |
|-------|--------|
| Username | `reviewer@worldclassscholars.org` |
| Password | *(set in App Store Connect only — do not commit)* |

### Attachment

Optional: link to `docs/AppStore_Review_Compliance_Packet.md` exported as PDF for internal use; App Store Connect does not accept repo paths directly.

---

## 5) Export compliance (encryption)

**Does your app use encryption?**  
Select the option that matches your build:

| Scenario | Answer |
|----------|--------|
| HTTPS/TLS, Keychain, standard Apple APIs only | **No** — app does not use non-exempt encryption |
| Custom/non-exempt cryptography | **Yes** — complete ERN / compliance documentation |

**Reviewer note (if asked):** The app uses exempt encryption provided by iOS (TLS via URLSession, Keychain). No proprietary crypto algorithms are implemented in-app.

---

## 6) Content & rights declarations

| Prompt | Response |
|--------|----------|
| Third-party content | Yes — educational references and companion YouTube embeds where configured; rights and attribution handled per course. |
| Made for Kids | **No** (unless you intentionally target under-13; then complete Kids category rules). |
| Gambling | No |
| Unrestricted web access | No (in-app browsing is limited; external links use allowlisted hosts). |

---

## 7) App Privacy (nutrition label) — draft

Confirm against `WCS-Platform/PrivacyInfo.xcprivacy` and live backend before submitting.

| Data type | Collected | Linked to user | Used for tracking |
|-----------|-----------|---------------|-------------------|
| Contact info (email, if account) | Optional | Yes | No |
| User content (posts, assignments) | Yes | Yes | No |
| Identifiers (user ID) | If authenticated | Yes | No |
| Usage data / analytics | If enabled | Yes/No per SDK | **No** (unless ad SDK added) |
| Diagnostics (crashes) | If crash reporting enabled | Often no | No |

**Privacy Policy URL** must match the URL in section 1.

---

## 8) Pricing and availability

| Field | Suggested response |
|-------|-------------------|
| Price | Free (or set tier if paid download) |
| Availability | All territories you support, or restrict per business plan |
| Pre-order | No |

**In-app purchases / subscriptions:** If Stripe or external membership checkout is used, ensure App Store **Guideline 3.1.1** disclosures and in-app copy match `docs/AppStore_Review_Compliance_Packet.md`. Add IAP products in Connect if Apple IAP is required for any entitlement.

---

## 9) TestFlight (optional before App Review)

| Field | Response |
|-------|----------|
| Beta App Description | Same as store description, shortened. |
| Feedback email | *(support email)* |
| What to test | Sign-in (if any), course enrollment, lesson playback, discussion, profile/membership hub. |

---

## 10) Submission checklist

- [ ] Bundle ID consistent across Xcode, profiles, and App Store Connect
- [ ] Build `1.1.0 (2)` or newer uploaded and processed
- [ ] iPhone 6.7" and iPad 12.9" screenshots uploaded from `distribution/`
- [ ] Privacy Policy and Support URLs live (HTTP 200)
- [ ] App Privacy questionnaire completed
- [ ] Export compliance answered
- [ ] Review notes + demo account (if needed)
- [ ] **Submit for Review**

---

## Related documents

- `docs/AppStoreSubmissionResponsePack.md` — extended copy-paste pack
- `docs/AppStoreMetadataTemplate.md` — metadata template
- `docs/AppStore_Review_Compliance_Packet.md` — commerce, links, media
- `docs/AppStoreProductionChecklist.md` — end-to-end checklist
- `production/apple/APPLE_STORE_PRODUCTION.md` — production hub
