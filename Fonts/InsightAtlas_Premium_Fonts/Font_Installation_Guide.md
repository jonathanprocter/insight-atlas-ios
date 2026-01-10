# Insight Atlas: Custom Font Installation Guide

To achieve the full premium design experience in your Insight Atlas iOS app, you need to install the custom fonts provided. This guide will walk you through the process.

## Included Fonts

This package contains the following font families:

- **Cormorant Garamond**: For elegant display headings and comfortable body text.
- **Inter**: A clean, readable sans-serif for all UI elements like buttons and labels.
- **Caveat**: A handwritten font for special accents and taglines.

## Installation Steps

### Step 1: Add the Fonts Folder to Your Xcode Project

1.  Open your Insight Atlas Xcode project.
2.  From the Finder, drag the entire `Fonts` folder (included in this package) into your Xcode project navigator. A dialog box will appear.
3.  In the dialog box, make sure to check the following options:
    *   **Copy items if needed**: This should be checked.
    *   **Create groups**: Select this option.
    *   **Add to targets**: Ensure your main app target (e.g., `InsightAtlas`) is checked.

This will copy the fonts into your project and make them accessible to your app.

### Step 2: Update Your Info.plist File

For the app to recognize and load the fonts, you must declare them in your `Info.plist` file.

1.  In your Xcode project navigator, find and open the `Info.plist` file.
2.  Add a new key called **`Fonts provided by application`**. If you're editing the raw XML, the key is `UIAppFonts`.
3.  This key is an array. You need to add a new string item for each font file you've added. 

**Copy and paste the following XML snippet into your `Info.plist` file by right-clicking it and choosing "Open As > Source Code":**

```xml
<key>UIAppFonts</key>
<array>
    <!-- Cormorant Garamond -->
    <string>CormorantGaramond-Regular.ttf</string>
    <string>CormorantGaramond-Medium.ttf</string>
    <string>CormorantGaramond-SemiBold.ttf</string>
    <string>CormorantGaramond-Bold.ttf</string>
    <string>CormorantGaramond-Italic.ttf</string>
    <string>CormorantGaramond-MediumItalic.ttf</string>
    <string>CormorantGaramond-SemiBoldItalic.ttf</string>
    <string>CormorantGaramond-BoldItalic.ttf</string>
    <string>CormorantGaramond-Light.ttf</string>
    <string>CormorantGaramond-LightItalic.ttf</string>

    <!-- Inter -->
    <string>Inter-Regular.ttf</string>
    <string>Inter-Medium.ttf</string>
    <string>Inter-SemiBold.ttf</string>
    <string>Inter-Bold.ttf</string>

    <!-- Caveat -->
    <string>Caveat.ttf</string>
</array>
```

### Step 3: Verify the Installation

1.  Build and run your app.
2.  Navigate to the analysis detail view.
3.  You should now see the custom fonts rendered correctly. The headings will have the elegant serif style of Cormorant Garamond, the UI elements will use the clean Inter font, and the tagline will appear in the handwritten Caveat font.

## Troubleshooting

*   **Fonts not appearing?** Double-check that the font filenames in your `Info.plist` exactly match the filenames in your `Fonts` folder.
*   **App crashing on launch?** This can happen if the font files are not correctly added to the target. Go to your project's "Build Phases" -> "Copy Bundle Resources" and ensure all the `.ttf` files are listed there.

That's it! Your app will now have the complete, premium visual identity intended by the design.
