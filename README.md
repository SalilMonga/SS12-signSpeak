# SignSpeak - ASL Translator App

An iOS application for translating American Sign Language (ASL) gestures, built with Flutter.

## Prerequisites

Before running this project, ensure you have the following installed:

1. **Flutter SDK**
2. **Xcode** (required for iOS development)
3. **CocoaPods**

### Installing Flutter

1. **Download Flutter**
   - Visit [flutter.dev/docs/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos)
   - Download the latest stable release for macOS
   - Or use Homebrew:
     ```bash
     brew install flutter
     ```

2. **Add Flutter to your PATH**
   - If you downloaded manually, extract the zip file and add to PATH:
     ```bash
     export PATH="$PATH:`pwd`/flutter/bin"
     ```
   - Add this line to your `~/.zshrc` or `~/.bash_profile` to make it permanent

3. **Verify Flutter installation**
   ```bash
   flutter --version
   flutter doctor
   ```

### Installing Xcode

1. **Install Xcode from the Mac App Store**
   - Search for "Xcode" and install (this may take a while, it's a large download)

2. **Install Xcode Command Line Tools**
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

3. **Accept Xcode license**
   ```bash
   sudo xcodebuild -license accept
   ```

### Installing CocoaPods

```bash
sudo gem install cocoapods
```

## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd SS12-signSpeak
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Install iOS dependencies**
   ```bash
   cd ios
   pod install
   cd ..
   ```

4. **Verify Flutter setup**
   ```bash
   flutter doctor
   ```
   Make sure there are no issues with iOS setup. If there are, follow the suggestions provided.

## Running on iOS Simulator

### Quick Start (3 Steps)

1. **Start the iOS Simulator**
   ```bash
   open -a Simulator
   ```
   This will open the default iPhone simulator. Wait for it to fully boot up.

2. **Navigate to the project directory**
   ```bash
   cd SS12-signSpeak
   ```

3. **Run the app**
   ```bash
   flutter run
   ```
   The app will build and launch on the simulator. This may take a few minutes on the first run.

### Advanced Options

**List available simulators:**
```bash
flutter emulators
```

**Launch a specific simulator:**
```bash
flutter emulators --launch apple_ios_simulator
```

**See all connected devices:**
```bash
flutter devices
```

**Run on a specific device:**
```bash
flutter run -d <device-id>
```

### Hot Reload

While the app is running, you can make changes to the code and press:
- `r` - Hot reload (updates the UI without restarting the app)
- `R` - Hot restart (restarts the app)
- `q` - Quit the app

## Running on Physical iOS Device

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select your device from the device dropdown
3. Update the Bundle Identifier and Team in Signing & Capabilities
4. Run from Xcode or use `flutter run`

## Project Structure

```
sign_speak/
├── lib/                 # Dart source files
│   └── main.dart       # Application entry point
├── ios/                # iOS-specific code
├── android/            # Android-specific code
├── test/               # Test files
└── pubspec.yaml        # Dependencies and configuration
```

## Common Commands

- `flutter run` - Run the app in debug mode
- `flutter build ios` - Build the iOS app
- `flutter test` - Run tests
- `flutter clean` - Clean build artifacts
- `flutter pub get` - Install dependencies

## Troubleshooting

### "No devices found"
- Make sure Simulator is running
- Check `flutter devices` to see available devices

### CocoaPods issues
- Run `cd ios && pod install && cd ..`
- If issues persist, try `pod repo update` then `pod install`

### Xcode signing issues
- Open `ios/Runner.xcworkspace` in Xcode
- Select a development team in Signing & Capabilities

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter iOS Setup](https://docs.flutter.dev/get-started/install/macos/mobile-ios)
- [ASL Resources](https://www.nidcd.nih.gov/health/american-sign-language)
