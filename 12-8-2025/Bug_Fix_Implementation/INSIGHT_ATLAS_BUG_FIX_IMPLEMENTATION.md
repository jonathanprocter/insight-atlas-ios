# INSIGHT ATLAS APPLICATION - COMPLETE BUG FIX IMPLEMENTATION GUIDE

## INSTRUCTIONS FOR CLAUDE CODE

You are tasked with fixing the Insight Atlas application. This document contains ALL known bugs affecting:
1. In-app content rendering
2. PDF export
3. DOCX export (currently non-functional - does not load after export)
4. HTML export

Read this entire document before making any changes. Implement fixes systematically in the order presented.

---

# PART 1: APPLICATION OVERVIEW

## What This Application Does
- Generates comprehensive analysis guides from book content
- Renders formatted content with special components (note boxes, flow diagrams, tables, exercises)
- Exports to multiple formats: PDF, DOCX, HTML

## Current State
- PDF export: Partially working but with significant rendering failures
- DOCX export: COMPLETELY BROKEN - files do not open after export
- HTML export: Has similar issues to PDF
- In-app rendering: Unknown state but likely has same markdown parsing issues

---

# PART 2: CRITICAL BUGS - MARKDOWN PARSING FAILURES

## BUG-001: Bold Text Not Rendering

### Symptoms
The markdown bold syntax `**text**` appears as literal asterisks instead of bold formatted text.

### Affected Locations (Examples from PDF export)
```
Page 3: "** True relationship success comes from..."
Page 3: "Core Framework Overview:**"
Page 3: "Main Concepts:**"
Page 3: "The Bottom Line:**"
Page 6: "★ 1. Self-Love Precedes All Other Love**"
Page 10: "1. Reflection:**"
Page 15: "1. Practice Dialogue: Addressing Concerns Without Attacking**"
Page 19: "1. Self-Assessment: Expectation Audit**"
Page 23: "1. Pattern Interrupt: Destructive Conflict Behaviors**"
Page 30: "1. Self-Assessment: Love Practice Audit**"
```

### Root Cause
The markdown parser is either:
1. Not processing bold syntax at all
2. Processing it AFTER text has been escaped/encoded
3. Using incorrect regex pattern

### REQUIRED FIX

Find the markdown processing function(s) in your codebase. Look for files named:
- `markdownParser.js` or `markdownParser.ts`
- `parseMarkdown.swift`
- `MarkdownProcessor.swift`
- `contentProcessor.js`
- `textFormatter.js`
- Any file containing "markdown" or "parse" or "format"

Implement or fix the bold text processing:

```javascript
// JAVASCRIPT/TYPESCRIPT IMPLEMENTATION
function processBoldMarkdown(text) {
    if (!text || typeof text !== 'string') return text;
    
    // Pattern: **text** becomes <strong>text</strong>
    // Must handle multi-word content and special characters
    const boldPattern = /\*\*([^*]+)\*\*/g;
    
    return text.replace(boldPattern, '<strong>$1</strong>');
}

// Alternative for PDF libraries that use different markup:
function processBoldForPDF(text) {
    if (!text || typeof text !== 'string') return text;
    
    const boldPattern = /\*\*([^*]+)\*\*/g;
    
    // Return object with styling information
    return text.replace(boldPattern, (match, content) => {
        return `{{BOLD_START}}${content}{{BOLD_END}}`;
    });
}
```

```swift
// SWIFT IMPLEMENTATION
func processBoldMarkdown(_ text: String) -> NSAttributedString {
    let pattern = "\\*\\*([^*]+)\\*\\*"
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    
    let attributedString = NSMutableAttributedString(string: text)
    let range = NSRange(text.startIndex..., in: text)
    
    let matches = regex.matches(in: text, options: [], range: range)
    
    // Process in reverse to maintain correct indices
    for match in matches.reversed() {
        if let contentRange = Range(match.range(at: 1), in: text) {
            let boldContent = String(text[contentRange])
            let boldAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16)
            ]
            let boldString = NSAttributedString(string: boldContent, attributes: boldAttributes)
            
            if let fullRange = Range(match.range, in: text) {
                let nsRange = NSRange(fullRange, in: text)
                attributedString.replaceCharacters(in: nsRange, with: boldString)
            }
        }
    }
    
    return attributedString
}
```

### PROCESSING ORDER IS CRITICAL

The markdown processing MUST happen in this order:
1. Process code blocks first (to protect their content)
2. Process bold text (`**text**`)
3. Process italic text (`*text*`)
4. Process links
5. Process other inline elements
6. Convert to final output format

---

## BUG-002: First Character Truncation

### Symptoms
The first letter of certain words is being stripped/removed.

### Affected Locations (Examples from PDF export)
```
"• ead time: 2 minutes" → Should be "• Read time: 2 minutes"
"2. stimated time: 15 minutes" → Should be "2. Estimated time: 15 minutes"
"2. nstead of saying:" → Should be "2. Instead of saying:"
"3. ry:" → Should be "3. Try:"
"7. coring: 40-50:" → Should be "7. Scoring: 40-50:"
```

### Root Cause
The italic processing regex is capturing and removing the first character. This happens when:
- Pattern incorrectly matches single asterisk followed by a character
- Pattern: `/\*(\w)/g` would match `*R` and capture just `R`, then replacement removes it

### REQUIRED FIX

Find and fix the italic text processing:

```javascript
// BROKEN CODE (likely what exists now):
function processItalicsBROKEN(text) {
    // This pattern is WRONG - it captures single chars after asterisk
    return text.replace(/\*(\w)/g, '<em>$1</em>');
}

// FIXED CODE:
function processItalicsFixed(text) {
    if (!text || typeof text !== 'string') return text;
    
    // Correct pattern: single asterisk, content, single asterisk
    // Must NOT match double asterisks (those are bold)
    // Use negative lookbehind and lookahead to avoid ** matches
    
    // First, temporarily replace ** with placeholder
    let processed = text.replace(/\*\*/g, '{{DOUBLE_ASTERISK}}');
    
    // Now process single asterisks for italics
    processed = processed.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    
    // Restore double asterisks
    processed = processed.replace(/{{DOUBLE_ASTERISK}}/g, '**');
    
    return processed;
}
```

```swift
// SWIFT IMPLEMENTATION
func processItalicsFixed(_ text: String) -> String {
    var processed = text
    
    // Protect double asterisks first
    processed = processed.replacingOccurrences(of: "**", with: "{{DOUBLE_ASTERISK}}")
    
    // Process single asterisk italics
    let pattern = "\\*([^*]+)\\*"
    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
        let range = NSRange(processed.startIndex..., in: processed)
        processed = regex.stringByReplacingMatches(
            in: processed,
            options: [],
            range: range,
            withTemplate: "<em>$1</em>"
        )
    }
    
    // Restore double asterisks
    processed = processed.replacingOccurrences(of: "{{DOUBLE_ASTERISK}}", with: "**")
    
    return processed
}
```

### VERIFICATION TEST
After implementing fix, verify:
```
Input: "• Read time: 2 minutes"
Output: "• Read time: 2 minutes" (unchanged, no asterisks present)

Input: "*Estimated* time: 15 minutes"
Output: "<em>Estimated</em> time: 15 minutes"

Input: "**Bold** and *italic* text"
Output: "<strong>Bold</strong> and <em>italic</em> text"
```

---

## BUG-003: Markdown Tables Not Rendering

### Symptoms
Tables appear as raw markdown syntax with visible pipes and dashes instead of formatted tables.

### Example of Current (Broken) Output
```
Weekly Presence Practice Tracker | Day | Situation | Quality of Attention (1-10) | What I 
Noticed | |-----|-----------|----------------------------|------------------| | Mon | |
| | Tue | | | | Wed | | | |
```

### Expected Output
A properly formatted table with:
- Visible borders/gridlines
- Header row styling
- Proper column alignment
- Cell padding

### REQUIRED FIX

Implement table parsing and conversion:

```javascript
// JAVASCRIPT TABLE PARSER
function parseMarkdownTable(text) {
    // Detect table pattern
    const tablePattern = /\|(.+)\|\n\|([-:| ]+)\|\n((?:\|.+\|\n?)+)/g;
    
    return text.replace(tablePattern, (match, headerRow, separator, bodyRows) => {
        // Parse header
        const headers = headerRow.split('|').map(h => h.trim()).filter(h => h);
        
        // Parse alignment from separator
        const alignments = separator.split('|').map(s => {
            s = s.trim();
            if (s.startsWith(':') && s.endsWith(':')) return 'center';
            if (s.endsWith(':')) return 'right';
            return 'left';
        }).filter(a => a);
        
        // Parse body rows
        const rows = bodyRows.trim().split('\n').map(row => {
            return row.split('|').map(cell => cell.trim()).filter(cell => cell !== '');
        });
        
        // Build HTML table
        let html = '<table class="markdown-table">\n';
        html += '  <thead>\n    <tr>\n';
        headers.forEach((header, i) => {
            const align = alignments[i] || 'left';
            html += `      <th style="text-align: ${align}">${header}</th>\n`;
        });
        html += '    </tr>\n  </thead>\n';
        
        html += '  <tbody>\n';
        rows.forEach(row => {
            html += '    <tr>\n';
            row.forEach((cell, i) => {
                const align = alignments[i] || 'left';
                html += `      <td style="text-align: ${align}">${cell}</td>\n`;
            });
            html += '    </tr>\n';
        });
        html += '  </tbody>\n</table>';
        
        return html;
    });
}
```

```swift
// SWIFT TABLE PARSER
func parseMarkdownTable(_ text: String) -> String {
    let tablePattern = "\\|(.+)\\|\\n\\|([-:| ]+)\\|\\n((?:\\|.+\\|\\n?)+)"
    
    guard let regex = try? NSRegularExpression(pattern: tablePattern, options: []) else {
        return text
    }
    
    var result = text
    let range = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, options: [], range: range)
    
    for match in matches.reversed() {
        guard let headerRange = Range(match.range(at: 1), in: text),
              let separatorRange = Range(match.range(at: 2), in: text),
              let bodyRange = Range(match.range(at: 3), in: text) else {
            continue
        }
        
        let headerRow = String(text[headerRange])
        let separator = String(text[separatorRange])
        let bodyRows = String(text[bodyRange])
        
        let headers = headerRow.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        
        var html = "<table class=\"markdown-table\">\n<thead>\n<tr>\n"
        for header in headers where !header.isEmpty {
            html += "<th>\(header)</th>\n"
        }
        html += "</tr>\n</thead>\n<tbody>\n"
        
        let rows = bodyRows.split(separator: "\n")
        for row in rows {
            html += "<tr>\n"
            let cells = row.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            for cell in cells where !cell.isEmpty {
                html += "<td>\(cell)</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</tbody>\n</table>"
        
        if let fullRange = Range(match.range, in: result) {
            result.replaceSubrange(fullRange, with: html)
        }
    }
    
    return result
}
```

### REQUIRED CSS FOR TABLES
```css
.markdown-table {
    width: 100%;
    border-collapse: collapse;
    margin: 16px 0;
    font-size: 14px;
}

.markdown-table th,
.markdown-table td {
    border: 1px solid #ddd;
    padding: 10px 12px;
    text-align: left;
}

.markdown-table th {
    background-color: #f5f5f5;
    font-weight: 600;
    color: #333;
}

.markdown-table tr:nth-child(even) {
    background-color: #fafafa;
}

.markdown-table tr:hover {
    background-color: #f0f0f0;
}
```

---

# PART 3: CRITICAL BUGS - COMPONENT RENDERING FAILURES

## BUG-004: Insight Atlas Note Boxes Showing ASCII Art

### Symptoms
Note boxes display visible ASCII box-drawing characters instead of CSS-styled containers.

### Example of Current (Broken) Output
```
┌─────────────────────────────────
────────────────────────────────┐
│ INSIGHT ATLAS NOTE │
├─────────────────────────────────
────────────────────────────────┤
│ │ │ This concept parallels Brené Brown's 
research on vulnerability │ │ and Carl Jung's work...
```

### Expected Output
A styled box with:
- CSS border (no ASCII characters)
- Background color
- Proper padding
- Word wrapping that respects word boundaries

### Root Cause
The application is either:
1. Using ASCII art as a fallback when CSS fails
2. Not applying CSS styles during export
3. Treating the content as preformatted text

### REQUIRED FIX

#### Step 1: Create Note Box Component

```javascript
// JAVASCRIPT - Note Box Generator
function createInsightAtlasNote(content) {
    // Parse the content sections
    const sections = parseNoteSections(content);
    
    let html = `
    <div class="insight-atlas-note">
        <div class="note-header">
            <span class="note-icon">💡</span>
            <span class="note-title">INSIGHT ATLAS NOTE</span>
        </div>
        <div class="note-body">
    `;
    
    if (sections.mainContent) {
        html += `<p class="note-main">${sections.mainContent}</p>`;
    }
    
    if (sections.keyDistinction) {
        html += `
        <div class="note-section">
            <strong>Key Distinction:</strong> ${sections.keyDistinction}
        </div>`;
    }
    
    if (sections.practicalImplication) {
        html += `
        <div class="note-section">
            <strong>Practical Implication:</strong> ${sections.practicalImplication}
        </div>`;
    }
    
    if (sections.goDeeper) {
        html += `
        <div class="note-section note-deeper">
            <strong>Go Deeper:</strong> ${sections.goDeeper}
        </div>`;
    }
    
    html += `
        </div>
    </div>`;
    
    return html;
}

function parseNoteSections(content) {
    const sections = {
        mainContent: '',
        keyDistinction: '',
        practicalImplication: '',
        goDeeper: ''
    };
    
    // Extract Key Distinction
    const kdMatch = content.match(/Key Distinction:\s*([^│]+?)(?=Practical|Go Deeper|$)/is);
    if (kdMatch) sections.keyDistinction = kdMatch[1].trim();
    
    // Extract Practical Implication
    const piMatch = content.match(/Practical Implication:\s*([^│]+?)(?=Go Deeper|$)/is);
    if (piMatch) sections.practicalImplication = piMatch[1].trim();
    
    // Extract Go Deeper
    const gdMatch = content.match(/Go Deeper:\s*([^│]+?)$/is);
    if (gdMatch) sections.goDeeper = gdMatch[1].trim();
    
    // Main content is everything before the first section
    const mainMatch = content.match(/^([^│]+?)(?=Key Distinction|Practical|Go Deeper)/is);
    if (mainMatch) sections.mainContent = mainMatch[1].trim();
    
    return sections;
}
```

#### Step 2: CSS for Note Boxes

```css
.insight-atlas-note {
    border: 2px solid #C9A227;
    border-radius: 8px;
    margin: 20px 0;
    background-color: #FFFDF5;
    overflow: hidden;
}

.insight-atlas-note .note-header {
    background-color: #C9A227;
    color: white;
    padding: 12px 16px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.insight-atlas-note .note-icon {
    font-size: 20px;
}

.insight-atlas-note .note-title {
    font-weight: 700;
    font-size: 14px;
    letter-spacing: 0.5px;
}

.insight-atlas-note .note-body {
    padding: 16px;
}

.insight-atlas-note .note-main {
    margin-bottom: 12px;
    line-height: 1.6;
    color: #333;
}

.insight-atlas-note .note-section {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid #E5E5E5;
    line-height: 1.6;
}

.insight-atlas-note .note-section strong {
    color: #C9A227;
}

.insight-atlas-note .note-deeper {
    font-style: italic;
    color: #666;
}
```

#### Step 3: Remove ASCII Box Detection

```javascript
// Find and replace ASCII box patterns with proper components
function replaceASCIIBoxes(content) {
    // Pattern to detect ASCII boxes
    const asciiBoxPattern = /┌[─┬]+┐[\s\S]*?└[─┴]+┘/g;
    
    // Alternative pattern for pipe-based boxes
    const pipeBoxPattern = /\|[-─]+\|[\s\S]*?\|[-─]+\|/g;
    
    // Extract content from ASCII box and convert to proper component
    return content.replace(asciiBoxPattern, (match) => {
        // Remove all box-drawing characters
        const cleanContent = match
            .replace(/[┌┐└┘├┤┬┴┼─│]/g, '')
            .replace(/\s+/g, ' ')
            .trim();
        
        // Detect component type and create proper HTML
        if (cleanContent.includes('INSIGHT ATLAS NOTE')) {
            return createInsightAtlasNote(cleanContent);
        }
        
        // Default: return as styled div
        return `<div class="content-box">${cleanContent}</div>`;
    });
}
```

---

## BUG-005: Exercise Boxes Formatting Issues

### Symptoms
Exercise sections have internal formatting problems including:
- Visible asterisks from bold syntax
- Missing first characters
- Inconsistent numbering

### REQUIRED FIX

```javascript
// Exercise Box Component
function createExerciseBox(title, content, duration) {
    // Process the content for proper markdown rendering
    let processedContent = content;
    processedContent = processBoldMarkdown(processedContent);
    processedContent = processItalicsFixed(processedContent);
    processedContent = processNumberedList(processedContent);
    
    return `
    <div class="exercise-box">
        <div class="exercise-header">
            <span class="exercise-icon">✏</span>
            <span class="exercise-title">${title}</span>
        </div>
        <div class="exercise-content">
            ${processedContent}
        </div>
        ${duration ? `<div class="exercise-duration">⏱ ${duration}</div>` : ''}
    </div>`;
}

// Process numbered lists properly
function processNumberedList(content) {
    const listPattern = /^(\d+)\.\s+(.+)$/gm;
    
    return content.replace(listPattern, (match, number, text) => {
        // Process any inline markdown in the list item text
        let processedText = processBoldMarkdown(text);
        processedText = processItalicsFixed(processedText);
        return `<li value="${number}">${processedText}</li>`;
    });
}
```

```css
.exercise-box {
    border: 2px solid #4A90A4;
    border-radius: 8px;
    margin: 20px 0;
    background-color: #F5FAFC;
    overflow: hidden;
}

.exercise-box .exercise-header {
    background-color: #4A90A4;
    color: white;
    padding: 12px 16px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.exercise-box .exercise-icon {
    font-size: 18px;
}

.exercise-box .exercise-title {
    font-weight: 700;
    font-size: 14px;
}

.exercise-box .exercise-content {
    padding: 16px;
    line-height: 1.6;
}

.exercise-box .exercise-content li {
    margin-bottom: 8px;
}

.exercise-box .exercise-duration {
    background-color: #E8F4F8;
    padding: 8px 16px;
    font-size: 13px;
    color: #4A90A4;
    font-weight: 500;
}
```

---

# PART 4: EXPORT FORMAT-SPECIFIC FIXES

## PDF EXPORT ISSUES

### Current State
PDF export is the closest to working but still has all markdown parsing issues.

### Required Fixes for PDF

```javascript
// PDF Export Pipeline - Correct Order
async function exportToPDF(content) {
    let processed = content;
    
    // STEP 1: Pre-process special components
    processed = replaceASCIIBoxes(processed);
    
    // STEP 2: Process markdown in correct order
    processed = processCodeBlocks(processed);      // Protect code first
    processed = processBoldMarkdown(processed);    // ** -> <strong>
    processed = processItalicsFixed(processed);    // * -> <em>
    processed = parseMarkdownTable(processed);     // Tables
    processed = processNumberedList(processed);    // Numbered lists
    processed = processBulletList(processed);      // Bullet lists
    
    // STEP 3: Convert HTML to PDF
    const pdfOptions = {
        format: 'A4',
        margin: {
            top: '20mm',
            right: '20mm',
            bottom: '20mm',
            left: '20mm'
        },
        printBackground: true  // CRITICAL: Must be true for backgrounds
    };
    
    // STEP 4: Include CSS
    const htmlWithStyles = `
        <!DOCTYPE html>
        <html>
        <head>
            <style>${getPDFStyles()}</style>
        </head>
        <body>
            ${processed}
        </body>
        </html>
    `;
    
    return generatePDF(htmlWithStyles, pdfOptions);
}

function getPDFStyles() {
    return `
        body {
            font-family: 'Georgia', serif;
            font-size: 12pt;
            line-height: 1.6;
            color: #333;
        }
        
        strong {
            font-weight: 700;
        }
        
        em {
            font-style: italic;
        }
        
        /* Include all component CSS here */
        ${getTableCSS()}
        ${getNoteBoxCSS()}
        ${getExerciseBoxCSS()}
    `;
}
```

---

## DOCX EXPORT ISSUES

### Current State
CRITICAL: DOCX files do not open after export. This is a complete failure.

### Likely Causes
1. Corrupted file structure
2. Invalid XML in document
3. Missing required DOCX components
4. Encoding issues

### Required Fixes for DOCX

```javascript
// DOCX Export - Using docx library (recommended)
const { Document, Paragraph, TextRun, Table, TableRow, TableCell } = require('docx');

async function exportToDOCX(content) {
    // STEP 1: Parse content into structured format
    const sections = parseContentSections(content);
    
    // STEP 2: Build document with proper structure
    const doc = new Document({
        sections: [{
            properties: {},
            children: sections.map(section => convertSectionToDOCX(section))
        }]
    });
    
    // STEP 3: Generate buffer
    const buffer = await Packer.toBuffer(doc);
    
    // STEP 4: Validate before saving
    if (!validateDOCXBuffer(buffer)) {
        throw new Error('Generated DOCX is invalid');
    }
    
    return buffer;
}

function convertSectionToDOCX(section) {
    switch (section.type) {
        case 'heading':
            return new Paragraph({
                text: section.content,
                heading: getHeadingLevel(section.level),
                spacing: { before: 400, after: 200 }
            });
            
        case 'paragraph':
            return new Paragraph({
                children: parseInlineFormattingDOCX(section.content),
                spacing: { after: 200 }
            });
            
        case 'table':
            return createDOCXTable(section.data);
            
        case 'note-box':
            return createDOCXNoteBox(section.content);
            
        case 'exercise':
            return createDOCXExercise(section.content);
            
        default:
            return new Paragraph({ text: section.content });
    }
}

function parseInlineFormattingDOCX(text) {
    const runs = [];
    let remaining = text;
    
    // Parse bold
    const boldPattern = /\*\*([^*]+)\*\*/;
    // Parse italic
    const italicPattern = /\*([^*]+)\*/;
    
    while (remaining.length > 0) {
        const boldMatch = remaining.match(boldPattern);
        const italicMatch = remaining.match(italicPattern);
        
        if (boldMatch && (!italicMatch || boldMatch.index <= italicMatch.index)) {
            // Add text before bold
            if (boldMatch.index > 0) {
                runs.push(new TextRun(remaining.substring(0, boldMatch.index)));
            }
            // Add bold text
            runs.push(new TextRun({ text: boldMatch[1], bold: true }));
            remaining = remaining.substring(boldMatch.index + boldMatch[0].length);
        } else if (italicMatch) {
            // Add text before italic
            if (italicMatch.index > 0) {
                runs.push(new TextRun(remaining.substring(0, italicMatch.index)));
            }
            // Add italic text
            runs.push(new TextRun({ text: italicMatch[1], italics: true }));
            remaining = remaining.substring(italicMatch.index + italicMatch[0].length);
        } else {
            // No more formatting, add remaining text
            runs.push(new TextRun(remaining));
            break;
        }
    }
    
    return runs;
}

function createDOCXTable(tableData) {
    const rows = tableData.map((rowData, rowIndex) => {
        const cells = rowData.map(cellContent => {
            return new TableCell({
                children: [new Paragraph(cellContent)],
                shading: rowIndex === 0 ? { fill: 'F5F5F5' } : undefined
            });
        });
        return new TableRow({ children: cells });
    });
    
    return new Table({
        rows: rows,
        width: { size: 100, type: 'pct' }
    });
}

function validateDOCXBuffer(buffer) {
    // Check minimum size
    if (buffer.length < 1000) return false;
    
    // Check for ZIP signature (DOCX is a ZIP file)
    const signature = buffer.slice(0, 4);
    const zipSignature = Buffer.from([0x50, 0x4B, 0x03, 0x04]);
    
    return signature.equals(zipSignature);
}
```

### DOCX TROUBLESHOOTING

If DOCX still fails to open:

1. **Check for XML encoding issues:**
```javascript
function sanitizeForXML(text) {
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;')
        // Remove invalid XML characters
        .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
}
```

2. **Ensure all required DOCX parts exist:**
```
[Content_Types].xml
_rels/.rels
word/document.xml
word/_rels/document.xml.rels
word/styles.xml
```

3. **Test with minimal document first:**
```javascript
async function testMinimalDOCX() {
    const doc = new Document({
        sections: [{
            children: [
                new Paragraph({ text: 'Test Document' })
            ]
        }]
    });
    
    const buffer = await Packer.toBuffer(doc);
    fs.writeFileSync('test.docx', buffer);
    // Try to open this file - if it works, issue is in content processing
}
```

---

## HTML EXPORT ISSUES

### Current State
Has similar markdown parsing issues as PDF.

### Required Fixes for HTML

```javascript
async function exportToHTML(content) {
    let processed = content;
    
    // Process all markdown
    processed = replaceASCIIBoxes(processed);
    processed = processCodeBlocks(processed);
    processed = processBoldMarkdown(processed);
    processed = processItalicsFixed(processed);
    processed = parseMarkdownTable(processed);
    processed = processLists(processed);
    
    // Wrap in complete HTML document
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Insight Atlas Guide</title>
    <style>
        ${getCompleteCSS()}
    </style>
</head>
<body>
    <div class="container">
        ${processed}
    </div>
</body>
</html>`;
    
    return html;
}

function getCompleteCSS() {
    return `
        * {
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Georgia', 'Times New Roman', serif;
            font-size: 16px;
            line-height: 1.7;
            color: #333;
            background-color: #FFFDF5;
            margin: 0;
            padding: 0;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        h1, h2, h3, h4, h5, h6 {
            font-family: 'Georgia', serif;
            color: #1a1a1a;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
        }
        
        h1 { font-size: 2em; }
        h2 { font-size: 1.5em; }
        h3 { font-size: 1.25em; }
        
        p {
            margin-bottom: 1em;
        }
        
        strong {
            font-weight: 700;
        }
        
        em {
            font-style: italic;
        }
        
        /* Table styles */
        ${getTableCSS()}
        
        /* Note box styles */
        ${getNoteBoxCSS()}
        
        /* Exercise box styles */
        ${getExerciseBoxCSS()}
        
        /* Flow diagram styles */
        ${getFlowDiagramCSS()}
    `;
}
```

---

# PART 5: COMPLETE IMPLEMENTATION CHECKLIST

## Files to Create/Modify

### 1. markdownParser.js (or equivalent)
- [ ] Implement `processBoldMarkdown()` function
- [ ] Fix `processItalics()` function (character truncation bug)
- [ ] Implement `parseMarkdownTable()` function
- [ ] Implement `processLists()` function
- [ ] Ensure correct processing order

### 2. componentRenderer.js (or equivalent)
- [ ] Create `createInsightAtlasNote()` function
- [ ] Create `createExerciseBox()` function
- [ ] Create `createFlowDiagram()` function
- [ ] Implement `replaceASCIIBoxes()` function

### 3. pdfExporter.js (or equivalent)
- [ ] Fix processing pipeline order
- [ ] Include all CSS styles
- [ ] Enable `printBackground: true`

### 4. docxExporter.js (or equivalent)
- [ ] Rewrite using proper DOCX library
- [ ] Implement inline formatting parser
- [ ] Add validation before save
- [ ] Test with minimal document

### 5. htmlExporter.js (or equivalent)
- [ ] Apply same markdown fixes
- [ ] Include complete CSS
- [ ] Ensure proper HTML5 structure

### 6. styles.css (or equivalent)
- [ ] Add table styles
- [ ] Add note box styles
- [ ] Add exercise box styles
- [ ] Add flow diagram styles

---

# PART 6: TESTING REQUIREMENTS

## Unit Tests

```javascript
// Test bold parsing
describe('Bold Markdown Parsing', () => {
    test('converts **text** to bold', () => {
        const input = '**Bold Text**';
        const output = processBoldMarkdown(input);
        expect(output).toBe('<strong>Bold Text</strong>');
    });
    
    test('handles multiple bold sections', () => {
        const input = '**First** and **Second**';
        const output = processBoldMarkdown(input);
        expect(output).toBe('<strong>First</strong> and <strong>Second</strong>');
    });
    
    test('handles bold with special characters', () => {
        const input = '**Text with: colons**';
        const output = processBoldMarkdown(input);
        expect(output).toBe('<strong>Text with: colons</strong>');
    });
});

// Test italic parsing (character truncation fix)
describe('Italic Markdown Parsing', () => {
    test('converts *text* to italic without losing characters', () => {
        const input = '*Italic Text*';
        const output = processItalicsFixed(input);
        expect(output).toBe('<em>Italic Text</em>');
    });
    
    test('does not affect non-italic text', () => {
        const input = 'Read time: 2 minutes';
        const output = processItalicsFixed(input);
        expect(output).toBe('Read time: 2 minutes');
    });
    
    test('preserves first character of words', () => {
        const input = '• Read time: 2 minutes';
        const output = processItalicsFixed(input);
        expect(output).toBe('• Read time: 2 minutes');
        expect(output).not.toBe('• ead time: 2 minutes');
    });
});

// Test table parsing
describe('Table Parsing', () => {
    test('converts markdown table to HTML', () => {
        const input = `| Col1 | Col2 |
|------|------|
| A    | B    |`;
        const output = parseMarkdownTable(input);
        expect(output).toContain('<table');
        expect(output).toContain('<th>');
        expect(output).toContain('<td>');
    });
});
```

## Integration Tests

```javascript
// Test complete export pipeline
describe('PDF Export', () => {
    test('generates valid PDF with no raw markdown', async () => {
        const content = '**Bold** and *italic* text';
        const pdf = await exportToPDF(content);
        
        // Convert PDF to text and check for raw markdown
        const pdfText = await extractTextFromPDF(pdf);
        expect(pdfText).not.toContain('**');
        expect(pdfText).not.toContain('*italic*');
    });
});

describe('DOCX Export', () => {
    test('generates valid DOCX that can be opened', async () => {
        const content = 'Test content';
        const buffer = await exportToDOCX(content);
        
        // Check ZIP signature
        expect(buffer[0]).toBe(0x50);
        expect(buffer[1]).toBe(0x4B);
        
        // Try to parse as ZIP
        const zip = new JSZip();
        await expect(zip.loadAsync(buffer)).resolves.toBeDefined();
    });
});
```

---

# PART 7: QUICK REFERENCE - ALL REGEX PATTERNS

```javascript
// BOLD: **text**
const BOLD_PATTERN = /\*\*([^*]+)\*\*/g;
// Replace with: <strong>$1</strong>

// ITALIC: *text* (after protecting bold)
const ITALIC_PATTERN = /\*([^*]+)\*/g;
// Replace with: <em>$1</em>

// TABLE HEADER
const TABLE_PATTERN = /\|(.+)\|\n\|([-:| ]+)\|\n((?:\|.+\|\n?)+)/g;

// NUMBERED LIST
const NUMBERED_LIST_PATTERN = /^(\d+)\.\s+(.+)$/gm;

// BULLET LIST
const BULLET_LIST_PATTERN = /^[-*•]\s+(.+)$/gm;

// ASCII BOX (to remove)
const ASCII_BOX_PATTERN = /[┌┐└┘├┤┬┴┼─│]+/g;
```

---

# PART 8: FINAL VERIFICATION

After implementing all fixes, verify the following:

## Visual Inspection Checklist

### PDF Export
- [ ] No visible `**` asterisks anywhere
- [ ] No visible `*` asterisks (except multiplication)
- [ ] All words have their first letter intact
- [ ] Tables display with borders and proper columns
- [ ] Note boxes have colored borders, no ASCII art
- [ ] Exercise boxes properly formatted
- [ ] Flow diagrams display correctly

### DOCX Export
- [ ] File opens without error
- [ ] Bold text appears bold
- [ ] Italic text appears italic
- [ ] Tables are editable Word tables
- [ ] No raw markdown visible

### HTML Export
- [ ] Renders correctly in browser
- [ ] All CSS styles applied
- [ ] Responsive on mobile
- [ ] No raw markdown visible

---

END OF IMPLEMENTATION GUIDE
