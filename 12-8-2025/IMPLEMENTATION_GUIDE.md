# iOS Implementation Guide - Insight Atlas 2026 Edition
## Fixing Rendering Issues on iPad/iPhone

---

## Overview

This guide provides step-by-step instructions for implementing the fixes to resolve rendering issues in your Insight Atlas iOS application. The fixes address three main problems:

1. **Thick black horizontal lines** instead of elegant diamond ornaments
2. **Text truncation** at the beginning of numbered list items
3. **Broken layout** in INSIGHT ATLAS NOTE boxes with visible vertical bars

---

## Files Provided

### 1. `ios_fixes.css`
Complete CSS stylesheet with iOS WebView-specific fixes. This file contains 12 major fix categories addressing all identified rendering issues.

### 2. `InsightAtlasWebView.swift`
Swift implementation of a custom WKWebView subclass that automatically applies iOS fixes and provides export functionality.

### 3. `IMPLEMENTATION_GUIDE.md` (this file)
Comprehensive implementation instructions.

---

## Implementation Methods

You have **three options** for implementing these fixes, depending on your current application architecture:

### **Option A: CSS-Only Fix (Simplest)**
If you already have HTML/CSS rendering in your app, simply add the CSS fixes.

### **Option B: Swift WebView Class (Recommended)**
Use the provided `InsightAtlasWebView` class for automatic fix injection.

### **Option C: Hybrid Approach**
Combine both CSS and Swift fixes for maximum compatibility.

---

## Option A: CSS-Only Implementation

### Step 1: Add CSS File to Xcode Project

1. Open your Xcode project
2. Right-click on your project navigator
3. Select **Add Files to "[Your Project Name]"**
4. Add `ios_fixes.css` to your project
5. Ensure **"Copy items if needed"** is checked
6. Select your target in **"Add to targets"**

### Step 2: Link CSS in Your HTML

Add this line in the `<head>` section of your HTML file, **after** your main stylesheet:

```html
<link rel="stylesheet" href="ios_fixes.css">
```

**Example:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Insight Atlas Guide</title>
    
    <!-- Your main stylesheet -->
    <link rel="stylesheet" href="main.css">
    
    <!-- iOS fixes - MUST come after main stylesheet -->
    <link rel="stylesheet" href="ios_fixes.css">
</head>
<body>
    <!-- Your content -->
</body>
</html>
```

### Step 3: Update HTML for Section Dividers

Replace any `<hr>` tags used for section dividers with this structure:

**Before:**
```html
<hr class="section-divider-ornament">
```

**After:**
```html
<div class="section-divider-ornament"></div>
```

The CSS `::before` pseudo-element will automatically add the diamond ornaments (◆ ◇ ◆).

### Step 4: Test on Device

1. Build and run your app on an iPad or iPhone
2. Navigate to a page with section dividers
3. Verify diamond ornaments appear instead of thick black lines
4. Check numbered lists for proper text alignment
5. Verify INSIGHT ATLAS NOTE boxes render correctly

---

## Option B: Swift WebView Implementation (Recommended)

### Step 1: Add Swift File to Project

1. Open your Xcode project
2. Right-click on your project navigator
3. Select **New File** → **Swift File**
4. Name it `InsightAtlasWebView.swift`
5. Copy the contents from the provided file

### Step 2: Replace Existing WebView

In your View Controller where you currently use `WKWebView`:

**Before:**
```swift
import WebKit

class MyViewController: UIViewController {
    var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: view.bounds, configuration: config)
        view.addSubview(webView)
        
        // Load HTML
        if let htmlPath = Bundle.main.path(forResource: "guide", ofType: "html"),
           let htmlContent = try? String(contentsOfFile: htmlPath) {
            webView.loadHTMLString(htmlContent, baseURL: nil)
        }
    }
}
```

**After:**
```swift
import WebKit

class MyViewController: UIViewController {
    var webView: InsightAtlasWebView! // Changed type
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let config = WKWebViewConfiguration()
        webView = InsightAtlasWebView(frame: view.bounds, configuration: config) // Changed class
        view.addSubview(webView)
        
        // Load HTML with automatic fixes
        if let htmlPath = Bundle.main.path(forResource: "guide", ofType: "html"),
           let htmlContent = try? String(contentsOfFile: htmlPath) {
            webView.loadInsightAtlasContent(htmlContent, baseURL: URL(fileURLWithPath: htmlPath)) // Changed method
        }
    }
}
```

### Step 3: Add Export Functionality (Optional)

Add buttons to your UI for exporting:

```swift
// Add to your View Controller

@IBAction func exportPDF(_ sender: UIButton) {
    webView.exportAsPDF { pdfData in
        guard let data = pdfData else { return }
        
        // Save to Files app
        let fileName = "InsightAtlas-\(Date().timeIntervalSince1970).pdf"
        self.savePDF(data: data, fileName: fileName)
    }
}

@IBAction func exportHTML(_ sender: UIButton) {
    webView.exportAsHTML { htmlContent in
        guard let html = htmlContent else { return }
        
        // Save or share HTML
        let fileName = "InsightAtlas-\(Date().timeIntervalSince1970).html"
        self.saveHTML(content: html, fileName: fileName)
    }
}

private func savePDF(data: Data, fileName: String) {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let pdfPath = documentsPath.appendingPathComponent(fileName)
    
    do {
        try data.write(to: pdfPath)
        
        // Share using activity view controller
        let activityVC = UIActivityViewController(activityItems: [pdfPath], applicationActivities: nil)
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(activityVC, animated: true)
    } catch {
        print("Error saving PDF: \(error)")
    }
}

private func saveHTML(content: String, fileName: String) {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let htmlPath = documentsPath.appendingPathComponent(fileName)
    
    do {
        try content.write(to: htmlPath, atomically: true, encoding: .utf8)
        
        // Share using activity view controller
        let activityVC = UIActivityViewController(activityItems: [htmlPath], applicationActivities: nil)
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(activityVC, animated: true)
    } catch {
        print("Error saving HTML: \(error)")
    }
}
```

### Step 4: Update Storyboard/XIB (If Using Interface Builder)

1. Open your Storyboard or XIB file
2. Select your WKWebView
3. In the **Identity Inspector** (right panel), change the **Class** to `InsightAtlasWebView`
4. Ensure the **Module** is set to your app's module name

---

## Option C: Hybrid Implementation

For maximum compatibility, use both approaches:

1. **Add CSS file** to your project (Option A)
2. **Use Swift WebView class** (Option B)
3. The Swift class will inject additional fixes, and the CSS file provides fallbacks

This ensures fixes are applied even if JavaScript injection fails.

---

## Testing Checklist

After implementation, test the following on **both iPad and iPhone**:

### ✅ Section Dividers
- [ ] Diamond ornaments (◆ ◇ ◆) appear in gold color
- [ ] No thick black horizontal lines
- [ ] Proper spacing above and below dividers

### ✅ Numbered Lists
- [ ] All text is visible (no truncation at beginning)
- [ ] Numbers are properly aligned in circles
- [ ] Adequate spacing between number and text
- [ ] Text wraps properly on multiple lines

### ✅ Content Boxes
- [ ] QUICK GLANCE box renders with gold gradient header
- [ ] INSIGHT ATLAS NOTE box has coral left border
- [ ] APPLY IT box has teal header
- [ ] KEY TAKEAWAYS box has gold background
- [ ] No vertical bars (|) visible in content
- [ ] Proper padding and spacing

### ✅ Typography
- [ ] Cormorant Garamond font loads for body text
- [ ] Inter font loads for headers
- [ ] Text is smooth and readable (antialiased)
- [ ] Proper line height (1.75 for body text)

### ✅ Export Functions (If Implemented)
- [ ] PDF export maintains formatting
- [ ] HTML export preserves all styles
- [ ] Share sheet appears correctly on iPad

---

## Troubleshooting

### Problem: Diamond ornaments still appear as thick black lines

**Solution 1:** Ensure CSS file is loaded **after** main stylesheet

**Solution 2:** Add `!important` to the CSS rules:
```css
.section-divider-ornament::before {
    content: '◆ ◇ ◆' !important;
    display: block !important;
    color: #C9A227 !important;
}
```

**Solution 3:** Use HTML content instead of CSS:
```html
<div class="section-divider-ornament" style="text-align: center; color: #C9A227; font-size: 14px; letter-spacing: 0.5em; margin: 3rem 0;">
    ◆ ◇ ◆
</div>
```

### Problem: Text still truncated in lists

**Solution:** Increase padding in CSS:
```css
.action-box ol li {
    padding-left: 3.5rem !important; /* Increase if needed */
}
```

### Problem: Fonts not loading

**Solution 1:** Check if fonts are included in your app bundle

**Solution 2:** Add font files to Xcode:
1. Add `.ttf` or `.otf` font files to project
2. Add to **Info.plist**:
```xml
<key>UIAppFonts</key>
<array>
    <string>CormorantGaramond-Regular.ttf</string>
    <string>CormorantGaramond-Bold.ttf</string>
    <string>Inter-Regular.ttf</string>
    <string>Inter-SemiBold.ttf</string>
    <string>Caveat-Regular.ttf</string>
</array>
```

**Solution 3:** Use web fonts:
```html
<head>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;700&family=Inter:wght@400;600&family=Caveat&display=swap" rel="stylesheet">
</head>
```

### Problem: Boxes have broken layout

**Solution:** Add explicit width and display properties:
```css
.insight-note,
.quick-glance,
.action-box {
    display: block !important;
    width: 100% !important;
    box-sizing: border-box !important;
}
```

### Problem: Export not working

**Solution 1:** Check iOS version compatibility:
```swift
if #available(iOS 14.0, *) {
    webView.createPDF(configuration: config) { result in
        // Handle result
    }
} else {
    // Fallback for older iOS versions
    print("PDF export requires iOS 14+")
}
```

**Solution 2:** Ensure WebView has finished loading:
```swift
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    // Now safe to export
    exportPDF()
}
```

---

## Claude Code Local Integration

If you're using **Claude Code Local** with **Xcode**:

### Step 1: Open Project in Claude Code Local

```bash
cd /path/to/your/ios/project
claude-code .
```

### Step 2: Use Claude to Integrate Files

Ask Claude:
```
Please integrate the InsightAtlasWebView.swift file into my Xcode project 
and update my view controller to use it.
```

### Step 3: Build and Test

Claude can help you:
- Add files to correct targets
- Update build settings
- Fix compilation errors
- Add export buttons to UI

---

## Additional Customization

### Adjust Colors

Edit the CSS variables in `ios_fixes.css`:

```css
:root {
    --primary-gold: #C9A227;      /* Change gold color */
    --accent-coral: #E07A5F;      /* Change coral color */
    --accent-teal: #2A9D8F;       /* Change teal color */
    --text-sepia: #3D3229;        /* Change text color */
    --bg-cream: #FAF9F7;          /* Change background */
}
```

### Adjust Spacing

Modify padding and margins:

```css
.action-box ol li {
    padding-left: 3rem;           /* Adjust list padding */
    margin-bottom: 1rem;          /* Adjust spacing between items */
}

.section-divider-ornament {
    margin: 3rem 0;               /* Adjust divider spacing */
}
```

### Change Diamond Ornaments

Replace with different symbols:

```css
.section-divider-ornament::before {
    content: '✦ ✧ ✦';           /* Stars */
    /* OR */
    content: '● ○ ●';            /* Circles */
    /* OR */
    content: '━━━';              /* Lines */
}
```

---

## Support

If you encounter issues not covered in this guide:

1. **Check Console Logs:** Look for JavaScript errors in Xcode console
2. **Verify File Paths:** Ensure all CSS/HTML files are in correct locations
3. **Test on Simulator:** Compare behavior between simulator and device
4. **Check iOS Version:** Some features require iOS 13+ or iOS 14+

---

## Summary

**Quick Start:**
1. Add `ios_fixes.css` to your Xcode project
2. Link it in your HTML: `<link rel="stylesheet" href="ios_fixes.css">`
3. Replace `WKWebView` with `InsightAtlasWebView` in your Swift code
4. Use `loadInsightAtlasContent()` instead of `loadHTMLString()`
5. Build and test on device

**Result:**
- ✅ Elegant diamond ornaments instead of thick black lines
- ✅ Properly aligned text in numbered lists
- ✅ Clean, professional rendering of all content boxes
- ✅ Consistent with Insight Atlas 2026 Edition branding

---

**Questions?** Review the troubleshooting section or examine the inline comments in the provided code files.
