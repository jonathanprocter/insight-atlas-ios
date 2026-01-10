# Quick Reference Card - iOS Fixes

## The Three Main Issues & Solutions

### 🔴 Issue 1: Thick Black Horizontal Lines
**Problem:** Section dividers render as thick black bars instead of elegant diamond ornaments (◆ ◇ ◆)

**Root Cause:** CSS pseudo-elements (`::before`) not rendering properly in iOS WebView

**Solution:**
```css
.section-divider-ornament::before {
    content: '◆ ◇ ◆' !important;
    display: block !important;
    font-size: 14px !important;
    color: #C9A227 !important;
    text-align: center !important;
    font-family: -apple-system, Arial, sans-serif !important;
}
```

---

### 🔴 Issue 2: Text Truncation in Lists
**Problem:** First letters cut off in numbered lists (e.g., "nstead of:" instead of "instead of:")

**Root Cause:** Insufficient padding with custom CSS counters

**Solution:**
```css
.action-box ol li {
    padding-left: 3rem !important; /* Increased from 2.5rem */
    overflow: visible !important;
}

ol li {
    padding-left: 2rem !important; /* Increased from 1.5rem */
}
```

---

### 🔴 Issue 3: Broken Note Box Layout
**Problem:** Vertical bars (|) appearing in INSIGHT ATLAS NOTE boxes

**Root Cause:** CSS column layout breaking or table structure issues

**Solution:**
```css
.insight-note {
    display: block !important;
    width: 100% !important;
    box-sizing: border-box !important;
}

.insight-note .block-content {
    column-count: 1 !important;
    -webkit-column-count: 1 !important;
    display: block !important;
}
```

---

## Implementation Cheat Sheet

### Option A: CSS Only (5 minutes)
```html
<!-- Add to <head> after main stylesheet -->
<link rel="stylesheet" href="ios_fixes.css">
```

### Option B: Swift Class (10 minutes)
```swift
// Replace WKWebView with InsightAtlasWebView
var webView: InsightAtlasWebView!

// Use this method instead of loadHTMLString
webView.loadInsightAtlasContent(htmlContent, baseURL: baseURL)
```

### Option C: Both (Best)
Use both CSS file AND Swift class for maximum compatibility.

---

## Brand Colors Reference

```css
:root {
    /* Primary */
    --primary-gold: #C9A227;
    --accent-coral: #E07A5F;
    --accent-teal: #2A9D8F;
    
    /* Text */
    --text-sepia: #3D3229;
    --text-brown: #6B5B4F;
    
    /* Background */
    --bg-cream: #FAF9F7;
    --bg-warm: #FDF8F3;
    --bg-white: #FFFFFF;
}
```

---

## Font Stack

```css
/* Display/Body */
font-family: 'Cormorant Garamond', Georgia, serif;

/* UI/Headers */
font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;

/* Handwritten */
font-family: 'Caveat', cursive;
```

---

## Common CSS Fixes

### Force Hardware Acceleration
```css
.content-box {
    -webkit-transform: translateZ(0);
    transform: translateZ(0);
}
```

### Improve Font Rendering
```css
body {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}
```

### Prevent Border Issues
```css
* {
    -webkit-box-sizing: border-box;
    box-sizing: border-box;
}
```

---

## Swift Code Snippets

### Load HTML with Fixes
```swift
webView.loadInsightAtlasContent(htmlContent, baseURL: baseURL)
```

### Export as PDF
```swift
webView.exportAsPDF { pdfData in
    guard let data = pdfData else { return }
    // Save or share PDF
}
```

### Export as HTML
```swift
webView.exportAsHTML { htmlContent in
    guard let html = htmlContent else { return }
    // Save or share HTML
}
```

---

## Testing Checklist

- [ ] Diamond ornaments visible (not black lines)
- [ ] List text not truncated
- [ ] No vertical bars in note boxes
- [ ] Fonts load correctly
- [ ] Colors match brand guide
- [ ] Export functions work
- [ ] Tested on iPad
- [ ] Tested on iPhone
- [ ] Tested in light mode
- [ ] Tested in dark mode

---

## File Structure

```
YourProject/
├── Resources/
│   ├── ios_fixes.css          ← Add this
│   ├── main.css
│   └── guide.html
├── ViewControllers/
│   └── GuideViewController.swift
└── Views/
    └── InsightAtlasWebView.swift  ← Add this
```

---

## Troubleshooting Quick Fixes

| Problem | Quick Fix |
|---------|-----------|
| Still seeing thick lines | Add `!important` to CSS rules |
| Text still truncated | Increase `padding-left` to `3.5rem` |
| Fonts not loading | Use web fonts from Google Fonts |
| Boxes broken | Add `display: block !important` |
| Export not working | Check iOS version (requires 14+) |

---

## Contact & Resources

**Files Provided:**
- `ios_fixes.css` - Complete CSS fixes
- `InsightAtlasWebView.swift` - Swift WebView class
- `IMPLEMENTATION_GUIDE.md` - Full documentation
- `QUICK_REFERENCE.md` - This file

**Recommended Reading:**
- Full implementation guide for detailed instructions
- Inline code comments for understanding each fix
- Troubleshooting section for common issues

---

## One-Line Summary

**Add `ios_fixes.css` to your HTML and replace `WKWebView` with `InsightAtlasWebView` in Swift.**

That's it! 🎉
