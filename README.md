# Voice Recognition Flutter App

This is a Flutter version of the emergency voice recognition app.

## Features

- ✅ Splash screen with dark blue background
- ✅ Emergency contacts management
- ✅ Background voice recognition listening for "help" keyword
- ✅ Activation screen with 38-second timer
- ✅ Audio recording during activation
- ✅ Emergency actions (SMS, calls, location sharing)
- ✅ Automatic emergency services call (112)

## Setup Instructions

1. **Install Flutter**: Make sure you have Flutter SDK installed
   ```bash
   flutter --version
   ```

2. **Get Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate Code** (for JSON serialization):
   ```bash
   flutter pub run build_runner build
   ```

4. **Run the App**:
   ```bash
   flutter run
   ```

## Required Permissions

The app requires the following permissions:
- Microphone (for speech recognition and recording)
- Location (for emergency location sharing)
- Phone (for making calls)
- SMS (for sending emergency messages)
- Notifications (for background service)

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   ├── emergency_contact.dart         # Emergency contact model
│   └── emergency_contact.g.dart       # Generated JSON serialization
├── screens/
│   ├── splash_screen.dart             # Splash screen
│   ├── emergency_contacts_screen.dart # Contacts management
│   └── activation_screen.dart         # Emergency activation
└── services/
    ├── emergency_contacts_repository.dart  # Contact storage
    ├── background_listening_service.dart  # Background listening
    └── emergency_handler.dart              # Emergency actions
```

## Key Differences from Native Android

1. **UI Framework**: Uses Flutter widgets instead of Jetpack Compose
2. **State Management**: Uses Provider instead of ViewModel
3. **Navigation**: Uses go_router instead of Navigation Compose
4. **Background Service**: Uses flutter_background_service plugin
5. **Speech Recognition**: Uses speech_to_text plugin
6. **Location**: Uses geolocator plugin
7. **Storage**: Uses shared_preferences plugin

## Testing

1. Add emergency contacts
2. Start background listening (implement UI button)
3. Say "help" 3 times within 1 minute
4. Verify activation screen opens
5. Test STOP button
6. Test timer expiration (38 seconds)

## Notes

- Background service requires proper Android configuration
- Some features may need platform-specific implementations
- WiFi/Mobile data control requires system-level permissions
