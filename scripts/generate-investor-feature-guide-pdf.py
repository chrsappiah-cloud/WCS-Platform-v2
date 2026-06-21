#!/usr/bin/env python3
"""Generate 20-page WCS Platform investor/consumer feature guide PDF."""

from __future__ import annotations

import shutil
from datetime import date
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    Image,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
)

REPO_ROOT = Path(__file__).resolve().parents[1]
IMAGES = Path.home() / "Desktop" / "WCS-Platform-Investor-Pack-build11" / "images"
OUT_REPO = REPO_ROOT / "production" / "apple" / "WCS_Platform_Investor_Feature_Guide_20pg.pdf"
OUT_DESKTOP = Path.home() / "Desktop" / "WCS_Platform_Investor_Feature_Guide_20pg.pdf"
BRAND = colors.HexColor("#1F4E79")


def _styles():
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="CoverTitle",
            parent=styles["Title"],
            fontSize=26,
            alignment=TA_CENTER,
            textColor=BRAND,
            spaceAfter=16,
        )
    )
    styles.add(
        ParagraphStyle(
            name="CoverSub",
            parent=styles["Normal"],
            fontSize=12,
            alignment=TA_CENTER,
            textColor=colors.HexColor("#444444"),
            spaceAfter=10,
        )
    )
    styles.add(
        ParagraphStyle(
            name="PageTitle",
            parent=styles["Heading1"],
            fontSize=16,
            textColor=BRAND,
            spaceBefore=4,
            spaceAfter=10,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Body",
            parent=styles["BodyText"],
            fontSize=10.5,
            leading=14,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Footer",
            parent=styles["Normal"],
            fontSize=8,
            textColor=colors.grey,
            alignment=TA_CENTER,
        )
    )
    return styles


def _page_footer(styles, n: int) -> list:
    return [
        Spacer(1, 0.2 * inch),
        Paragraph(f"WCS Platform · Investor & Consumer Feature Guide · Page {n} of 20", styles["Footer"]),
        PageBreak(),
    ]


def _body(styles, text: str) -> Paragraph:
    return Paragraph(text, styles["Body"])


def _maybe_image(name: str, width: float = 4.8 * inch) -> list:
    path = IMAGES / name
    if not path.exists():
        return []
    img = Image(str(path), width=width, height=width * 1.78)
    img.hAlign = "CENTER"
    return [Spacer(1, 6), img, Spacer(1, 10)]


def build_pages(styles) -> list:
    today = date.today().strftime("%B %d, %Y")
    story: list = []

    # Page 1 — Cover
    story += [
        Spacer(1, 1.4 * inch),
        Paragraph("WCS Platform", styles["CoverTitle"]),
        Paragraph("iOS Learning Application", styles["CoverSub"]),
        Paragraph("20-Page Feature &amp; Function Guide", styles["CoverSub"]),
        Paragraph("For Investors and Consumers", styles["CoverSub"]),
        Spacer(1, 0.4 * inch),
        Paragraph(
            f"World Class Scholars · Version 1.0 (Build 11) · {today}<br/>"
            "Bundle ID: wcs.WCS-Platform · Platform: iPhone &amp; iPad (SwiftUI)",
            styles["CoverSub"],
        ),
        Spacer(1, 0.6 * inch),
        _body(
            styles,
            "This document describes the product capabilities, user journeys, technology foundations, "
            "and commercial model of the WCS Platform native iOS application. It is intended for "
            "due diligence, investor briefings, consumer transparency, and App Store marketing alignment.",
        ),
    ]
    story += _page_footer(styles, 1)

    pages: list[tuple[str, str, str | None]] = [
        (
            "Executive Summary",
            """
            <b>WCS Platform</b> is a native iOS education application that delivers structured learning
            programs for individual learners, care-sector professionals, and organizational cohorts.
            The product combines course discovery, enrollment, sequenced modules, video lessons, quizzes,
            assignments, progress tracking, and community discussion in a single SwiftUI experience.
            <br/><br/>
            For <b>consumers</b>, the app offers a trustworthy catalog of programs with clear progress
            signals and accessible support contacts. For <b>investors</b>, WCS pairs a scalable content
            pipeline (AI-assisted authoring and video generation) with enterprise-ready procurement paths
            and compliance-first external account—without consumer commerce complexity in the
            current App Store build.
            <br/><br/>
            The application is production-hardened with privacy manifests, CI quality gates, simulator and
            device UI tests, and documented reviewer paths for Apple App Store compliance.
            """,
            None,
        ),
        (
            "Product Vision &amp; Mission",
            """
            World Class Scholars exists to make high-quality, structured learning available to learners
            who need clarity—not clutter. The iOS app expresses that mission through:
            <br/>• <b>Open discovery</b> of programs with transparent structure (modules, lessons, assessments).
            <br/>• <b>Trust surfaces</b> on the Discover tab (course designer contact, learner stories, support email).
            <br/>• <b>Progress you can trust</b> via enrollment state, lesson completion, and quiz outcomes.
            <br/>• <b>Companion media</b> where appropriate (lesson video, optional YouTube enrichment).
            <br/><br/>
            Unlike generic video libraries, WCS is a <i>learning operating system</i>: content is organized,
            assessed, and discussed—not merely streamed. The admin-facing AI Course Studio (restricted role)
            accelerates curriculum authoring for institutions that license the platform.
            """,
            None,
        ),
        (
            "Who the App Serves",
            """
            <b>Individual learners</b> browse programs, enroll in free-audit or assigned tiers, complete
            lessons and quizzes, and participate in cohort discussions.<br/><br/>
            <b>Care and creative-arts professionals</b> benefit from specialized programs (e.g., dementia-inclusive
            creative learning) with practical modules and reflective discussion.<br/><br/>
            <b>Organizations &amp; investors (B2B)</b> use clearly labeled external procurement links for seat
            licensing and enterprise contracts—separate from consumer app flows.<br/><br/>
            <b>Administrators &amp; instructional designers</b> access AI-assisted draft generation, scene-based
            video pipelines, and publish workflows (admin-only surfaces not required for standard App Review).
            """,
            None,
        ),
        (
            "Navigation Architecture",
            """
            The app uses a five-tab <b>TabView</b> (iOS 18+):<br/>
            <b>Discover</b> — featured programs, resume learning, trust cluster, support.<br/>
            <b>Programs</b> — full course catalog and search.<br/>
            <b>Discussion</b> — community threads tied to learning cohorts.<br/>
            <b>Profile</b> — identity, enrollments, access &amp; account, settings.<br/>
            <b>About</b> — platform mission, policies, institutional context.<br/><br/>
            Each tab is wrapped in a <b>NavigationStack</b> for deep linking into course detail, lessons,
            quizzes, and admin tools. Brand accent color (#1F4E79) and rounded typography reinforce a
            professional, accessible edtech aesthetic consistent across iPhone and iPad layouts.
            """,
            None,
        ),
        (
            "Discover Tab — Featured Learning",
            """
            The Discover home screen welcomes learners with <b>“Open learning, WCS-owned.”</b> Featured program
            cards scroll horizontally for quick entry into high-priority courses. Enrolled users see a
            <b>Resume learning</b> strip linking directly to in-progress programs.<br/><br/>
            The <b>Course designer contact card</b> surfaces Dr Christopher Appiah-Thompson with one-tap
            email to activated support addresses (primary: christopher.appiahthompson@myworldclass.org;
            secondary: chrsappiah@gmail.com). Learner testimonial pages provide social proof (placeholder
            content flagged for marketing replacement before campaigns).<br/><br/>
            Capability rows summarize platform strengths: structured modules, graded assessments, video
            lessons, and offline-tolerant networking where configured.
            """,
            "01-discover-home.png",
        ),
        (
            "Programs Tab — Course Catalog",
            """
            The Programs tab presents the full <b>course catalog</b> as browsable cards with titles,
            descriptions, module counts, and enrollment status. Learners can search and filter to find
            programs aligned with their goals.<br/><br/>
            Each course maps to a structured backend model: goals, outcomes, modules, lessons, quizzes,
            and assignments. Free-audit tiers allow exploration; assigned tiers gate advanced lessons per
            server-side entitlement records (no commerce framework in build 11).<br/><br/>
            Navigation to <b>Course Detail</b> reveals syllabus structure, instructor context, and enroll
            actions—forming the primary conversion funnel for individual learners.
            """,
            "02-programs-catalog.png",
        ),
        (
            "Course Detail &amp; Enrollment",
            """
            Course Detail consolidates marketing copy, learning outcomes, module syllabus, and enrollment
            state. Tapping <b>Enroll</b> registers the learner and unlocks module navigation according to
            plan tier.<br/><br/>
            The screen communicates expectations: lesson types (video, reading, quiz), estimated effort,
            and discussion participation. Progress rings or completion chips update as learners advance.<br/><br/>
            Gating logic respects <b>free audit vs. assigned</b> boundaries without in-app card capture;
            enroll paths route to Access &amp; account with labeled external link when configured.
            """,
            "03-course-detail.png",
        ),
        (
            "Modules, Lessons &amp; Sequencing",
            """
            Within a course, <b>modules</b> group related lessons into pedagogical units—mirroring textbook
            chapters but optimized for mobile consumption. Lessons declare type: video playback, text content,
            quiz checkpoint, or assignment submission.<br/><br/>
            Sequencing rules prevent skipping required assessments where policy demands mastery checks.
            LessonVideoPlaybackPolicy governs autoplay, background audio, and accessibility captions where
            available.<br/><br/>
            Module-level <b>video discovery</b> can attach companion YouTube educational clips derived from
            lesson scripts (API-key gated; graceful fallback when unavailable).
            """,
            None,
        ),
        (
            "Video Lesson Playback",
            """
            Video lessons render in a dedicated player surface with standard transport controls, lesson title,
            and navigation to adjacent lessons. Assets may originate from:<br/>
            • Cached AI-generated lesson MP4s (admin pipeline)<br/>
            • Remote URLs via Supabase/OpenAI orchestration when live stack enabled<br/>
            • On-device AVFoundation image-sequence renders for demos and tests<br/>
            • Manual external uploads validated for format and safety<br/><br/>
            <b>LessonVideoWithYouTubeBackupView</b> offers companion clips without replacing first-party
            instructional video. Playback respects network resilience (retries, circuit breaker, stale cache).
            """,
            "04-lesson-video.png",
        ),
        (
            "Quizzes &amp; Assessments",
            """
            Quizzes validate comprehension through multiple-choice and structured prompts tied to lesson
            objectives. The Quiz flow includes start screen, per-question navigation, and completion summary
            with score feedback.<br/><br/>
            QuizViewModel synchronizes state with MockLearningStore / production APIs. Results contribute to
            profile progress metrics and may unlock subsequent modules.<br/><br/>
            Assessment checkpoints embedded in <b>scene-based video plans</b> (instructional design layer)
            align video content with formative checks—supporting mastery-based pathways for institutional buyers.
            """,
            "05-quiz-assessment.png",
        ),
        (
            "Assignments &amp; Progress Tracking",
            """
            Assignments extend beyond auto-graded quizzes: learners may submit reflective responses or
            evidence of practice (configuration-dependent). Instructors or admins review submissions outside
            the consumer critical path.<br/><br/>
            <b>Progress tracking</b> aggregates lesson completions, quiz scores, and enrollment timestamps on
            the Profile and Resume cards. Telemetry uses structured event names without logging access data.<br/><br/>
            The design prioritizes <i>visible progress</i>—learners always know what to do next, reducing
            dropout common in unstructured MOOC experiences.
            """,
            None,
        ),
        (
            "Discussion &amp; Community",
            """
            The Discussion tab hosts cohort conversations: threaded posts, replies, and compose actions.
            MockDiscussionStore powers demo mode; production connects to moderated community APIs.<br/><br/>
            Discussion reinforces social learning—particularly valuable for care-sector cohorts reflecting
            on practice. Notifications (Core/Notifications) can alert users to replies when push is enabled
            and permitted.<br/><br/>
            Community guidelines and reporting flows align with App Store safety expectations; admin tools
            can curate or remove content at the API layer.
            """,
            "06-discussion-community.png",
        ),
        (
            "Profile &amp; Learner Identity",
            """
            Profile centralizes the learner identity: display name, avatar, enrollment list, and shortcuts to
            Access &amp; account and settings. Assigned status reflects <b>server-side access records</b>
            (commerce framework removed in build 11).<br/><br/>
            Sign-in state bootstraps on launch via AppViewModel. Keychain and UserDefaults persist non-sensitive
            preferences under declared privacy manifest reasons.<br/><br/>
            Profile is the anchor for <b>reviewer validation</b> of plan tiers and external enroll links.
            """,
            "07-profile.png",
        ),
        (
            "Access &amp; Account (Build 11)",
            """
            Build <b>1.0 (11)</b> removes Apple commerce entirely to resolve Guideline 3.1.1. The Access
            screen shows:<br/>
            • <b>Plan overview</b> (Free Audit vs. Pro descriptions)<br/>
            • <b>Enroll to Assigned</b> — optional hosted external provider external link URL (env-configured, external)<br/>
            • <b>Organization &amp; investor procurement</b> — B2B links, clearly labeled<br/>
            • <b>Admin payouts</b> — enterprise settlement (admin-only)<br/><br/>
            No consumer card entry in-app. No commerce framework product IDs. Assigned gating uses backend entitlements.
            Debug-only mock assigned toggles are excluded from Release builds.
            """,
            "08-access-account.png",
        ),
        (
            "Admin AI Course Studio",
            """
            Restricted to admin roles, the <b>Admin Course Creator</b> studio generates course drafts with AI:
            goals, modules, lessons, reasoning traces, and video generation jobs.<br/><br/>
            Features include bulk video orchestration, per-scene pipeline controls, instructional text-to-video
            render, hybrid Apple Foundation Models + network fallback planning, and publish-to-catalog actions.<br/><br/>
            Real-time progress UI surfaces job states (queued, rendering, complete, failed). Reviewers may skip
            this surface; it is not required for standard consumer validation.
            """,
            "09-admin-ai-studio.png",
        ),
        (
            "Video &amp; AI Pipeline (Technical)",
            """
            The lesson video stack includes:<br/>
            • <b>Structured scene plans</b> (conditioning, motion, camera, backend model hints)<br/>
            • <b>HybridLessonVideoOrchestrator</b> — Apple FM when iOS 26+ else network heuristic<br/>
            • <b>InstructionalLessonVideoPipeline</b> — text → plan → render → compose MP4<br/>
            • <b>Supabase BFF</b> for OpenAI Sora when live stack enabled<br/>
            • <b>AVFoundation</b> image-sequence fallback for CI and offline demos<br/><br/>
            WCSBackendStackCoordinator probes Supabase, Cloudflare, and iCloud backup tiers for health display.
            """,
            None,
        ),
        (
            "Privacy, Security &amp; Compliance",
            """
            <b>PrivacyInfo.xcprivacy</b> declares required reason APIs. Outbound URLs pass allowlist validation in CI.
            Crossref and YouTube enrichment use query metadata—not learner PII.<br/><br/>
            Support contacts are activated in Info.plist and validated by <code>validate-support-contacts.sh</code>.
            External access links are user-initiated and labeled. Encryption export compliance uses standard iOS TLS.<br/><br/>
            GitHub Actions enforces build, unit tests, UI smoke, E2E gates, and support-contact validation before merge to main.
            """,
            None,
        ),
        (
            "About Tab &amp; Institutional Trust",
            """
            The About tab presents World Class Scholars mission, platform principles, and links to policies.
            Support mailto links use activated emails for learner and reviewer confidence.<br/><br/>
            Home trust cluster and About content align for consistent institutional narrative—critical for
            dementia-care and creative-arts programs where credibility affects enrollment.<br/><br/>
            Investors should note: trust UI is first-class, not an afterthought—reducing support burden and
            App Store clarification cycles.
            """,
            "10-about-trust.png",
        ),
        (
            "Investment Thesis &amp; Roadmap",
            """
            <b>Why invest in WCS Platform iOS?</b><br/>
            1. <b>Differentiated OS-layer</b> — structured learning + AI authoring, not a thin content wrapper.<br/>
            2. <b>Multi-tier monetization</b> — individual assigned (external/hosted), enterprise seats, investor procurement.<br/>
            3. <b>Defensible pipeline</b> — scene-based video orchestration with on-device and cloud backends.<br/>
            4. <b>Production discipline</b> — CI gates, ARC Shield review artifacts, documented reviewer paths.<br/>
            5. <b>Category expertise</b> — dementia-inclusive creative learning vertical with pilot social proof.<br/><br/>
            <b>Roadmap highlights:</b> deeper CMS integration, live cohort scheduling, expanded language support,
            Apple Intelligence adoption on iOS 26+ devices, and international B2B partnerships.
            """,
            None,
        ),
    ]

    page_num = 2
    for title, body, image in pages:
        story.append(Paragraph(title, styles["PageTitle"]))
        story.append(_body(styles, body))
        if image:
            story += _maybe_image(image)
        story += _page_footer(styles, page_num)
        page_num += 1

    return story


def write_pdf(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    styles = _styles()
    doc = SimpleDocTemplate(
        str(path),
        pagesize=A4,
        rightMargin=48,
        leftMargin=48,
        topMargin=44,
        bottomMargin=44,
    )
    doc.build(build_pages(styles))


def main() -> None:
    write_pdf(OUT_REPO)
    shutil.copy2(OUT_REPO, OUT_DESKTOP)
    print(f"Wrote: {OUT_REPO}")
    print(f"Wrote: {OUT_DESKTOP}")


if __name__ == "__main__":
    main()
