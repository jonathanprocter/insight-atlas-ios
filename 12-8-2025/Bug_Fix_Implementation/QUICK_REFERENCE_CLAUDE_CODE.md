# URGENT: Fix Insight Atlas Application - Quick Reference

## IMMEDIATE ACTIONS REQUIRED

### BUG 1: Bold text shows as `**text**` instead of bold
**FIX:** Find markdown parser, add/fix this regex:
```
Pattern: /\*\*([^*]+)\*\*/g
Replace: <strong>$1</strong>
```

### BUG 2: First letters missing (e.g., "Read" becomes "ead")
**FIX:** Fix italic parser - it's eating first characters:
```
WRONG: /\*(\w)/g
RIGHT: /\*([^*]+)\*/g
```

### BUG 3: Tables show as raw `| Col | Col |` text
**FIX:** Implement table-to-HTML converter (see full guide)

### BUG 4: Note boxes show ASCII art `┌───┐` instead of CSS
**FIX:** Replace ASCII detection with proper CSS-styled divs

### BUG 5: DOCX files won't open after export
**FIX:** Rewrite DOCX export using proper library (docx npm package)

---

## PROCESSING ORDER (CRITICAL)
1. Process code blocks (protect content)
2. Process **bold** 
3. Process *italic*
4. Process tables
5. Process lists
6. Convert to final format

---

## KEY CSS NEEDED

```css
/* Tables */
.markdown-table { width: 100%; border-collapse: collapse; }
.markdown-table th, .markdown-table td { border: 1px solid #ddd; padding: 10px; }
.markdown-table th { background: #f5f5f5; font-weight: 600; }

/* Note Boxes */
.insight-atlas-note { border: 2px solid #C9A227; border-radius: 8px; background: #FFFDF5; }
.note-header { background: #C9A227; color: white; padding: 12px; }

/* Exercise Boxes */
.exercise-box { border: 2px solid #4A90A4; border-radius: 8px; background: #F5FAFC; }
```

---

## TEST CASES (Must Pass)

```
Input: "**Bold**" → Output: <strong>Bold</strong> (NOT "**Bold**")
Input: "• Read time" → Output: "• Read time" (NOT "• ead time")
Input: "| A | B |" → Output: <table>...</table> (NOT raw pipes)
```

---

For complete implementation details, see: INSIGHT_ATLAS_BUG_FIX_IMPLEMENTATION.md
