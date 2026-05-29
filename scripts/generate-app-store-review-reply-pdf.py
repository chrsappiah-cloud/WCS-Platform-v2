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
OUT_REPO = REPO_ROOT / "production" / "apple" / "WCS_App_Store_Review_Reply_v1_0_10.pdf"
OUT_DESKTOP = Path.home() / "Desktop" / "WCS_App_Store_Review_Reply_v1_0_10.pdf"
OUT_DESKTOP_COPY = Path.home() / "Desktop" / "WCS_App_Store_Distribution_Form_v1_0_10.pdf"


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
            "Resolution Center response · Submission ID bfa381c2-5902-4590-a217-e8d85a1fed22<br/>"
            f"Resubmission build 1.0 (10) · Prepared {today}",
            styles["SubTitle"],
        ),
        Paragraph("Hello App Review Team,", styles["Body"]),
        Paragraph(
            "Thank you for your review on May 29, 2026. We submitted updated build "
            "<b>1.0 (10)</b> to resolve <b>Guideline 3.1.1 – In-App Purchase</b> and retain "
            "iPad launch stability fixes from our prior response.",
            styles["Body"],
        ),
        Paragraph("Guideline 3.1.1 – In-App Purchase", styles["Head"]),
        Paragraph(
            "<b>Issue reported:</b> Premium digital content was accessible without In-App Purchase.",
            styles["Body"],
        ),
        Paragraph("<b>Resolution in build 1.0 (10):</b>", styles["Body"]),
        _bullets(
            styles,
            [
                "<b>Individual Pro</b> (Premium course access) is purchased exclusively with "
                "<b>Apple In-App Purchase</b> using StoreKit 2 (<i>SubscriptionStoreView</i>).",
                "<b>Restore purchases</b> is on the same screen: Profile → Membership &amp; subscriptions → Subscribe with Apple.",
                "Premium unlock uses StoreKit entitlements (<i>Transaction.currentEntitlements</i>) and shows as <b>Premium: Active</b> on Profile after purchase or restore.",
                "Consumer-facing hosted Stripe membership checkout was <b>removed from Release builds</b>. External links remain only for organization/investor B2B procurement and are labeled as not replacing Individual Pro IAP.",
                "Developer/mock premium toggles are <b>Debug-only</b> and are not in App Store Release builds.",
            ],
        ),
        Spacer(1, 6),
        Paragraph("How to validate (reviewer path)", styles["Head"]),
        _bullets(
            styles,
            [
                "Open the <b>Profile</b> tab.",
                "Tap <b>Membership &amp; subscriptions</b>.",
                "Under <b>Subscribe with Apple</b>, subscribe to <b>Individual Pro</b> "
                "(product ID: <font face='Courier'>wcs.individual.pro.monthly</font>) or tap <b>Restore purchases</b>.",
                "Return to <b>Programs</b>, open a subscription-gated course, and confirm full lesson access when Premium is active.",
            ],
        ),
        Spacer(1, 6),
        Paragraph("Guideline 2.1(a) – Launch stability", styles["Head"]),
        Paragraph(
            "We retained launch-path hardening for iPad-class devices (including iPad Air 11-inch M3) "
            "and validated on iPhone hardware and simulator CI.",
            styles["Body"],
        ),
        Paragraph("Business model (Guideline 2.1(b))", styles["Head"]),
        _bullets(
            styles,
            [
                "<b>Individual learners:</b> Apple In-App Purchase only for Premium digital content.",
                "<b>Organizations:</b> B2B seat/contract access outside the consumer app; does not bypass Individual Pro IAP.",
            ],
        ),
        Paragraph(
            "Product ID: <font face='Courier'>wcs.individual.pro.monthly</font> · Bundle ID: "
            "<font face='Courier'>wcs.WCS-Platform</font> · Team ID: TM2WG7HH96",
            styles["Body"],
        ),
        Paragraph(
            "Please contact us if you need a sandbox tester account or additional metadata. Thank you.",
            styles["Body"],
        ),
        Spacer(1, 12),
        Paragraph(
            "<i>Distribution form summary: Individual Premium = IAP only; enterprise/investor = B2B external; "
            "no consumer digital unlock outside IAP.</i>",
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
    shutil.copy2(OUT_REPO, OUT_DESKTOP_COPY)
    print(f"Wrote: {OUT_REPO}")
    print(f"Wrote: {OUT_DESKTOP}")
    print(f"Wrote: {OUT_DESKTOP_COPY}")


if __name__ == "__main__":
    main()
