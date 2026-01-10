# Firebase Setup Guide for Authentication

## 📋 Prerequisites

1. A Google account
2. Flutter project set up
3. Android Studio / Xcode (for platform-specific setup)

## 🚀 Step-by-Step Setup

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or **"Create a project"**
3. Enter project name: `Split Expenses` (or your preferred name)
4. Click **Continue**
5. (Optional) Enable Google Analytics if desired
6. Click **Create project**
7. Wait for project creation, then click **Continue**

### Step 2: Add Android App

1. In Firebase Console, click the **Android icon** (or **Add app** → **Android**)
2. Enter Android package name:
   - Find it in `android/app/build.gradle` → `applicationId`
   - Usually: `com.example.split_expenses` or similar
3. Enter app nickname (optional): `Split Expenses Android`
4. Enter debug signing certificate SHA-1 (optional for now)
5. Click **Register app**
6. Download `google-services.json`
7. Place the file in: `android/app/google-services.json`
8. Click **Next** → **Next** → **Continue to console**

### Step 3: Add iOS App (if developing for iOS)

1. In Firebase Console, click the **iOS icon** (or **Add app** → **iOS**)
2. Enter iOS bundle ID:
   - Find it in Xcode or `ios/Runner.xcodeproj`
   - Usually: `com.example.splitExpenses` or similar
3. Enter app nickname (optional): `Split Expenses iOS`
4. Click **Register app**
5. Download `GoogleService-Info.plist`
6. Place the file in: `ios/Runner/GoogleService-Info.plist`
7. Click **Next** → **Next** → **Continue to console**

### Step 4: Configure Android Build Files

1. Open `android/build.gradle` (project-level)
2. Add to `dependencies`:
```gradle
dependencies {
    // ... existing dependencies
    classpath 'com.google.gms:google-services:4.4.2'
}
```

3. Open `android/app/build.gradle` (app-level)
4. Add at the **top** of the file:
```gradle
plugins {
    // ... existing plugins
    id 'com.google.gms.google-services'
}
```

5. Ensure `minSdkVersion` is at least 21:
```gradle
android {
    defaultConfig {
        minSdkVersion 21
        // ... other config
    }
}
```

### Step 5: Configure iOS (if developing for iOS)

1. Open `ios/Podfile`
2. Ensure platform is iOS 12.0 or higher:
```ruby
platform :ios, '12.0'
```

3. Run in terminal:
```bash
cd ios
pod install
cd ..
```

### Step 6: Enable Phone Authentication in Firebase

1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Click on **Phone** provider
3. Click **Enable**
4. (Optional) Add test phone numbers for development
5. Click **Save**

### Step 7: Install Dependencies

Run in your project root:
```bash
flutter pub get
```

### Step 8: Test the App

1. Run the app: `flutter run`
2. You should see the login screen
3. Enter a phone number with country code (e.g., +1234567890)
4. Click "Send OTP"
5. Enter the OTP received via SMS
6. Click "Verify & Login"

## 🔧 Troubleshooting

### Error: "FirebaseApp not initialized"

**Solution**: Make sure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in the correct location.

### Error: "Phone number format invalid"

**Solution**: Ensure phone number includes country code (e.g., +1 for US, +91 for India).

### OTP not received

**Possible causes**:
1. Phone number format incorrect
2. Firebase Phone Auth not enabled
3. Test numbers not added (for development)
4. Network issues

**Solution**: 
- Check Firebase Console → Authentication → Sign-in method → Phone
- For testing, add your phone number to test numbers
- Ensure phone number format: +[country code][number]

### Build errors after adding Firebase

**Solution**:
1. Run `flutter clean`
2. Run `flutter pub get`
3. For Android: Rebuild project
4. For iOS: Run `cd ios && pod install && cd ..`

## 📱 Testing Phone Numbers

For development, you can add test phone numbers in Firebase Console:
1. Go to **Authentication** → **Sign-in method** → **Phone**
2. Scroll to **Phone numbers for testing**
3. Add phone number and OTP code
4. Use these during development (no real SMS sent)

## 🔐 Security Notes

- Phone authentication requires real phone numbers in production
- Firebase has quotas for free tier
- Consider implementing rate limiting for production
- Store user data securely in Firestore

## ✅ Verification Checklist

- [ ] Firebase project created
- [ ] Android app added and `google-services.json` downloaded
- [ ] iOS app added (if needed) and `GoogleService-Info.plist` downloaded
- [ ] Build files configured (Android/iOS)
- [ ] Phone authentication enabled in Firebase Console
- [ ] Dependencies installed (`flutter pub get`)
- [ ] App runs without errors
- [ ] Login screen appears
- [ ] OTP can be sent and verified

## 🎉 Next Steps

After Firebase is set up:
1. Test authentication flow
2. Set up Firestore for data sync (optional)
3. Add user profile management
4. Implement cloud sync for groups and expenses

---

**Need Help?** Check Firebase documentation: https://firebase.google.com/docs/flutter/setup

