#!/usr/bin/env python3
"""Generate WCS iOS Intensive Testing Kit PDF from the repo markdown source."""

from __future__ import annotations

import json
import os
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

REPO_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = REPO_ROOT / "production" / "apple"
MD_PATH = OUT_DIR / "WCS_iOS_Intensive_Testing_Kit.md"
PDF_PATH = OUT_DIR / "WCS_iOS_Intensive_Testing_Kit.pdf"


def build_pdf() -> None:
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="BodyX",
            parent=styles["BodyText"],
            leading=14,
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            name="TitleX",
            parent=styles["Title"],
            alignment=1,
            textColor=colors.HexColor("#1F4E79"),
            spaceAfter=16,
        )
    )
    styles.add(
        ParagraphStyle(
            name="HeadX",
            parent=styles["Heading2"],
            textColor=colors.HexColor("#1F4E79"),
            spaceAfter=10,
        )
    )

    doc = SimpleDocTemplate(
        str(PDF_PATH),
        pagesize=A4,
        rightMargin=40,
        leftMargin=40,
        topMargin=40,
        bottomMargin=40,
    )

    story = [
        Paragraph("WCS iOS Intensive Testing Kit", styles["TitleX"]),
        Paragraph("Prepared for World Class Scholars", styles["BodyX"]),
        Spacer(1, 8),
        Paragraph(
            "A practical production-readiness standard for iOS apps.",
            styles["BodyX"],
        ),
        Spacer(1, 12),
        Paragraph("Chapter themes", styles["HeadX"]),
    ]

    for title, body in [
        (
            "Part I: Foundations",
            "Assertions, lifecycle, coverage, app launch, and dependencies.",
        ),
        (
            "Part II: iOS testing tips and techniques",
            "Outlets, buttons, alerts, navigation, UserDefaults, networking, text fields, tables, and snapshots.",
        ),
        (
            "Part III: Using your new power",
            "Refactoring, MVVM, MVP, and TDD.",
        ),
    ]:
        story.append(Paragraph(f"<b>{title}</b>", styles["BodyX"]))
        story.append(Paragraph(body, styles["BodyX"]))

    story.append(Paragraph("WCS module checklist", styles["HeadX"]))
    data = [
        ["Area", "What to test"],
        ["App startup", "Launch path, initial controller, scene/app delegate behavior"],
        ["Forms", "Text entry, return-key behavior, validation, focus changes"],
        ["Navigation", "Push, modal, segue, and dismissal flows"],
        ["Storage", "Defaults, persistence, recovery, and empty-state behavior"],
        ["Networking", "Requests, responses, async completions, errors, retries"],
        ["Tables", "Row count, cell content, row selection, updates"],
        ["Alerts", "Message text, button wiring, cancel/confirm behavior"],
        ["Appearance", "Layout, snapshot comparisons, device variations"],
        ["Refactoring safety", "Tests that protect extracted types and moved logic"],
    ]
    table = Table(data, colWidths=[1.7 * inch, 4.8 * inch])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2F5597")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                (
                    "ROWBACKGROUNDS",
                    (0, 1),
                    (-1, -1),
                    [colors.whitesmoke, colors.HexColor("#F4F7FB")],
                ),
            ]
        )
    )
    story.append(table)
    story.append(Spacer(1, 8))

    story.append(Paragraph("WCS Apple Store readiness criteria", styles["HeadX"]))
    for item in [
        "Direct unit tests for core logic.",
        "View controller tests for UI behavior.",
        "Dependency isolation for external services.",
        "Coverage for edge cases and failure paths.",
        "Snapshot or UI checks for critical appearance.",
        "CI execution with green results.",
        "Safe refactoring coverage before structural changes.",
    ]:
        story.append(Paragraph(f"• {item}", styles["BodyX"]))

    story.append(Paragraph("Suggested suite structure", styles["HeadX"]))
    for item in [
        "AppLaunchTests",
        "AssertionTests",
        "LifecycleTests",
        "CoverageTests",
        "StartupControllerTests",
        "NavigationTests",
        "StorageTests",
        "NetworkRequestTests",
        "NetworkResponseTests",
        "TextFieldTests",
        "TableViewTests",
        "AlertTests",
        "SnapshotTests",
        "RefactoringSafetyTests",
    ]:
        story.append(Paragraph(f"• {item}", styles["BodyX"]))

    doc.build(story)

    meta = {
        "caption": "WCS iOS Intensive Testing Kit",
        "description": "Regenerated PDF with branded headings and checklist tables.",
        "source_markdown": str(MD_PATH),
    }
    PDF_PATH.with_suffix(".pdf.meta.json").write_text(
        json.dumps(meta, indent=2), encoding="utf-8"
    )


if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if not MD_PATH.exists():
        raise SystemExit(f"Missing markdown source: {MD_PATH}")
    build_pdf()
    print(MD_PATH)
    print(PDF_PATH)
    print(os.path.getsize(PDF_PATH))
