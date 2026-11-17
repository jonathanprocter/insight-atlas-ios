# Insight Atlas iOS

> Transform how you learn - Where Understanding Illuminates the World

Insight Atlas is an iOS application that generates comprehensive, beautifully formatted reading guides from PDF and EPUB books using AI (MiniMax primary, with Claude and OpenRouter).

## Features

- **AI-Powered Guide Generation**: Transform any book into an insightful, structured guide
- **Multiple AI Providers**: MiniMax (OAuth), Claude (Anthropic), and OpenRouter
- **Beautiful Export Formats**: Export guides as Markdown, PDF, HTML, DOCX, or plain text
- **Premium UI Design**: Elegant, book-inspired interface with custom typography
- **Secure API Key Storage**: API keys and OAuth tokens stored securely in iOS Keychain
- **Offline Library**: All guides stored locally for offline access
- **Premium Offline Narration**: Pocket/Kokoro on-device speech, with Apple system voices as fallback (no hosted Liam TTS)
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

### API Keys / Auth

Insight Atlas generates guides with:

1. **MiniMax** (default): Sign in via OAuth in Settings
2. **Claude API Key**: From [console.anthropic.com](https://console.anthropic.com/)
3. **OpenRouter API Key**: From [openrouter.ai](https://openrouter.ai/) (optional fallback)

Configure providers in Settings. OpenAI is not a supported provider.

> **Security Note**: API keys and MiniMax tokens are stored securely in the iOS Keychain and are never transmitted to any server except the respective AI providers. Reset All Settings clears MiniMax tokens as well.

### Offline Narration

Pocket/Kokoro is the default narration provider, with Apple system voices as fallback. In the app, open **Settings → Audio & Narration**, then download the verified on-device model once. The download is approximately 126 MiB and uses approximately 182 MiB after installation; subsequent narration works without a network connection or speech API credentials. See [Kokoro Offline Narration](docs/KOKORO_OFFLINE_NARRATION.md) for model integrity, privacy, fallbacks, and troubleshooting.

## Architecture

The app follows a SwiftUI + service-container pattern:

```
InsightAtlas/
├── Models/
│   └── GuideModels.swift            # Library item + generation models
├── Views/
│   ├── LibraryView.swift            # Library
│   ├── GenerationView.swift         # Guide generation
│   ├── AnalysisDetailView.swift     # Guide reader
│   ├── SettingsView.swift           # Providers, Pocket voices, theme
│   ├── AnalysisBookReferences.swift # Split from AnalysisComponents
│   └── …
├── Services/
│   ├── AIService.swift              # Shared MiniMax / Claude / OpenRouter client
│   ├── AppEnvironment.swift         # Settings source of truth + DI facade
│   ├── DataManager.swift            # Library CRUD + export orchestration
│   ├── GuideHTMLExporter.swift      # HTML export
│   ├── GuideDOCXExporter.swift      # DOCX export
│   ├── GuidePDFExporter.swift       # PDF export (MainActor)
│   ├── SourceTextStore.swift        # Manuscripts for Regenerate
│   ├── GuideBodyStore.swift         # Lazy guide bodies on disk
│   ├── NarrationService.swift       # Pocket + Apple narration
│   ├── KokoroAudioService.swift     # On-device sherpa-onnx TTS
│   ├── KokoroModelManager.swift     # Model download / install
│   ├── BookProcessor.swift          # PDF/EPUB extract
│   └── KeychainService.swift        # API keys + MiniMax OAuth tokens
└── PrivacyInfo.xcprivacy
```

### Key Services

| Service | Responsibility |
|---------|---------------|
| `AIService.shared` | MiniMax (default), Claude, OpenRouter |
| `AppEnvironment.shared` | Single settings SoT + service wiring |
| `DataManager` | Library metadata, body flush, export entry points |
| `Guide*Exporter` | HTML / DOCX / PDF writers |
| `SourceTextStore` | Original book text for Regenerate |
| `NarrationService` | Pocket (Kokoro) + Apple Voice orchestration |
| `KokoroAudioService` | Local 24 kHz synthesis via sherpa-onnx |
| `KeychainService` | Claude/OpenRouter keys + MiniMax OAuth |

Release uploads **must** use `scripts/release-testflight.sh` (strips unused onnxruntime/SherpaOnnxC dynamic stubs).

## Testing

Run the test suite:

```bash
xcodebuild test -scheme InsightAtlas -destination 'platform=iOS Simulator,name=iPhone 16'
```

Representative tests:
- `SettingsSourceOfTruthTests.swift` — AppEnvironment ↔ DataManager settings mirror
- `SourceTextStoreTests.swift` — Regenerate source persistence
- `ManuscriptGateExportTests.swift` — export integrity gate
- `MiniMaxCredentialHelperTests.swift` — OAuth credential helpers
- `KokoroModelManagerTests.swift` / `KokoroTextChunkerTests.swift` / `KokoroVoiceRegistryTests.swift`
- PDF redesign + governor suites under `InsightAtlasTests/`

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

| Dependency | Purpose |
|---|---|
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | EPUB extraction |
| [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | Native on-device Kokoro inference |
| [SWCompression](https://github.com/tsolomko/SWCompression) | Verified model archive extraction |

See [Third-Party Notices](docs/THIRD_PARTY_NOTICES.md) for attribution and licenses.

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
