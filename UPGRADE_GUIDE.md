# Split Expenses App - Upgrade Guide

## 🎉 What's New in This Upgrade

### ✅ Completed Features

1. **Mobile Contacts Integration**
   - Add participants directly from your device contacts
   - Search contacts by name, email, or phone
   - Automatic import of email and phone numbers

2. **Email Support**
   - Add participants by email address
   - Email validation
   - Quick email-based participant creation

3. **Enhanced Participant Model**
   - Participants now support:
     - Name (required)
     - Email (optional)
     - Phone (optional)
     - Contact ID (for linking with device contacts)

4. **Improved UI**
   - Modern tabbed dialog for adding participants
   - Three methods: Manual entry, Contacts picker, Email entry
   - Better participant display with contact info

## 📱 Permissions Setup

### Android
Permissions have been added to `AndroidManifest.xml`:
- `READ_CONTACTS` - To access device contacts
- `WRITE_CONTACTS` - For future contact updates

### iOS
Permission description added to `Info.plist`:
- `NSContactsUsageDescription` - Explains why contacts access is needed

## 🚀 How to Use New Features

### Adding Participants from Contacts
1. Open a group
2. Go to "People" tab
3. Tap "Add Person"
4. Select "Contacts" tab
5. Search and select a contact
6. Participant is added with name, email, and phone automatically

### Adding Participants by Email
1. Open a group
2. Go to "People" tab
3. Tap "Add Person"
4. Select "Email" tab
5. Enter email address
6. Participant is created with email

### Manual Entry (Enhanced)
1. Open a group
2. Go to "People" tab
3. Tap "Add Person"
4. Select "Manual" tab
5. Enter name (required), email (optional), phone (optional)

## 🔄 Database Upgrade Path

### Current Setup
- **Local Storage**: Hive (NoSQL database)
- **Data Location**: Device storage only
- **Sync**: None

### Future: Firebase Cloud Sync (Optional)

To enable cloud sync with Firebase:

1. **Uncomment Firebase dependencies** in `pubspec.yaml`:
```yaml
firebase_core: ^3.6.0
cloud_firestore: ^5.4.4
firebase_auth: ^5.3.1
```

2. **Set up Firebase project**:
   - Create a Firebase project at https://console.firebase.google.com
   - Add Android/iOS apps to your Firebase project
   - Download configuration files:
     - `google-services.json` → `android/app/`
     - `GoogleService-Info.plist` → `ios/Runner/`

3. **Initialize Firebase** in `main.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // ... rest of your code
}
```

4. **Use FirebaseService** (template provided in `lib/services/firebase_service.dart`)

## 📦 Dependencies Added

- `flutter_contacts: ^1.1.7` - Access device contacts
- `permission_handler: ^11.3.1` - Handle runtime permissions
- `email_validator: ^2.1.17` - Validate email addresses

## 🔧 Migration Notes

### Data Migration
Your existing data is safe! The Participant model has been updated with new optional fields:
- Existing participants will continue to work
- New fields (email, phone, contactId) are optional
- No data loss during upgrade

### Hive Adapters
Hive adapters have been regenerated to support the new Participant model structure.

## 🎯 Making the App Fully Dynamic

### Current State
- ✅ Local data storage
- ✅ Contact integration
- ✅ Email support
- ✅ Enhanced participant model

### To Make It Fully Dynamic (Cloud Sync)

1. **Enable Firebase** (see above)
2. **Add Authentication**:
   - User login/signup
   - Multi-user support
   - Shared groups

3. **Real-time Updates**:
   - Use Firestore listeners
   - Automatic sync across devices
   - Live expense updates

4. **Notifications**:
   - Push notifications for new expenses
   - Email notifications (using email addresses)
   - Settlement reminders

5. **Sharing Features**:
   - Share groups via email/phone
   - Invite participants via email
   - Group collaboration

## 🐛 Troubleshooting

### Contacts Not Loading
- Check if permissions are granted
- On Android: Settings → Apps → Split Expenses → Permissions → Contacts
- On iOS: Settings → Privacy → Contacts → Split Expenses

### Email Validation Errors
- Ensure email format is correct (e.g., user@example.com)
- Check for typos

### Build Errors
- Run `flutter clean`
- Run `flutter pub get`
- Run `flutter pub run build_runner build --delete-conflicting-outputs`

## 📝 Next Steps

1. **Test the new features**:
   - Try adding participants from contacts
   - Test email-based participant creation
   - Verify data persistence

2. **Optional: Set up Firebase**:
   - Follow the Firebase setup guide above
   - Enable cloud sync for multi-device support

3. **Future Enhancements**:
   - Add participant avatars
   - Group sharing via links
   - Export expenses to CSV/PDF
   - Currency support
   - Recurring expenses

## 💡 Tips

- Use contacts for frequent participants
- Use email for participants you want to notify
- Manual entry is best for one-time participants
- Edit participant info anytime to add email/phone later

---

**Need Help?** Check the code comments or create an issue in your repository.

