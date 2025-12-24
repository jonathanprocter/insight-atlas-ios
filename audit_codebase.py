#!/usr/bin/env python3
"""
Insight Atlas iOS Codebase Audit Script
Checks for quality and completeness of all exports and functionality.
"""

import os
import re
from pathlib import Path
from dataclasses import dataclass
from typing import List, Tuple

@dataclass
class AuditResult:
    category: str
    check: str
    passed: bool
    message: str
    severity: str = "error"  # error, warning, info

class InsightAtlasAuditor:
    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.results: List[AuditResult] = []
        self.data_manager_path = self.project_path / "InsightAtlas/Services/DataManager.swift"
        self.style_path = self.project_path / "InsightAtlas/Services/InsightAtlasStyle.swift"
        self.guide_view_path = self.project_path / "InsightAtlas/Views/GuideView.swift"
        self.quality_audit_path = self.project_path / "InsightAtlas/Services/QualityAuditService.swift"
        self.regenerate_view_path = self.project_path / "InsightAtlas/Views/RegenerateView.swift"
        self.app_path = self.project_path / "InsightAtlas/InsightAtlasApp.swift"
        self.info_plist_path = self.project_path / "InsightAtlas/Info.plist"
        self.source_roots = [
            self.project_path / "InsightAtlas",
            self.project_path / "InsightAtlasTests",
        ]

    def read_file(self, path: Path) -> str:
        try:
            return path.read_text(encoding='utf-8')
        except Exception as e:
            return ""

    def add_result(self, category: str, check: str, passed: bool, message: str, severity: str = "error"):
        self.results.append(AuditResult(category, check, passed, message, severity))

    def audit_all(self):
        """Run all audit checks"""
        print("=" * 60)
        print("INSIGHT ATLAS iOS CODEBASE AUDIT")
        print("=" * 60)
        print()

        self.audit_html_export()
        self.audit_pdf_export()
        self.audit_docx_export()
        self.audit_guide_view()
        self.audit_quality_service()
        self.audit_regenerate_view()
        self.audit_navigation_styling()
        self.audit_brand_consistency()
        self.audit_project_hygiene()
        self.audit_info_plist()
        self.audit_risky_patterns()

        return self.print_results()

    def audit_html_export(self):
        """Audit HTML export functionality"""
        print("Auditing HTML Export...")
        content = self.read_file(self.data_manager_path)

        # Check for required CSS classes
        required_css_classes = [
            ("quick-glance", "Quick Glance block styling"),
            ("insight-note", "Insight Note block styling"),
            ("action-box", "Action Box block styling"),
            ("visual-flowchart", "Visual Flowchart block styling"),
            ("visual-table", "Visual Table block styling"),
            ("exercise", "Exercise block styling"),
            ("foundational-narrative", "Foundational Narrative styling"),
            ("structure-map", "Structure Map styling"),
            ("takeaways", "Takeaways block styling"),
            ("reading-time-badge", "Reading time badge styling"),
            ("flow-step", "Flowchart step styling"),
            ("flow-arrow", "Flowchart arrow styling"),
            ("styled-table", "Table styling"),
        ]

        for css_class, desc in required_css_classes:
            has_class = f".{css_class}" in content
            self.add_result("HTML Export", f"Has {desc}", has_class,
                          f"CSS class .{css_class} {'found' if has_class else 'MISSING'}")

        # Check for block rendering functions
        required_functions = [
            ("renderSpecialBlock", "Special block renderer"),
            ("renderFlowchartContent", "Flowchart content renderer"),
            ("renderBlockContent", "Block content renderer"),
            ("renderStructureMapContent", "Structure map renderer"),
            ("renderBlockTableContent", "Block table renderer"),
            ("convertInlineMarkdown", "Inline markdown converter"),
            ("calculateReadingTime", "Dynamic reading time calculator"),
        ]

        for func, desc in required_functions:
            has_func = f"func {func}" in content or f"private func {func}" in content
            self.add_result("HTML Export", f"Has {desc}", has_func,
                          f"Function {func} {'found' if has_func else 'MISSING'}")

        # Check for list type tracking
        has_list_type = "listType = \"ul\"" in content and "listType = \"ol\"" in content
        self.add_result("HTML Export", "Proper list type tracking (ul/ol)", has_list_type,
                       "List type tracking for proper tag closure")

        # Check for brand colors in CSS
        brand_colors = [
            ("--gold: #CBA135", "Gold primary color"),
            ("--burgundy: #582534", "Burgundy color"),
            ("--coral: #E76F51", "Coral accent color"),
        ]

        for color, desc in brand_colors:
            has_color = color in content
            self.add_result("HTML Export", f"Has {desc}", has_color,
                          f"Brand color {color} {'defined' if has_color else 'MISSING'}")

        # Check for header structure
        has_header = ".header" in content and ".header .brand" in content
        self.add_result("HTML Export", "Has proper header structure", has_header,
                       "Header with branding elements")

    def audit_pdf_export(self):
        """Audit PDF export functionality"""
        print("Auditing PDF Export...")
        content = self.read_file(self.data_manager_path)

        # Check for PDF generation function
        has_pdf_gen = "func generatePDF" in content
        self.add_result("PDF Export", "Has PDF generation function", has_pdf_gen,
                       "generatePDF function")

        # Check for special block handling in PDF
        special_blocks = [
            ("[QUICK_GLANCE]", "Quick Glance block"),
            ("[INSIGHT_NOTE]", "Insight Note block"),
            ("[ACTION_BOX", "Action Box block"),
            ("[FOUNDATIONAL_NARRATIVE]", "Foundational Narrative block"),
            ("[TAKEAWAYS]", "Takeaways block"),
            ("[EXERCISE_", "Exercise block"),
            ("[QUOTE]", "Quote block"),
        ]

        # Look in createAttributedString function
        for marker, desc in special_blocks:
            pattern = f'line.hasPrefix\\("{re.escape(marker)}"\\)'
            has_handling = re.search(pattern, content) is not None
            self.add_result("PDF Export", f"Handles {desc}", has_handling,
                          f"PDF rendering for {marker}")

        # Check for dynamic reading time in PDF
        has_reading_time = "calculateReadingTime" in content and "QUICK_GLANCE" in content
        self.add_result("PDF Export", "Has dynamic reading time", has_reading_time,
                       "Dynamic reading time in Quick Glance")

        # Check for brand colors in PDF
        pdf_colors = ["UIColor.iaGold", "UIColor.iaHeading", "UIColor.iaCoral", "UIColor.iaBurgundy"]
        for color in pdf_colors:
            has_color = color in content
            self.add_result("PDF Export", f"Uses {color}", has_color,
                          f"Brand color {color} in PDF")

    def audit_docx_export(self):
        """Audit DOCX export functionality"""
        print("Auditing DOCX Export...")
        content = self.read_file(self.data_manager_path)

        # Check for DOCX generation
        has_docx = "func generateDOCX" in content
        self.add_result("DOCX Export", "Has DOCX generation function", has_docx,
                       "generateDOCX function")

        # Check for custom styles
        docx_styles = [
            ("InsightNote", "Insight Note style"),
            ("ActionBox", "Action Box style"),
            ("QuickGlance", "Quick Glance style"),
            ("Heading1", "Heading 1 style"),
            ("Heading2", "Heading 2 style"),
        ]

        for style, desc in docx_styles:
            has_style = f'styleId="{style}"' in content
            self.add_result("DOCX Export", f"Has {desc}", has_style,
                          f"DOCX style {style}")

        # Check for brand colors in DOCX (check both text color and border colors)
        has_gold = 'w:color w:val="CBA135"' in content or 'w:color="CBA135"' in content
        has_burgundy = 'w:color w:val="582534"' in content or 'w:color="582534"' in content
        self.add_result("DOCX Export", "Has gold brand color", has_gold, "Gold color #CBA135")
        self.add_result("DOCX Export", "Has burgundy brand color", has_burgundy, "Burgundy color #582534")

    def audit_guide_view(self):
        """Audit in-app guide rendering"""
        print("Auditing GuideView...")
        content = self.read_file(self.guide_view_path)

        # Check for special block views
        block_views = [
            ("QuickGlanceBlockView", "Quick Glance view"),
            ("InsightNoteBlockView", "Insight Note view"),
            ("ActionBoxBlockView", "Action Box view"),
            ("FlowchartBlockView", "Flowchart view"),
            ("TableBlockView", "Table view"),
            ("TakeawaysBlockView", "Takeaways view"),
        ]

        for view, desc in block_views:
            has_view = view in content
            self.add_result("GuideView", f"Has {desc}", has_view,
                          f"Block view component {view}")

        # Check for quality score display
        has_quality = "qualityScore" in content
        self.add_result("GuideView", "Has quality score display", has_quality,
                       "Quality score state variable")

        # Check for regenerate functionality
        has_regenerate = "showingRegenerateConfirmation" in content
        self.add_result("GuideView", "Has regenerate confirmation", has_regenerate,
                       "Regenerate confirmation dialog")

        # Check for RegenerateView integration
        has_regenerate_view = "RegenerateView" in content
        self.add_result("GuideView", "Has RegenerateView integration", has_regenerate_view,
                       "RegenerateView sheet/cover")

    def audit_quality_service(self):
        """Audit quality audit service"""
        print("Auditing QualityAuditService...")
        content = self.read_file(self.quality_audit_path)

        if not content:
            self.add_result("Quality Service", "File exists", False,
                          "QualityAuditService.swift not found")
            return

        # Check for required sections
        required_sections = [
            "[QUICK_GLANCE]",
            "[INSIGHT_NOTE]",
            "[ACTION_BOX",
            "[FOUNDATIONAL_NARRATIVE]",
            "[TAKEAWAYS]",
            "[EXERCISE_",
            "[VISUAL_FLOWCHART",
            "[VISUAL_TABLE",
            "[STRUCTURE_MAP]",
        ]

        for section in required_sections:
            has_section = section in content
            self.add_result("Quality Service", f"Checks for {section}", has_section,
                          f"Required section check for {section}")

        # Check for quality checks
        quality_checks = [
            ("word count", "Word count validation"),
            ("heading structure", "Heading structure check"),
            ("properly closed", "Block closure validation"),
        ]

        for check, desc in quality_checks:
            has_check = check.lower() in content.lower()
            self.add_result("Quality Service", f"Has {desc}", has_check,
                          f"Quality check: {check}")

        # Check for 95% threshold
        has_threshold = "95" in content or "passingThreshold" in content
        self.add_result("Quality Service", "Has 95% passing threshold", has_threshold,
                       "95% quality threshold defined")

    def audit_regenerate_view(self):
        """Audit regenerate view functionality"""
        print("Auditing RegenerateView...")
        content = self.read_file(self.regenerate_view_path)

        if not content:
            self.add_result("Regenerate View", "File exists", False,
                          "RegenerateView.swift not found")
            return

        # Check for iteration support
        has_iteration = "iterationCount" in content or "maxIterations" in content
        self.add_result("Regenerate View", "Has iteration support", has_iteration,
                       "Iteration counting for quality improvement")

        # Check for progress display
        has_progress = "ProgressView" in content or "progress" in content.lower()
        self.add_result("Regenerate View", "Has progress display", has_progress,
                       "Visual progress indicator")

        # Check for quality score display
        has_score = "qualityScore" in content or "currentScore" in content
        self.add_result("Regenerate View", "Has quality score display", has_score,
                       "Quality score visualization")

        # Check for audit integration
        has_audit = "QualityAuditService" in content or "auditReport" in content
        self.add_result("Regenerate View", "Has audit integration", has_audit,
                       "QualityAuditService integration")

    def audit_navigation_styling(self):
        """Audit navigation and UI styling"""
        print("Auditing Navigation & Styling...")
        content = self.read_file(self.app_path)

        # Check for navigation bar configuration
        has_nav_config = "UINavigationBarAppearance" in content
        self.add_result("Navigation", "Has navigation bar configuration", has_nav_config,
                       "UINavigationBarAppearance setup")

        # Check for tab bar configuration
        has_tab_config = "UITabBarAppearance" in content
        self.add_result("Navigation", "Has tab bar configuration", has_tab_config,
                       "UITabBarAppearance setup")

        # Check for color application
        has_heading_color = "UIColor.iaHeading" in content
        has_gold_tint = "UIColor.iaGold" in content
        self.add_result("Navigation", "Has heading color applied", has_heading_color,
                       "iaHeading color in navigation")
        self.add_result("Navigation", "Has gold tint applied", has_gold_tint,
                       "iaGold tint color")

    def audit_brand_consistency(self):
        """Audit brand consistency across components"""
        print("Auditing Brand Consistency...")
        style_content = self.read_file(self.style_path)

        # Check for required brand elements
        brand_elements = [
            ("InsightAtlasColors", "Color palette struct"),
            ("InsightAtlasTypography", "Typography struct"),
            ("InsightAtlasBrand", "Brand constants"),
            ("gold = Color(hex: \"#CBA135\")", "Gold color definition"),
            ("burgundy = Color(hex: \"#582534\")", "Burgundy color definition"),
            ("coral = Color(hex: \"#E76F51\")", "Coral color definition"),
        ]

        for element, desc in brand_elements:
            has_element = element in style_content
            self.add_result("Brand Consistency", f"Has {desc}", has_element,
                          f"Brand element: {element}")

        # Check for UIColor extensions
        uicolor_extensions = [
            "static let iaGold",
            "static let iaHeading",
            "static let iaBurgundy",
            "static let iaCoral",
        ]

        for ext in uicolor_extensions:
            has_ext = ext in style_content
            self.add_result("Brand Consistency", f"Has {ext}", has_ext,
                          f"UIColor extension: {ext}")

    def audit_project_hygiene(self):
        """Audit for repository hygiene issues an expert would flag"""
        print("Auditing Project Hygiene...")

        # Check for AppleDouble files within source roots
        apple_double_files = []
        for root in self.source_roots:
            if not root.exists():
                continue
            for path in root.rglob("._*"):
                apple_double_files.append(str(path))
        has_apple_double = len(apple_double_files) == 0
        self.add_result(
            "Project Hygiene",
            "No AppleDouble (._) files in source roots",
            has_apple_double,
            "Remove AppleDouble files: " + (apple_double_files[0] if apple_double_files else "none")
        )

        # Check for duplicate Swift filenames with trailing " 2.swift"
        duplicate_swift = []
        for root in self.source_roots:
            if not root.exists():
                continue
            for path in root.rglob("* 2.swift"):
                duplicate_swift.append(str(path))
        has_duplicates = len(duplicate_swift) == 0
        self.add_result(
            "Project Hygiene",
            "No duplicate Swift files with ' 2.swift' suffix",
            has_duplicates,
            "Remove duplicate Swift files: " + (duplicate_swift[0] if duplicate_swift else "none")
        )

        # Check for TODO/FIXME/HACK markers
        markers = []
        marker_pattern = re.compile(r"\b(TODO|FIXME|HACK)\b")
        for root in self.source_roots:
            if not root.exists():
                continue
            for path in root.rglob("*.swift"):
                try:
                    text = path.read_text(encoding="utf-8")
                except Exception:
                    continue
                if marker_pattern.search(text):
                    markers.append(str(path))
        has_markers = len(markers) == 0
        self.add_result(
            "Project Hygiene",
            "No TODO/FIXME/HACK markers",
            has_markers,
            "Resolve markers in: " + (markers[0] if markers else "none")
        )

        # Ensure test target exists with at least one test file
        test_files = []
        tests_root = self.project_path / "InsightAtlasTests"
        if tests_root.exists():
            test_files = list(tests_root.rglob("*Tests.swift"))
        has_tests = len(test_files) > 0
        self.add_result(
            "Project Hygiene",
            "Has test suite files",
            has_tests,
            "No *Tests.swift files found in InsightAtlasTests"
        )

    def audit_info_plist(self):
        """Audit Info.plist configuration for background tasks"""
        print("Auditing Info.plist...")
        plist_content = self.read_file(self.info_plist_path)
        if not plist_content:
            self.add_result("Info.plist", "Info.plist exists", False, "InsightAtlas/Info.plist not found")
            return

        # BGTaskSchedulerPermittedIdentifiers must include the guide generation identifier
        required_identifier = "com.insightatlas.guide-generation"
        has_bg_identifier = required_identifier in plist_content
        self.add_result(
            "Info.plist",
            "Has BGTaskSchedulerPermittedIdentifiers entry",
            has_bg_identifier,
            f"Missing BGTaskSchedulerPermittedIdentifiers for {required_identifier}"
        )

        # UIBackgroundModes should include processing for BGProcessingTask
        has_processing_mode = "processing" in plist_content and "UIBackgroundModes" in plist_content
        self.add_result(
            "Info.plist",
            "Includes UIBackgroundModes processing",
            has_processing_mode,
            "UIBackgroundModes missing 'processing'"
        )

    def audit_risky_patterns(self):
        """Audit risky coding patterns (force unwraps, force tries)"""
        print("Auditing Risky Patterns...")
        risky_locations = []
        patterns = [
            re.compile(r"URL\\(string:\\s*[^\\)]+\\)!"),
            re.compile(r"try!"),
        ]
        for root in self.source_roots:
            if not root.exists():
                continue
            for path in root.rglob("*.swift"):
                try:
                    text = path.read_text(encoding="utf-8")
                except Exception:
                    continue
                if any(p.search(text) for p in patterns):
                    risky_locations.append(str(path))
        has_risky = len(risky_locations) == 0
        self.add_result(
            "Risky Patterns",
            "No force unwraps or try! in source",
            has_risky,
            "Review risky patterns in: " + (risky_locations[0] if risky_locations else "none"),
            severity="warning"
        )

    def print_results(self):
        """Print audit results summary"""
        print("\n" + "=" * 60)
        print("AUDIT RESULTS")
        print("=" * 60 + "\n")

        # Group by category
        categories = {}
        for result in self.results:
            if result.category not in categories:
                categories[result.category] = []
            categories[result.category].append(result)

        total_checks = len(self.results)
        passed_checks = sum(1 for r in self.results if r.passed)
        failed_checks = total_checks - passed_checks

        # Print by category
        for category, results in categories.items():
            passed = sum(1 for r in results if r.passed)
            total = len(results)
            print(f"\n{category} ({passed}/{total})")
            print("-" * 40)

            for result in results:
                status = "✓" if result.passed else "✗"
                print(f"  {status} {result.check}")
                if not result.passed:
                    print(f"      → {result.message}")

        # Print summary
        score = (passed_checks / total_checks * 100) if total_checks > 0 else 0
        print("\n" + "=" * 60)
        print(f"OVERALL SCORE: {score:.1f}% ({passed_checks}/{total_checks} checks passed)")
        print("=" * 60)

        if failed_checks > 0:
            print(f"\n⚠️  {failed_checks} issues need to be fixed to reach 100%")
            print("\nFAILED CHECKS:")
            for result in self.results:
                if not result.passed:
                    print(f"  • [{result.category}] {result.check}")
                    print(f"    → {result.message}")
        else:
            print("\n✓ All checks passed! Codebase meets 100% quality standards.")

        return score


if __name__ == "__main__":
    project_path = "/Volumes/2 TB/insight-atlas-ios"
    auditor = InsightAtlasAuditor(project_path)
    score = auditor.audit_all()
