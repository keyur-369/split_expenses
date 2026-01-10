# 📦 How to Create a GitHub Release

Follow these steps to upload the APK and AAB files to GitHub Releases:

## Step 1: Go to Your Repository

1. Open your browser and go to: https://github.com/369KeYuRmIsTrY/split_expenses
2. Make sure you're logged in to GitHub

## Step 2: Navigate to Releases

1. Click on **"Releases"** in the right sidebar (or go to the "Releases" tab)
2. Click the **"Create a new release"** button (or **"Draft a new release"**)

## Step 3: Create the Release Tag

1. **Tag version**: Enter `v1.0.0`
2. **Target**: Select `main` branch (should be selected by default)
3. Click **"Create new tag: v1.0.0 on publish"**

## Step 4: Fill in Release Details

### Release Title
```
v1.0.0 - Initial Release 🎉
```

### Release Description
Copy and paste this (or customize it):

```markdown
# 🚀 Split Expenses v1.0.0 - Initial Release

This is the first official release of **Split Expenses - Mini Splitwise**!

## 📥 Download

### For Android Users
- **APK File**: Download `split-expenses-v1.0.0.apk` below (50.2 MB)
- **App Bundle**: Download `split-expenses-v1.0.0.aab` for Play Store submission (42.9 MB)

### Installation
1. Download the APK file
2. Enable "Install from Unknown Sources" in your Android settings
3. Open the APK and tap Install
4. Start splitting expenses!

📖 [Full Installation Guide](https://github.com/369KeYuRmIsTrY/split_expenses/blob/main/releases/INSTALLATION_GUIDE.md) | 📝 [Detailed Release Notes](https://github.com/369KeYuRmIsTrY/split_expenses/blob/main/releases/RELEASE_NOTES_v1.0.0.md)

## ✨ What's New

### Core Features
- ✅ Group expense management
- ✅ Smart expense splitting
- ✅ Participant management with contact integration
- ✅ Real-time balance calculations
- ✅ Detailed expense breakdowns
- ✅ Summary and settlement views

### Authentication & Sync
- ✅ Firebase Authentication
- ✅ Cloud Firestore sync
- ✅ Offline support with Hive
- ✅ Email verification

### User Interface
- ✅ Beautiful Material Design UI
- ✅ Dark mode support
- ✅ Google Fonts integration
- ✅ Smooth animations

## 🛠️ Technical Details

- **Flutter**: 3.8.1+
- **Dart**: 3.8.1+
- **Minimum Android**: 5.0 (Lollipop)
- **APK Size**: 50.2 MB
- **AAB Size**: 42.9 MB

## 📱 Platform Support

- ✅ Android
- 🔜 iOS (coming soon)
- 🔜 Web (coming soon)
- 🔜 Desktop (coming soon)

## 🐛 Known Issues

None reported yet!

## 🔜 Coming Soon

- Multiple currency support
- Expense categories
- Receipt image upload
- Export to CSV/PDF
- Push notifications
- Unequal splitting options

## 🙏 Acknowledgments

Thank you for trying Split Expenses! If you like it:
- ⭐ Star this repository
- 📢 Share with friends
- 🐛 Report bugs
- 💡 Suggest features

**Happy Expense Splitting! 💰**

---

*Made with ❤️ using Flutter*
```

## Step 5: Upload the Release Files

1. Scroll down to the **"Attach binaries"** section
2. Click **"Attach binaries by dropping them here or selecting them"**
3. Upload these two files from `d:\flutter project\split_expenses\releases\`:
   - `split-expenses-v1.0.0.apk` (50.2 MB)
   - `split-expenses-v1.0.0.aab` (42.9 MB)
4. Wait for the files to upload (may take a few minutes)

## Step 6: Publish the Release

1. Check the box **"Set as the latest release"** (should be checked by default)
2. Leave **"Set as a pre-release"** unchecked
3. Click the green **"Publish release"** button

## Step 7: Verify

1. Go back to your repository homepage
2. You should see the release in the right sidebar
3. Click on it to verify the files are downloadable
4. Test the download link to make sure it works

## 🎉 Done!

Your release is now live! Anyone can download and install your app.

### Share Your Release

Share the release link:
```
https://github.com/369KeYuRmIsTrY/split_expenses/releases/tag/v1.0.0
```

Or the direct APK download link:
```
https://github.com/369KeYuRmIsTrY/split_expenses/releases/download/v1.0.0/split-expenses-v1.0.0.apk
```

---

## 📝 For Future Releases

When you want to release a new version (e.g., v1.1.0):

1. Build the new APK/AAB:
   ```bash
   flutter build apk --release
   flutter build appbundle --release
   ```

2. Copy to releases folder with new version:
   ```bash
   Copy-Item "build\app\outputs\flutter-apk\app-release.apk" -Destination "releases\split-expenses-v1.1.0.apk"
   Copy-Item "build\app\outputs\bundle\release\app-release.aab" -Destination "releases\split-expenses-v1.1.0.aab"
   ```

3. Create a new release on GitHub with tag `v1.1.0`
4. Upload the new files
5. Update the README.md download links to point to the new version

---

## 💡 Tips

- **Version Naming**: Use semantic versioning (MAJOR.MINOR.PATCH)
  - MAJOR: Breaking changes
  - MINOR: New features (backwards compatible)
  - PATCH: Bug fixes

- **Release Notes**: Always include:
  - What's new
  - Bug fixes
  - Known issues
  - Breaking changes (if any)

- **File Naming**: Keep consistent naming:
  - `split-expenses-v{VERSION}.apk`
  - `split-expenses-v{VERSION}.aab`

---

*Last Updated: January 10, 2026*
