import Foundation

/// Contains the Master Template 2026 CSS for HTML exports
/// This ensures consistent styling across all HTML exports matching the InsightAtlas-Master-Template-FINAL.html
struct InsightAtlasHTMLTemplate {

    /// The complete Master Template 2026 Design System CSS
    static let masterTemplateCSS: String = """
        <style>
            /* ═══ INSIGHT ATLAS - MASTER TEMPLATE 2026 ═══ */
            /* Complete Design System with All Unique Elements */

            :root {
                /* Brand Colors */
                --brand-sepia: #54585b;
                --brand-parchment: #e7e3da;
                --brand-ink: #54585b;

                /* Primary Palette - Gold */
                --primary-gold: #C9A227;
                --primary-gold-light: #DCBE5E;
                --primary-gold-dark: #A88A1F;
                --primary-gold-subtle: rgba(201, 162, 39, 0.08);

                /* Secondary Palette (reserved) */
                --accent-burgundy: #54585b;
                --accent-coral: #54585b;
                --accent-coral-text: #54585b;
                --accent-teal: #54585b;
                --accent-teal-text: #54585b;
                --accent-orange: #54585b;
                --accent-orange-text: #54585b;
                --accent-crimson: #B12A2A;
                --primary-gold-text: #8B7318;

                /* Text Colors */
                --text-heading: #54585b;
                --text-body: #54585b;
                --text-muted: #979c9f;
                --text-subtle: #979c9f;
                --text-inverse: #f9f9f9;

                /* Background Colors */
                --bg-primary: #f9f9f9;
                --bg-secondary: #e7e3da;
                --bg-card: #ffffff;
                --bg-cream: #f9f9f9;

                /* Border Colors */
                --border-light: #e7e3da;
                --border-medium: #d4d5d8;

                /* Fonts */
                --font-display: 'SF Pro Text', 'Helvetica Neue', 'Avenir Next', sans-serif;
                --font-ui: 'SF Pro Text', 'Helvetica Neue', 'Avenir Next', sans-serif;
                --font-handwritten: 'SF Pro Text', 'Helvetica Neue', 'Avenir Next', sans-serif;

                /* Spacing */
                --content-width: 720px;
                --radius-lg: 10px;
                --radius-xl: 12px;

                /* Transitions */
                --transition-fast: 0.15s ease;
                --transition-normal: 0.3s ease;
            }

            /* ═══ DARK MODE ═══ */
            @media (prefers-color-scheme: dark) {
                :root {
                    --text-heading: #f9f9f9;
                    --text-body: #e7e3da;
                    --text-muted: #979c9f;
                    --text-subtle: #979c9f;
                    --bg-primary: #1f1f1f;
                    --bg-secondary: #2a2a2a;
                    --bg-card: #242424;
                    --border-light: #3a3a3a;
                    --border-medium: #4a4a4a;
                    --primary-gold: #D4AF37;
                    --primary-gold-text: #D4AF37;
                    --accent-coral: #54585b;
                    --accent-coral-text: #54585b;
                    --accent-teal: #54585b;
                    --accent-teal-text: #54585b;
                    --accent-crimson: #B12A2A;
                }
            }

            @media (prefers-reduced-motion: reduce) {
                *, *::before, *::after {
                    animation-duration: 0.01ms !important;
                    transition-duration: 0.01ms !important;
                }
            }

            *, *::before, *::after { box-sizing: border-box; }

            html {
                font-size: 16px;
                scroll-behavior: smooth;
                -webkit-font-smoothing: antialiased;
            }

            body {
                font-family: var(--font-ui);
                max-width: var(--content-width);
                margin: 0 auto;
                padding: 48px 24px;
                line-height: 1.6;
                font-size: 1rem;
                color: var(--text-body);
                background: var(--bg-primary);
            }

            ::selection {
                background: rgba(201, 162, 39, 0.25);
                color: var(--text-heading);
            }

            /* ═══ TYPOGRAPHY ═══ */
            h1, h2, h3, h4, h5, h6 {
                font-family: var(--font-display);
                font-weight: 600;
                color: var(--text-heading);
                margin-top: 3rem;
                margin-bottom: 1rem;
                line-height: 1.2;
            }

            h1 { font-size: clamp(2rem, 5vw, 2.5rem); font-weight: 700; margin-top: 0; }
            h2 {
                font-size: 1.5rem;
                position: relative;
                padding-bottom: 0.75rem;
            }
            h2::after {
                content: '';
                position: absolute;
                bottom: 0;
                left: 0;
                width: 60px;
                height: 2px;
                background: linear-gradient(90deg, var(--primary-gold), var(--accent-orange));
                border-radius: 9999px;
            }
            h3 { font-size: 1.25rem; }
            h4 { font-size: 1.125rem; font-weight: 500; }
            h5 { font-size: 1rem; font-weight: 500; }
            h6 { font-size: 0.95rem; font-weight: 500; }

            p { margin: 0 0 1.25rem 0; }
            strong { color: var(--text-heading); font-weight: 600; }
            em { font-style: italic; color: var(--text-muted); }

            a {
                color: var(--primary-gold);
                text-decoration: none;
                border-bottom: 1px solid rgba(201, 162, 39, 0.3);
                transition: all var(--transition-fast);
            }

            a:hover {
                color: var(--accent-orange);
                border-bottom-color: var(--accent-orange);
            }

            ul, ol {
                margin: 1.25rem 0;
                padding-left: 2rem;
            }

            li {
                margin-bottom: 0.75rem;
            }

            /* ═══ COVER PAGE ═══ */
            .cover-page {
                min-height: 100vh;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                text-align: center;
                padding: 3rem 2rem;
                margin: -48px -24px 3rem -24px;
                background: linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
                position: relative;
                border-bottom: 3px solid var(--primary-gold);
            }
            .cover-page::before {
                content: '';
                position: absolute;
                top: 24px;
                left: 24px;
                right: 24px;
                bottom: 24px;
                border: 1px solid var(--primary-gold);
                border-radius: 4px;
                pointer-events: none;
            }
            .cover-page::after {
                content: '';
                position: absolute;
                top: 28px;
                left: 28px;
                right: 28px;
                bottom: 28px;
                border: 1px solid rgba(201, 162, 39, 0.3);
                border-radius: 2px;
                pointer-events: none;
            }

            .cover-top-tagline {
                font-family: var(--font-ui);
                font-size: 0.7rem;
                font-weight: 500;
                letter-spacing: 0.25em;
                color: var(--accent-crimson);
                text-transform: uppercase;
                margin-bottom: 0.75rem;
            }

            .cover-divider {
                width: 80px;
                height: 1px;
                background: var(--primary-gold);
                margin: 0 auto 3rem auto;
            }

            .cover-logo {
                width: 180px;
                height: auto;
                margin-bottom: 3rem;
                opacity: 0.95;
            }

            .cover-logo-placeholder {
                font-size: 4rem;
                color: var(--primary-gold);
                margin-bottom: 3rem;
                line-height: 1;
            }

            .cover-title {
                font-family: var(--font-display);
                font-size: clamp(2.5rem, 8vw, 4rem);
                font-weight: 700;
                color: var(--text-heading);
                line-height: 1.1;
                margin: 0 0 1.5rem 0;
                max-width: 600px;
            }

            .cover-by {
                font-family: var(--font-display);
                font-size: 1rem;
                font-style: italic;
                color: var(--text-muted);
                margin-bottom: 0.25rem;
            }

            .cover-author {
                font-family: var(--font-display);
                font-size: 1.5rem;
                font-weight: 500;
                color: var(--text-body);
                margin-bottom: 2rem;
            }

            .cover-small-divider {
                width: 50px;
                height: 1px;
                background: var(--primary-gold);
                margin: 0 auto 3rem auto;
            }

            .cover-brand {
                font-family: var(--font-display);
                font-size: 1.75rem;
                font-weight: 600;
                color: var(--primary-gold);
                margin-bottom: 0.5rem;
            }

            .cover-subtitle {
                font-family: var(--font-ui);
                font-size: 0.65rem;
                font-weight: 500;
                letter-spacing: 0.2em;
                color: var(--text-muted);
                text-transform: uppercase;
            }

            /* Corner decorations */
            .cover-corner {
                position: absolute;
                width: 16px;
                height: 16px;
                border-color: var(--primary-gold);
                border-style: solid;
            }
            .cover-corner.top-left { top: 36px; left: 36px; border-width: 1px 0 0 1px; }
            .cover-corner.top-right { top: 36px; right: 36px; border-width: 1px 1px 0 0; }
            .cover-corner.bottom-left { bottom: 36px; left: 36px; border-width: 0 0 1px 1px; }
            .cover-corner.bottom-right { bottom: 36px; right: 36px; border-width: 0 1px 1px 0; }

            /* ═══ DOCUMENT HEADER ═══ */
            .document-header {
                text-align: center;
                margin-bottom: 4rem;
                padding-bottom: 2.5rem;
                position: relative;
            }

            .document-header::after {
                content: '';
                position: absolute;
                bottom: 0;
                left: 50%;
                transform: translateX(-50%);
                width: 100px;
                height: 2px;
                background: linear-gradient(90deg, transparent, var(--primary-gold), transparent);
            }

            .brand-badge {
                display: inline-flex;
                font-family: var(--font-ui);
                font-size: 0.75rem;
                font-weight: 500;
                letter-spacing: 0.12em;
                color: var(--brand-sepia);
                text-transform: uppercase;
                margin-bottom: 1rem;
                padding: 0.5rem 1.25rem;
                border: 1px solid var(--border-medium);
                border-radius: 9999px;
                background: var(--bg-secondary);
            }

            .document-header h1 {
                font-size: clamp(2.25rem, 7vw, 3.75rem);
                margin: 1rem 0;
                line-height: 1.1;
            }

            .document-header .subtitle {
                font-size: 1.25rem;
                color: var(--text-muted);
                font-style: italic;
                margin-top: 0.5rem;
            }

            .document-header .author {
                font-family: var(--font-ui);
                font-size: 0.875rem;
                color: var(--text-subtle);
                margin-top: 1.25rem;
            }

            /* ═══ QUICK GLANCE ═══ */
            .quick-glance {
                background: var(--bg-card);
                backdrop-filter: blur(20px);
                border: 1px solid rgba(201, 162, 39, 0.15);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
                box-shadow: 0 4px 24px rgba(45, 37, 32, 0.06);
                position: relative;
                overflow: hidden;
            }

            .quick-glance::before {
                content: '';
                position: absolute;
                top: 0;
                left: 0;
                right: 0;
                height: 3px;
                background: linear-gradient(90deg, var(--primary-gold), var(--accent-orange), var(--primary-gold));
            }

            .block-header {
                display: flex;
                align-items: center;
                gap: 0.75rem;
                font-family: var(--font-ui);
                font-weight: 600;
                font-size: 0.875rem;
                letter-spacing: 0.06em;
                text-transform: uppercase;
                margin-bottom: 1.25rem;
                padding-bottom: 1rem;
                border-bottom: 1px solid var(--border-light);
            }

            .quick-glance .block-header { color: var(--primary-gold-dark); }
            .quick-glance .block-header::before { content: '📋'; font-size: 1.125rem; }
            .quick-glance .block-content { margin-top: 0.5rem; }

            /* ═══ INSIGHT NOTE ═══ */
            .insight-note {
                background: linear-gradient(135deg, rgba(212, 115, 92, 0.08) 0%, rgba(232, 155, 90, 0.1) 100%);
                border: 1px solid rgba(212, 115, 92, 0.25);
                border-left: 4px solid var(--accent-coral);
                border-radius: var(--radius-lg);
                padding: 1.5rem 1.5rem 1.5rem 2rem;
                margin: 2rem 0;
            }

            .insight-note .block-header {
                color: var(--accent-coral);
                padding-bottom: 0.75rem;
                border-bottom: none;
            }

            .insight-note .block-header::before { content: '💡'; }

            /* ═══ ACTION BOX ═══ */
            .action-box {
                background: rgba(42, 139, 127, 0.08);
                border: 2px solid rgba(42, 139, 127, 0.25);
                border-radius: var(--radius-xl);
                padding: 1.5rem 2rem;
                margin: 2rem 0;
            }

            .action-box .block-header {
                color: var(--accent-teal);
                border-bottom: 1px solid rgba(42, 139, 127, 0.25);
            }

            .action-box .block-header::before {
                content: '✓';
                font-weight: 700;
                width: 22px;
                height: 22px;
                display: flex;
                align-items: center;
                justify-content: center;
                background: var(--accent-teal);
                color: var(--text-inverse);
                border-radius: 9999px;
                font-size: 0.75rem;
            }

            .action-box ol {
                counter-reset: action-counter;
                list-style: none;
                padding-left: 0;
            }

            .action-box ol li {
                counter-increment: action-counter;
                padding-left: 2.5rem;
                position: relative;
                margin-bottom: 1rem;
            }

            .action-box ol li::before {
                content: counter(action-counter);
                position: absolute;
                left: 0;
                top: 2px;
                width: 26px;
                height: 26px;
                display: flex;
                align-items: center;
                justify-content: center;
                background: linear-gradient(135deg, var(--accent-teal) 0%, #3BA396 100%);
                color: var(--text-inverse);
                font-family: var(--font-ui);
                font-weight: 600;
                font-size: 0.875rem;
                border-radius: 9999px;
            }

            /* ═══ EXERCISE ═══ */
            .exercise {
                background: linear-gradient(135deg, rgba(42, 139, 127, 0.08) 0%, rgba(42, 139, 127, 0.04) 100%);
                border: 2px solid rgba(42, 139, 127, 0.25);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
                position: relative;
            }

            .exercise::before {
                content: '✏️';
                position: absolute;
                top: -15px;
                right: -15px;
                font-size: 70px;
                opacity: 0.06;
                transform: rotate(15deg);
            }

            .exercise .block-header {
                color: var(--accent-teal);
                border-bottom: 1px solid rgba(42, 139, 127, 0.25);
            }

            .exercise .block-header::before { content: '✏️'; font-size: 1.125rem; }

            /* ═══ TAKEAWAYS ═══ */
            .takeaways {
                background: linear-gradient(135deg, rgba(74, 155, 127, 0.1) 0%, rgba(74, 155, 127, 0.04) 100%);
                border: 2px solid rgba(74, 155, 127, 0.3);
                border-radius: var(--radius-xl);
                padding: 2rem;
                margin: 2.5rem 0;
            }

            .takeaways .block-header {
                color: #4A9B7F;
                border-bottom: 1px solid rgba(74, 155, 127, 0.25);
            }

            .takeaways .block-header::before { content: '🎯'; font-size: 1.125rem; }

            /* ═══ QUOTE BLOCK ═══ */
            blockquote {
                background: var(--bg-secondary);
                border-left: 4px solid var(--accent-coral);
                padding: 2rem;
                margin: 2.5rem 0;
                border-radius: var(--radius-lg);
                font-style: italic;
                font-size: 1.25rem;
                line-height: 1.6;
                color: var(--text-heading);
            }

            blockquote::before {
                content: '"';
                font-size: 3rem;
                color: var(--primary-gold);
                opacity: 0.3;
                line-height: 0;
                vertical-align: -0.45em;
                margin-right: 0.25rem;
            }

            /* ═══ SECTION DIVIDER ═══ */
            .section-divider {
                border: none;
                text-align: center;
                margin: 3rem 0;
                padding: 2rem 0;
                position: relative;
            }

            .section-divider::before {
                content: '✦';
                color: var(--primary-gold);
                font-size: 1.5rem;
                display: block;
            }

            .section-divider-ornament {
                border: none;
                text-align: center;
                margin: 3rem 0;
                padding: 1.5rem 0;
            }

            .section-divider-ornament::before {
                content: '✦ ✦ ✦';
                color: var(--primary-gold);
                letter-spacing: 0.5rem;
                display: block;
                font-size: 1rem;
            }

            /* ═══ FOOTER ═══ */
            .document-footer {
                text-align: center;
                margin-top: 4rem;
                padding-top: 2.5rem;
                border-top: 1px solid var(--border-light);
                font-family: var(--font-ui);
                font-size: 0.875rem;
                color: var(--text-subtle);
            }

            .brand-footer {
                font-weight: 600;
                color: var(--brand-sepia);
                letter-spacing: 0.06em;
                margin-bottom: 1rem;
            }

            .tagline-footer {
                font-family: var(--font-handwritten);
                font-size: 1.125rem;
                color: var(--accent-crimson);
                margin-top: 0.5rem;
            }

            .footer-logo {
                width: 80px;
                height: auto;
                margin-bottom: 0.75rem;
                opacity: 0.7;
            }

            /* ═══ RESPONSIVE ═══ */
            @media (max-width: 640px) {
                html { font-size: 16px; }
                body { padding: 1.5rem 1rem; }
                .document-header h1 { font-size: 2.25rem; }
                .quick-glance, .insight-note, .action-box, .exercise,
                .takeaways { padding: 1.25rem; }
            }

            /* ═══ PRINT STYLES ═══ */
            @media print {
                body {
                    background: white;
                    color: black;
                    font-size: 11pt;
                    max-width: 100%;
                    padding: 0;
                }
                .cover-page {
                    min-height: auto;
                    page-break-after: always;
                    margin: 0;
                    padding: 2rem;
                    border: 1px solid #C9A227;
                    background: white;
                }
                .cover-page::before, .cover-page::after { display: none; }
                .cover-corner { display: none; }
                .document-header, .quick-glance, .insight-note, .action-box,
                .exercise, .takeaways {
                    break-inside: avoid;
                    box-shadow: none;
                }
                a::after {
                    content: ' (' attr(href) ')';
                    font-size: 0.8em;
                    color: #666;
                }
            }
        </style>
        """
}
