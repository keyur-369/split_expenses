# 💰 Split Expenses - Mini Splitwise

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

**A beautiful and intuitive expense splitting application built with Flutter**

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Architecture](#-architecture) • [Contributing](#-contributing)

</div>

---

## 📖 About

**Split Expenses** is a modern, feature-rich mobile application that simplifies the process of splitting expenses among friends, roommates, or groups. Inspired by Splitwise, this app provides an elegant solution for tracking shared expenses and settling debts.

Whether you're planning a trip with friends, sharing rent with roommates, or managing group expenses, Split Expenses makes it easy to keep track of who owes what and ensures everyone pays their fair share with real-time sync and integrated payment features.

## ✨ Features In Detail

### 🎯 Core Management Features
- **Group Management**:
  - Create unlimited expense groups with custom names.
  - Multi-group dashboard to track different social circles (Trips, Home, Work).
  - Delete groups with safety confirmation to prevent data loss.
- **Smart Group Partitioning**:
  - Automatically categorizes groups into **Outstanding Receivables** (Groups where you are owed money).
  - **Outstanding Payables** (Groups where you owe money).
  - **Settled / Others** (Clean groups with no pending debts).
- **Expense Tracking**:
  - Add expenses with description, amount, and date.
  - Quick edit/delete for existing expenses.
  - Detailed history log of every transaction within a group.
- **Smart Splitting Engine**:
  - Automatically calculates equal splits among all or selected participants.
  - Handles complex fractional divisions to ensure the total is accurate.

### 💳 Payments & Settlements
- **Direct UPI Integration**:
  - One-tap icons for **Google Pay**, **Paytm**, and **PhonePe** directly on the participant card.
  - Deep-linking support to open payment apps with the exact amount and recipient details.
- **Push Notification Reminders**:
  - Group owners can send professionally crafted "Reminders" to members.
  - Integrated via **Firebase Cloud Messaging (FCM)** for real-time alerts.
- **Payment Settlement Notes**:
  - Add optional text notes when marking a payment as paid for audit trails.
  - Notes are visible to all members for transparency.
- **Comprehensive Settle Up Screen**:
  - Dedicated UI to manage who is paying whom.
  - Instant balance updates upon settlement confirmation.

### 🔐 Security & Data Sync
- **Firebase Authentication**:
  - Secure Email/Password login.
  - Mandatory Email Verification for account security.
- **Firebase App Check**:
  - Enterprise-grade protection to prevent unauthorized API access and bot traffic.
- **Real-time Cloud Sync**:
  - Data stays synchronized across multiple devices using **Cloud Firestore**.
  - Conflict resolution for simultaneous updates.
- **Local Persistence (Offline Mode)**:
  - Powered by **Hive (NoSQL)** for lightning-fast local data access.
  - Add expenses while offline; they sync automatically once connectivity is restored.

### 🎨 Premium User Experience
- **Material 3 Design System**:
  - Vibrant, modern color palettes (vibrant greens for receivables, reds for payables).
  - Modern typography using **Google Fonts (Poppins/Inter)**.
- **Advanced UI Components**:
  - **Image Cropper**: Custom crop your profile picture after selection for a perfect look.
  - **Staggered Animations**: Smooth list entrance animations for a premium feel.
  - **Glassmorphism Effects**: Subtle blur and transparency in UI cards.
- **Dynamic Dark Mode**:
  - Eye-friendly dark theme that adapts to system settings.
- **Contact Integration**:
  - Seamlessly import names and details from your phone's address book using `flutter_contacts`.

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (^3.8.1)
- [Dart SDK](https://dart.dev/get-dart) (^3.8.1)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
- [Firebase Account](https://console.firebase.google.com/)

### Installation
1. **Clone the repo**:
   ```bash
   git clone https://github.com/keyur-369/split_expenses.git
   ```
2. **Fetch packages**:
   ```bash
   flutter pub get
   ```
3. **Generate local adaptors**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
4. **Firebase Config**: Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
5. **Run**:
   ```bash
   flutter run --release
   ```

## 🏗️ Architecture Detail

### Tech Stack
- **Framework**: `Flutter` (for high-performance cross-platform UI)
- **State management**: `Provider` (for reactive UI updates)
- **Primary Database**: `Cloud Firestore` (Real-time NoSQL)
- **Local Cache**: `Hive` (Fast local storage)
- **Notification**: `FCM` (Firebase Cloud Messaging)
- **Security**: `App Check` & `Auth Service`

### Design Patterns
- **MVVM Architecture**: Clean separation between UI, Logic (Services), and Data (Models).
- **Service-Oriented**: Centralized logic for Groups, Auth, and Notifications.
- **Repository Pattern**: Abstracted data layer for seamless Offline-to-Online transitions.

## 🔧 Platform Specifics

### Android Configuration
Required Permissions (Added in `AndroidManifest.xml`):
- `READ_CONTACTS`: To import friends.
- `POST_NOTIFICATIONS`: For payment alerts (Android 13+).
- `INTERNET`: For Cloud Sync.

### iOS Configuration
Required Keys (Added in `Info.plist`):
- `NSContactsUsageDescription`: Description for contact access.
- `FirebaseAppDelegateProxyEnabled`: Set to `NO` for custom notification handling.

## 🧪 Testing Coverage
Run the full suite to verify logic:
```bash
flutter test
```

## 👨‍💻 Developed By
**Keyur Mistry**
- Dedicated to building high-quality, user-centric mobile solutions.
- GitHub: [@keyur-369](https://github.com/keyur-369)

---

<div align="center">

**If you find this project useful, please consider giving it a ⭐️**

Made with ❤️ using Flutter

</div>

---

## 🔗 Download Pre-Release Application

You can download the latest pre-release version of the application from the link below:

**👉 [Download Latest Pre-Release APK](https://github.com/keyur-369/split_expenses/releases/latest)**
