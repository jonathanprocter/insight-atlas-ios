# Insight Atlas iOS

> Transform how you learn - Where Understanding Illuminates the World

Insight Atlas is an iOS application that generates comprehensive, beautifully formatted reading guides from PDF and EPUB books using AI (Claude and OpenAI).

## Features

- **AI-Powered Guide Generation**: Transform any book into an insightful, structured guide
- **Multiple AI Providers**: Support for Claude (Anthropic) and OpenAI
- **Beautiful Export Formats**: Export guides as Markdown, PDF, HTML, DOCX, or plain text
- **Premium UI Design**: Elegant, book-inspired interface with custom typography
- **Secure API Key Storage**: API keys stored securely in iOS Keychain
- **Offline Library**: All guides stored locally for offline access
- **Accessibility Support**: VoiceOver and Dynamic Type compatible

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/insight-atlas-ios.git
cd insight-atlas-ios
```

2. Open the project in Xcode:
```bash
open InsightAtlas.xcodeproj
```

3. Build and run on your device or simulator.

## Configuration

### API Keys

Insight Atlas requires API keys from either Anthropic (Claude) or OpenAI to generate guides:

1. **Claude API Key**: Get from [console.anthropic.com](https://console.anthropic.com/)
2. **OpenAI API Key**: Get from [platform.openai.com](https://platform.openai.com/)

Configure your API keys in the app's Settings > Manage API Keys section.

> **Security Note**: API keys are stored securely in the iOS Keychain and are never transmitted to any server except the respective AI providers.

## Architecture

The app follows a clean architecture pattern with SwiftUI:

```
InsightAtlas/
├── Models/
│   └── GuideModels.swift       # Data models
├── Views/
│   ├── LibraryView.swift       # Main library screen
│   ├── GenerationView.swift    # Guide generation UI
│   ├── AnalysisDetailView.swift # Guide reader
│   ├── SettingsView.swift      # Settings & configuration
│   └── AnalysisComponents.swift # Reusable UI components
├── Services/
│   ├── AIService.swift         # AI API integration
│   ├── BookProcessor.swift     # PDF/EPUB processing
│   ├── DataManager.swift       # Main data management
│   ├── KeychainService.swift   # Secure key storage
│   ├── LibraryService.swift    # Library management
│   ├── SettingsService.swift   # Settings management
│   ├── ExportService.swift     # Export functionality
│   └── PDFTextFixer.swift      # Text extraction fixes
├── Extensions/
│   ├── String+Localization.swift
│   └── View+Accessibility.swift
└── Resources/
    └── en.lproj/
        └── Localizable.strings # Localization
```

### Key Services

| Service | Responsibility |
|---------|---------------|
| `AIService` | Handles communication with AI providers (Claude, OpenAI) |
| `BookProcessor` | Extracts text from PDF and EPUB files |
| `DataManager` | Main coordinator for data persistence |
| `KeychainService` | Secure storage for API keys |
| `LibraryService` | CRUD operations for library items |
| `ExportService` | Export guides to various formats |
| `PDFTextFixer` | Fixes ligatures and encoding issues from PDFs |

## Testing

Run the test suite:

```bash
xcodebuild test -scheme InsightAtlas -destination 'platform=iOS Simulator,name=iPhone 15'
```

Test files:
- `PDFTextFixerTests.swift` - Text extraction tests
- `AIServiceTests.swift` - AI service tests
- `BookProcessorTests.swift` - Book processing tests
- `KeychainServiceTests.swift` - Keychain storage tests
- `LibraryServiceTests.swift` - Library management tests

## Localization

The app supports localization through `Localizable.strings`. Currently available:
- English (en)

To add a new language:
1. Create a new `.lproj` folder (e.g., `fr.lproj`)
2. Copy `Localizable.strings` and translate all strings
3. Add the language to the project settings

## Accessibility

The app includes comprehensive accessibility support:
- All interactive elements have accessibility labels
- VoiceOver navigation is fully supported
- Dynamic Type support for text scaling
- High contrast mode compatibility

## Security

- **API Keys**: Stored in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **No Server Communication**: Keys are only sent to AI providers
- **Local Storage**: All library data stored on-device
- **No Analytics**: No tracking or analytics SDKs

## Dependencies

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) - EPUB extraction

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is proprietary software. All rights reserved.

## Support

For support, please open an issue on GitHub.

---

Built with SwiftUI and AI
