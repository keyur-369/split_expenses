# 💰 Split Expenses - Mini Splitwise

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

**A beautiful and intuitive expense splitting application built with Flutter**

[Features](#-features) • [Screenshots](#-screenshots) • [Installation](#-installation) • [Usage](#-usage) • [Architecture](#-architecture) • [Contributing](#-contributing)

</div>

---

## 📖 About

**Split Expenses** is a modern, feature-rich mobile application that simplifies the process of splitting expenses among friends, roommates, or groups. Inspired by Splitwise, this app provides an elegant solution for tracking shared expenses and settling debts.

Whether you're planning a trip with friends, sharing rent with roommates, or managing group expenses, Split Expenses makes it easy to keep track of who owes what and ensures everyone pays their fair share.

## ✨ Features

### 🎯 Core Features
- **Group Management**: Create and manage multiple expense groups
- **Expense Tracking**: Add, edit, and delete expenses with detailed breakdowns
- **Smart Splitting**: Automatically split expenses equally among participants
- **Participant Management**: Add participants from contacts or manually
- **Balance Calculation**: Real-time calculation of who owes whom
- **Expense Details**: View detailed breakdown of each expense
- **Summary View**: Comprehensive overview of all balances and settlements

### 🔐 Authentication & Sync
- **Firebase Authentication**: Secure email/password authentication
- **Email Verification**: Verify user email addresses for security
- **Cloud Sync**: Sync data across devices using Cloud Firestore
- **Offline Support**: Local storage with Hive for offline functionality

### 🎨 User Experience
- **Beautiful UI**: Modern, clean interface with Material Design
- **Dark Mode**: Full dark mode support
- **Google Fonts**: Beautiful typography with Google Fonts integration
- **Smooth Animations**: Polished animations and transitions
- **Contact Integration**: Import participants directly from phone contacts
- **Intuitive Navigation**: Easy-to-use navigation and user flows

### 📱 Additional Features
- **Multi-platform**: Works on Android, iOS, Web, Windows, macOS, and Linux
- **Data Persistence**: Local storage ensures data is never lost
- **Email Validation**: Built-in email validation for user registration
- **Permission Handling**: Proper permission management for contacts access
- **Responsive Design**: Adapts to different screen sizes



## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (^3.8.1)
- [Dart SDK](https://dart.dev/get-dart) (^3.8.1)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
- [Git](https://git-scm.com/)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/369KeYuRmIsTrY/split_expenses.git
   cd split_expenses
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Hive adapters**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Set up Firebase** (Optional - for authentication and cloud sync)
   
   Follow the instructions in [FIREBASE_SETUP.md](FIREBASE_SETUP.md) to configure Firebase for your project.

5. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Usage

### Creating a Group
1. Tap the **+** button on the home screen
2. Enter a group name
3. Add participants from contacts or manually
4. Tap "Create" to create the group

### Adding an Expense
1. Open a group
2. Tap the **+** button
3. Enter expense details:
   - Description
   - Amount
   - Select who paid
   - Choose participants to split with
4. Tap "Add Expense"

### Viewing Balances
1. Open a group to see the total spending
2. Tap the "Summary" tab to view:
   - Individual balances
   - Who owes whom
   - Settlement suggestions

### Managing Participants
1. Open a group
2. Tap on a participant to:
   - Edit their name
   - View their expenses
   - Delete them (if not involved in expenses)

## 🏗️ Architecture

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── expense.dart         # Expense model
│   ├── group.dart           # Group model
│   └── participant.dart     # Participant model
├── screens/                  # UI screens
│   ├── group_list_screen.dart
│   ├── group_detail_screen.dart
│   ├── add_expense_screen.dart
│   ├── expense_detail_screen.dart
│   ├── summary_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   └── verify_email_screen.dart
├── services/                 # Business logic
│   ├── group_service.dart
│   ├── auth_service.dart
│   ├── firebase_service.dart
│   ├── firestore_service.dart
│   └── contact_service.dart
├── storage/                  # Local storage
│   └── storage_service.dart
├── theme/                    # App theming
│   └── app_theme.dart
└── widgets/                  # Reusable widgets
    ├── expense_tile.dart
    └── add_participant_dialog.dart
```

### Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform UI framework |
| **Provider** | State management |
| **Hive** | Local NoSQL database |
| **Firebase Auth** | User authentication |
| **Cloud Firestore** | Cloud database |
| **Google Fonts** | Custom typography |
| **Flutter Contacts** | Contact integration |
| **Permission Handler** | Runtime permissions |
| **Email Validator** | Email validation |
| **UUID** | Unique ID generation |
| **Intl** | Internationalization & formatting |

### Design Patterns
- **Provider Pattern**: For state management
- **Service Layer**: Separation of business logic
- **Repository Pattern**: Data access abstraction
- **MVVM**: Model-View-ViewModel architecture

## 🔧 Configuration

### Firebase Setup
To enable authentication and cloud sync:
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add your app to the Firebase project
3. Download configuration files:
   - `google-services.json` for Android
   - `GoogleService-Info.plist` for iOS
4. Enable Email/Password authentication in Firebase Console
5. Set up Cloud Firestore database

Detailed instructions: [FIREBASE_SETUP.md](FIREBASE_SETUP.md)

### Permissions

#### Android
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.INTERNET" />
```

#### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSContactsUsageDescription</key>
<string>We need access to your contacts to add participants</string>
```

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  provider: ^6.1.2
  uuid: ^4.5.1
  intl: ^0.19.0
  google_fonts: ^6.3.2
  flutter_contacts: ^1.1.7
  permission_handler: ^11.3.1
  email_validator: ^2.1.17
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.14
  hive_generator: ^2.0.1
```

## 🛠️ Building for Production

### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

### Windows
```bash
flutter build windows --release
```

## 🧪 Testing

Run tests with:
```bash
flutter test
```

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Keyur Mistry**
- GitHub: [@369KeYuRmIsTrY](https://github.com/369KeYuRmIsTrY)

## 🙏 Acknowledgments

- Inspired by [Splitwise](https://www.splitwise.com/)
- Built with [Flutter](https://flutter.dev/)
- Icons from [Material Design Icons](https://material.io/resources/icons/)
- Fonts from [Google Fonts](https://fonts.google.com/)

## 📞 Support

If you have any questions or need help, feel free to:
- Open an issue on GitHub
- Contact me through GitHub

## 🗺️ Roadmap

### Planned Features
- [ ] Multiple currency support
- [ ] Expense categories and tags
- [ ] Receipt image upload
- [ ] Export data to CSV/PDF
- [ ] Push notifications
- [ ] Group chat functionality
- [ ] Recurring expenses
- [ ] Advanced splitting options (percentage, shares)
- [ ] Payment integration
- [ ] Multi-language support

## 📊 Project Status

This project is actively maintained and under development. New features and improvements are added regularly.

---

<div align="center">

**If you find this project useful, please consider giving it a ⭐️**

Made with ❤️ using Flutter

</div>
