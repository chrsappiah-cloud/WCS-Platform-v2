#!/usr/bin/env python3
"""Generate App Store Resolution Center reply PDF for WCS Platform resubmission."""

from __future__ import annotations

import shutil
from datetime import date
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import ListFlowable, ListItem, Paragraph, SimpleDocTemplate, Spacer

REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD = "11"
OUT_REPO = REPO_ROOT / "production" / "apple" / f"WCS_App_Store_Review_Reply_v1_0_{BUILD}.pdf"
OUT_DESKTOP = Path.home() / "Desktop" / f"WCS_App_Store_Review_Reply_v1_0_{BUILD}.pdf"
OUT_DESKTOP_NOTES = Path.home() / "Desktop" / f"WCS_App_Store_Notes_for_Review_v1_0_{BUILD}.pdf"


def _styles():
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="TitleDoc",
            parent=styles["Title"],
            alignment=1,
            textColor=colors.HexColor("#1F4E79"),
            spaceAfter=14,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SubTitle",
            parent=styles["Normal"],
            alignment=1,
            fontSize=10,
            textColor=colors.HexColor("#444444"),
            spaceAfter=18,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Head",
            parent=styles["Heading2"],
            textColor=colors.HexColor("#1F4E79"),
            spaceBefore=10,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Body",
            parent=styles["BodyText"],
            leading=14,
            spaceAfter=8,
        )
    )
    return styles


def _bullets(styles, items: list[str]) -> ListFlowable:
    return ListFlowable(
        [ListItem(Paragraph(item, styles["Body"]), leftIndent=12) for item in items],
        bulletType="bullet",
        start="•",
    )


def build_story(styles) -> list:
    today = date.today().strftime("%B %d, %Y")
    return [
        Paragraph("WCS Platform — App Store Review Reply", styles["TitleDoc"]),
        Paragraph(
            "Resolution Center response · Guideline 3.1.1 (commerce)<br/>"
            f"Resubmission build 1.0 ({BUILD}) · Prepared {today}",
            styles["SubTitle"],
        ),
        Paragraph("Hello App Review Team,", styles["Body"]),
        Paragraph(
            "Thank you for your prior guidance on <b>Guideline 3.1.1</b>. In build "
            f"<b>1.0 ({BUILD})</b>, we have <b>removed Apple commerce entirely</b> from the app.",
            styles["Body"],
        ),
        Paragraph("Summary of changes", styles["Head"]),
        _bullets(
            styles,
            [
                "<b>WCScommerce frameworkAccessManager</b> deleted — no commerce framework 2 product loading, commerce action, restore, or entitlement sync.",
                "<b>Access &amp; account</b> no longer shows AccessStoreView, Restore Commerces, or commerce badges.",
                "Screen now shows Plan overview, optional hosted external link (external, labeled), and organization/investor B2B links only.",
                "Profile removed “Get Assigned with commerce” upsell; assigned follows server-side records.",
                "All commerce framework imports, product IDs, and commerce telemetry removed from Release builds.",
            ],
        ),
        Spacer(1, 6),
        Paragraph("How to validate (reviewer path)", styles["Head"]),
        _bullets(
            styles,
            [
                "Launch app → open <b>Profile</b> tab.",
                "Tap <b>Access &amp; account</b>.",
                "View <b>Plan overview</b> (Free Audit and Pro descriptions).",
                "If configured: <b>Continue now</b> under Enroll to Assigned opens external hosted external link (external provider).",
                "Organization &amp; investor procurement links appear only when env-configured (B2B, labeled).",
                "Return to <b>Programs</b> — access follows free-tier or server entitlement gating.",
            ],
        ),
        Spacer(1, 6),
        Paragraph("Compliance", styles["Head"]),
        _bullets(
            styles,
            [
                "No consumer digital content sold through commerce; commerce framework is not used.",
                "External links are user-initiated and labeled for B2B procurement only.",
                "No in-app card capture for consumers.",
                "Admin AI Course Studio is optional (admin-only; not required for review).",
            ],
        ),
        Paragraph(
            "Bundle ID: <font face='Courier'>wcs.WCS-Platform</font> · Team ID: TM2WG7HH96 · "
            "Support: christopher.appiahthompson@myworldclass.org",
            styles["Body"],
        ),
        Paragraph(
            "Please contact us if you need additional information. Thank you.",
            styles["Body"],
        ),
        Spacer(1, 12),
        Paragraph(
            "<i>Notes for Review (paste in App Store Connect): see WCS_App_Store_Notes_for_Review_v1_0_11 on Desktop.</i>",
            styles["Body"],
        ),
    ]


def write_pdf(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    styles = _styles()
    doc = SimpleDocTemplate(
        str(path),
        pagesize=A4,
        rightMargin=48,
        leftMargin=48,
        topMargin=48,
        bottomMargin=48,
    )
    doc.build(build_story(styles))


def main() -> None:
    write_pdf(OUT_REPO)
    shutil.copy2(OUT_REPO, OUT_DESKTOP)
    # Same PDF serves as attachment for notes reference
    shutil.copy2(OUT_REPO, OUT_DESKTOP_NOTES)
    print(f"Wrote: {OUT_REPO}")
    print(f"Wrote: {OUT_DESKTOP}")
    print(f"Wrote: {OUT_DESKTOP_NOTES}")


if __name__ == "__main__":
    main()
