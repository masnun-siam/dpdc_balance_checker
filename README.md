# DPDC Balance Checker

A beautiful, cross-platform Flutter application for checking DPDC (Dhaka Power Distribution Company) electricity account balance. Features a modern gradient UI with smooth animations, token caching, saved customer IDs, and balance sharing capabilities.

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Platforms](#platforms)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [API Integration](#api-integration)
- [Project Structure](#project-structure)
- [Technologies Used](#technologies-used)
- [Building for Production](#building-for-production)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Features

### Core Functionality
- **Balance Checking**: Instant electricity account balance lookup by customer ID
- **Token Caching**: Intelligent bearer token management with automatic refresh
- **Extended Timeouts**: Optimized API call timeouts for reliable connections
- **Error Handling**: Comprehensive error management with user-friendly messages

### User Experience
- **Beautiful UI**: Modern gradient-based design with vibrant colors
- **Smooth Animations**: Page transitions, button effects, and loading animations
- **Saved Customer IDs**: Store multiple customer IDs with optional labels
- **Quick Access**: Select from saved IDs for faster balance checking
- **Share Functionality**: Export and share balance details
- **Responsive Design**: Optimized for mobile, tablet, and desktop screens

### Technical Features
- **Cross-Platform**: Single codebase for Android, iOS, Web, Windows, macOS, and Linux
- **Local Storage**: Persistent data storage using SharedPreferences
- **Material Design 3**: Modern UI components following Google's latest design guidelines
- **GraphQL Integration**: Efficient API queries for balance retrieval

## Screenshots

The application features:
- Gradient home screen with customer ID input
- Animated balance display with detailed account information
- Saved IDs management
- Beautiful error dialogs
- Smooth page transitions

## Platforms

This application supports:

| Platform | Status |
|----------|--------|
| Android  | ✅ Supported |
| iOS      | ✅ Supported |
| Web      | ✅ Supported |
| Windows  | ✅ Supported |
| macOS    | ✅ Supported |
| Linux    | ✅ Supported |

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: Version 3.9.2 or higher
  - [Installation Guide](https://docs.flutter.dev/get-started/install)
- **Dart SDK**: Included with Flutter
- **IDE**:
  - [Android Studio](https://developer.android.com/studio) (recommended) or
  - [VS Code](https://code.visualstudio.com/) with Flutter extensions
- **Platform-Specific Requirements**:
  - **Android**: Android Studio, Android SDK
  - **iOS**: Xcode (macOS only)
  - **Web**: Chrome browser
  - **Desktop**: Platform-specific build tools

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/masnun-siam/dpdc_balance_checker.git
cd dpdc_balance_checker
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Verify Installation

```bash
flutter doctor
```

Ensure all required components show a checkmark.

## Usage

### Running the Application

#### Web
```bash
flutter run -d chrome
```

#### Android/iOS (with device/emulator connected)
```bash
flutter run
```

#### Desktop
```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### Using the App

1. **Enter Customer ID**
   - Launch the app
   - Enter your DPDC customer ID (e.g., `31719842`)
   - Tap "Check Balance"

2. **View Balance**
   - Wait for the API to fetch your balance
   - View detailed account information including:
     - Balance Remaining
     - Customer Name
     - Account ID
     - Customer Class
     - Connection Status
     - Mobile Number
     - Email ID
     - Minimum Recharge Amount

3. **Save Customer ID** (Optional)
   - After viewing balance, tap "Save Customer ID"
   - Add an optional label for easy identification
   - Access saved IDs from the dropdown on home screen

4. **Share Balance**
   - Tap the share button to export balance details
   - Share via SMS, email, WhatsApp, or other apps

## API Integration

The application integrates with the official DPDC API:

### Authentication Flow

**Endpoint**: `https://amiapp.dpdc.org.bd/auth/login/generate-bearer`

```
Method: POST
Headers:
  - Content-Type: application/json;charset=UTF-8
  - clientId: auth-ui
  - clientSecret: 0yFsAl4nN9jX1GGkgOrvpUxDarf2DT40
  - tenantCode: DPDC
```

**Response**: Bearer token valid for multiple requests (cached for efficiency)

### Balance Retrieval

**Endpoint**: `https://amiapp.dpdc.org.bd/usage/usage-service`

```
Method: POST
Headers:
  - Content-Type: application/json;charset=UTF-8
  - Authorization: Bearer {token}
  - accessToken: {token}
  - tenantCode: DPDC
```

**GraphQL Query**:
```graphql
query {
  postBalanceDetails(input: {
    customerNumber: "{CUSTOMER_ID}"
    tenantCode: "DPDC"
  }) {
    accountId
    customerName
    customerClass
    mobileNumber
    emailId
    accountType
    balanceRemaining
    connectionStatus
    customerType
    minRecharge
  }
}
```

### Token Management

- **Caching**: Tokens are cached using SharedPreferences
- **Expiry**: 50-minute validity with automatic refresh
- **Timeout**: Extended to 30 seconds for reliable connections
- **Retry Logic**: Automatic token regeneration on expiry

## Project Structure

```
lib/
├── main.dart                      # Application entry point
├── models/
│   └── balance_details.dart       # Data model for balance information
├── services/
│   ├── dpdc_api_service.dart      # DPDC API integration & token management
│   └── storage_service.dart       # Local storage for saved customer IDs
├── screens/
│   ├── home_screen.dart           # Customer ID input screen
│   └── balance_screen.dart        # Balance display screen
└── widgets/
    └── error_dialog.dart          # Reusable error dialog component

android/                           # Android platform files
ios/                              # iOS platform files
web/                              # Web platform files
windows/                          # Windows platform files
macos/                            # macOS platform files
linux/                            # Linux platform files
test/                             # Unit and widget tests
```

## Technologies Used

### Framework & Language
- **Flutter** (v3.9.2+): Cross-platform UI framework
- **Dart** (v3.9.2+): Programming language

### Key Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `http` | ^1.2.0 | HTTP client for API requests |
| `shared_preferences` | ^2.2.2 | Local data persistence |
| `share_plus` | ^7.2.1 | Native sharing functionality |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |
| `flutter_lints` | ^5.0.0 | Code quality and style enforcement |

### Architecture
- **Pattern**: StatefulWidget with provider-ready structure
- **State Management**: Built-in Flutter state management
- **API Layer**: Service-based architecture
- **Data Models**: Strongly-typed Dart classes with JSON serialization

## Building for Production

### Android (APK)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android (App Bundle)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS
```bash
flutter build ios --release
```
Requires: macOS with Xcode and valid Apple Developer account

### Web
```bash
flutter build web --release
```
Output: `build/web/`

Deploy to any static hosting service (Firebase Hosting, Netlify, Vercel, etc.)

### Windows
```bash
flutter build windows --release
```
Output: `build/windows/runner/Release/`

### macOS
```bash
flutter build macos --release
```
Output: `build/macos/Build/Products/Release/`

### Linux
```bash
flutter build linux --release
```
Output: `build/linux/x64/release/bundle/`

## Development

### Running Tests
```bash
flutter test
```

### Code Formatting
```bash
flutter format .
```

### Static Analysis
```bash
flutter analyze
```

### Clean Build
```bash
flutter clean
flutter pub get
flutter run
```

## Design System

### Color Palette
- **Primary Gradient**: Blue (#3B82F6) to Purple (#8B5CF6)
- **Secondary Gradient**: Orange (#F97316) to Pink (#EC4899)
- **Success**: Green indicators
- **Error**: Red indicators
- **Background**: White/Light gray with gradient overlays

### Typography
- **Title**: Bold, 24-28pt
- **Balance**: Extra Bold, 48-64pt (primary display)
- **Body**: Regular, 14-16pt
- **Labels**: Medium, 12-14pt

### Animations
- Page transitions (Cupertino/Fade)
- Button press effects (scale)
- Loading indicators (circular progress)
- Card entrance animations (fade + slide)
- Pulse effects for icons

## Security Considerations

- **HTTPS**: All API communications over secure HTTPS
- **Token Handling**: Tokens cached securely, auto-refresh on expiry
- **No Sensitive Storage**: Customer IDs only (non-sensitive public data)
- **Input Validation**: All user inputs validated before API calls
- **Error Masking**: No sensitive error details exposed to users

## Future Enhancements

Potential features for future releases:

- Multi-language support (Bengali translation)
- Bill payment integration
- Usage history and consumption trends
- Balance alert notifications
- Dark mode theme
- Biometric authentication for saved accounts
- Offline mode with last cached balance
- Export to PDF functionality

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please ensure:
- Code follows Flutter/Dart style guidelines
- All tests pass (`flutter test`)
- No analyzer warnings (`flutter analyze`)
- Code is properly formatted (`flutter format .`)

## License

This project is open source and available for educational and personal use.

## Support

For issues, questions, or suggestions:
- Open an issue on [GitHub Issues](https://github.com/masnun-siam/dpdc_balance_checker/issues)
- Contact: Masnun Siam

## Acknowledgments

- DPDC (Dhaka Power Distribution Company) for providing the public API
- Flutter team for the amazing framework
- All contributors and users of this application

---

**Version**: 1.0.0+1
**Last Updated**: November 2025
**Maintained by**: [Masnun Siam](https://github.com/masnun-siam)

Made with ❤️ using Flutter
