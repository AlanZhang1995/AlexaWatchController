# Alexa Watch Controller

Apple Watch application for controlling Alexa smart plugs.

## Project Structure

```
AlexaWatchController/
├── AlexaWatchController/           # iOS Companion App
│   ├── App/                        # App entry point
│   ├── Views/                      # SwiftUI Views
│   ├── ViewModels/                 # MVVM ViewModels
│   └── Resources/                  # Assets and resources
├── AlexaWatchControllerWatch/      # watchOS App
│   ├── App/                        # Watch App entry point
│   ├── Views/                      # Watch SwiftUI Views
│   ├── ViewModels/                 # Watch ViewModels
│   ├── Complications/              # Watch face complications
│   └── Resources/                  # Watch assets
├── Shared/                         # Shared code between iOS and watchOS
│   ├── Models/                     # Data models
│   ├── Services/                   # Service layer
│   └── Utilities/                  # Shared utilities
└── Tests/                          # Test targets
    ├── AlexaWatchControllerTests/  # iOS app tests
    └── SharedTests/                # Shared code tests
```

## Configuration

- **Bundle ID (iOS)**: com.example.alexawatchcontroller
- **Bundle ID (watchOS)**: com.example.alexawatchcontroller.watchkitapp
- **App Group**: group.com.example.alexawatchcontroller

## Capabilities

- WatchConnectivity (for token sync between iPhone and Watch)
- App Groups (for shared data storage)
- Keychain Sharing (for secure token storage)

## Requirements

- iOS 16.0+
- watchOS 9.0+
- Xcode 15.0+
- Swift 5.9+
