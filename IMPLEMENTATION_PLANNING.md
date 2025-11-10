# DPDC Balance Checker - Implementation Plan

## Project Overview
A beautiful, gradient-based balance checker application for DPDC (Dhaka Power Distribution Company) that allows users to check their electricity account balance by entering their customer ID.

**Target Platforms**: Mobile (Android/iOS), Web, Desktop (Windows/macOS/Linux)
**Design Style**: Gradient/Colorful with vibrant aesthetics
**Key Features**: Balance checking, Save customer IDs, Share/Export functionality

---

## Technical Architecture

### Technology Stack
- **Framework**: Flutter (Dart)
- **State Management**: StatefulWidget (can upgrade to Provider/Riverpod if needed)
- **HTTP Client**: `http` package
- **Local Storage**: `shared_preferences`
- **Sharing**: `share_plus`

### API Integration Flow

#### Step 1: Generate Bearer Token
```
Endpoint: https://amiapp.dpdc.org.bd/auth/login/generate-bearer
Method: POST
Headers:
  - Content-Type: application/json;charset=UTF-8
  - clientId: auth-ui
  - clientSecret: 0yFsAl4nN9jX1GGkgOrvpUxDarf2DT40
  - tenantCode: DPDC
Body: {}

Response: { "token": "..." }
```

#### Step 2: Fetch Balance Details
```
Endpoint: https://amiapp.dpdc.org.bd/usage/usage-service
Method: POST
Headers:
  - Content-Type: application/json;charset=UTF-8
  - Authorization: Bearer {token}
  - accessToken: {token}
  - tenantCode: DPDC
Body: GraphQL Query
{
  "query": "query{ postBalanceDetails(input :{\n        customerNumber:\"{CUSTOMER_ID}\",tenantCode:\"DPDC\"       \n    } ) {  accountId customerName customerClass mobileNumber emailId  accountType balanceRemaining connectionStatus customerType minRecharge}}"
}

Response Fields:
  - accountId
  - customerName
  - customerClass
  - mobileNumber
  - emailId
  - accountType
  - balanceRemaining (MAIN DISPLAY)
  - connectionStatus
  - customerType
  - minRecharge
```

---

## Implementation Steps

### 1. Setup Dependencies
**File**: `pubspec.yaml`

Add dependencies:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.2.0
  shared_preferences: ^2.2.2
  share_plus: ^7.2.1
```

Run: `flutter pub get`

---

### 2. Create API Service Layer
**File**: `lib/services/dpdc_api_service.dart`

**Responsibilities**:
- Generate bearer token from DPDC auth endpoint
- Fetch balance details using the token
- Parse API responses
- Handle network errors and timeouts
- Return structured data or error messages

**Key Methods**:
```dart
Future<String> generateBearerToken()
Future<BalanceDetails> fetchBalanceDetails(String customerId)
```

**Error Handling**:
- Network connectivity issues
- Invalid API responses
- Token generation failures
- Customer ID not found
- Server errors (500, 503, etc.)

---

### 3. Create Data Models
**File**: `lib/models/balance_details.dart`

**BalanceDetails Class**:
```dart
class BalanceDetails {
  final String accountId;
  final String customerName;
  final String customerClass;
  final String? mobileNumber;
  final String? emailId;
  final String accountType;
  final double balanceRemaining;
  final String connectionStatus;
  final String customerType;
  final double? minRecharge;

  // Constructor, fromJson, toJson methods
}
```

---

### 4. Create Local Storage Service
**File**: `lib/services/storage_service.dart`

**Responsibilities**:
- Save customer IDs with optional labels
- Retrieve list of saved customer IDs
- Delete saved customer IDs
- Store search history (optional)

**Key Methods**:
```dart
Future<void> saveCustomerId(String id, {String? label})
Future<List<String>> getSavedCustomerIds()
Future<void> deleteCustomerId(String id)
```

---

### 5. Build Customer ID Input Page (Home Screen)
**File**: `lib/screens/home_screen.dart`

**UI Components**:
1. **Gradient Background**
   - Use `LinearGradient` or `RadialGradient`
   - Vibrant colors (e.g., blue to purple, orange to pink)

2. **Header Section**
   - DPDC logo or title
   - Subtitle: "Check Your Balance"

3. **Input Section**
   - Text field for customer ID
   - Input validation (numeric, length check)
   - Clear button

4. **Saved IDs Section** (if any exist)
   - Dropdown or list of previously saved IDs
   - Quick select functionality

5. **Action Button**
   - Large, prominent "Check Balance" button
   - Gradient background matching theme
   - Tap animation/ripple effect

6. **Loading State**
   - Circular progress indicator
   - Disable input during API call
   - Loading message

**Validation Rules**:
- Customer ID must not be empty
- Must be numeric
- Reasonable length (8-12 digits)

**User Flow**:
```
Enter Customer ID → Validate → Show Loading → Generate Token → Fetch Balance → Navigate to Results
```

---

### 6. Build Balance Display Page (Results Screen)
**File**: `lib/screens/balance_screen.dart`

**UI Layout**:

1. **Header Section**
   - Gradient background
   - Back button
   - Success icon/checkmark

2. **Balance Display (PRIMARY)**
   - **LARGE font size** (48-64pt)
   - **Bold weight**
   - Prominent placement at top
   - Format: "৳ X,XXX.XX" or "BDT X,XXX.XX"
   - Color: White or contrasting color on gradient

3. **Customer Information Cards**
   - Card-based layout with subtle shadows
   - Each card contains:
     - **Customer Name**
     - **Account ID**
     - **Customer Class**
     - **Customer Type**
     - **Connection Status** (with color indicator)
     - **Mobile Number**
     - **Email ID**
     - **Minimum Recharge**

4. **Action Buttons**
   - **Save Customer ID** button (if not already saved)
     - Opens dialog to add optional label
   - **Share** button
     - Uses `share_plus` to share formatted text
   - **Check Another** button
     - Navigate back to home screen

**Share Format**:
```
DPDC Balance Details
-------------------
Customer: {name}
Account ID: {accountId}
Balance: ৳ {balance}
Connection Status: {status}
Checked on: {date/time}
```

---

### 7. Implement Error Handling
**File**: `lib/widgets/error_dialog.dart`

**Alert Dialog Components**:
- Clear error icon
- Error title
- Descriptive error message
- Action buttons:
  - "Retry" (attempt operation again)
  - "Cancel" or "Close"

**Error Scenarios**:
1. **Token Generation Failed**
   - Message: "Unable to connect to DPDC servers. Please try again."

2. **Invalid Customer ID**
   - Message: "Customer ID not found. Please verify and try again."

3. **Network Error**
   - Message: "No internet connection. Please check your network."

4. **API Timeout**
   - Message: "Request timed out. Please try again."

5. **Server Error**
   - Message: "Server error occurred. Please try again later."

---

### 8. UI/UX Enhancements

**Color Scheme**:
- Primary gradient: Blue (#3B82F6) to Purple (#8B5CF6)
- Secondary gradient: Orange (#F97316) to Pink (#EC4899)
- Background: Gradient or solid white/light gray
- Text: White on dark gradients, dark on light backgrounds
- Accent: Green for success, Red for errors

**Animations**:
- Page transition: Slide or fade
- Button press: Scale animation
- Loading: Smooth circular progress
- Card appearance: Fade in with slight slide up

**Typography**:
- Title: Bold, 24-28pt
- Balance: Extra bold, 48-64pt
- Body: Regular, 14-16pt
- Labels: Medium, 12-14pt

**Responsive Design**:
- Mobile: Single column layout
- Tablet: Utilize extra space with larger cards
- Desktop: Centered content with max width
- Web: Add padding for large screens

---

### 9. Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── balance_details.dart     # Data model
├── services/
│   ├── dpdc_api_service.dart    # API integration
│   └── storage_service.dart     # Local storage
├── screens/
│   ├── home_screen.dart         # Customer ID input
│   └── balance_screen.dart      # Results display
└── widgets/
    └── error_dialog.dart        # Reusable error dialog
```

---

### 10. Testing Plan

**Manual Testing**:
1. Test with provided customer ID: `31719842`
2. Test with invalid customer ID
3. Test with empty input
4. Test network error handling (airplane mode)
5. Test save/load customer IDs
6. Test share functionality
7. Test on multiple platforms (web, mobile, desktop)

**Edge Cases**:
- Very long customer IDs
- Special characters in input
- Rapid repeated requests
- Token expiration
- Null/missing fields in API response

---

### 11. Future Enhancements (Optional)

- **Multi-language Support**: Bengali translation
- **Bill Payment**: Integration with payment gateways
- **Usage History**: View consumption over time
- **Notifications**: Balance alerts
- **Dark Mode**: Theme toggle
- **Biometric Auth**: For saved accounts
- **Offline Mode**: Cache last checked balance

---

### 12. Security Considerations

**Current Implementation**:
- Token is generated per request (good)
- Client credentials are in code (acceptable for public app)
- No sensitive user data stored locally

**Recommendations**:
- Do not store tokens long-term
- Clear sensitive data from memory after use
- Use HTTPS for all requests (already implemented by API)
- Validate all user inputs

---

### 13. Deployment Checklist

**Before Release**:
- [ ] Test on real devices (Android/iOS)
- [ ] Test on different screen sizes
- [ ] Verify web deployment works
- [ ] Check app icons and splash screens
- [ ] Review and update app permissions
- [ ] Test on different network speeds
- [ ] Verify error messages are user-friendly
- [ ] Performance testing (cold start, API response time)

**Platform-Specific**:
- **Android**: Update `build.gradle`, permissions, app name
- **iOS**: Update `Info.plist`, signing, app name
- **Web**: Configure base URL, favicon, meta tags
- **Desktop**: Test executable builds

---

## Quick Start Commands

```bash
# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Run on mobile (with device connected)
flutter run

# Build for release
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web
flutter build windows      # Windows
flutter build macos        # macOS
flutter build linux        # Linux
```

---

## Notes

- Customer ID example: `31719842`
- API requires both `Authorization` and `accessToken` headers with same token
- Balance is returned as a number (likely in BDT)
- Connection status indicates active/inactive account
- Some fields may be null (mobileNumber, emailId)

---

**Created**: 2025-11-10
**Last Updated**: 2025-11-10
**Version**: 1.0
