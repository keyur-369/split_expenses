# 📥 Installation Guide

## Download Split Expenses v1.0.0

### 🤖 Android

#### Option 1: Direct APK Download (Recommended for Testing)
1. Download the APK file: `split-expenses-v1.0.0.apk` (50.2 MB)
2. Transfer it to your Android device
3. Follow the installation steps below

#### Option 2: From GitHub Releases
1. Go to [Releases](https://github.com/369KeYuRmIsTrY/split_expenses/releases)
2. Download the latest `split-expenses-v1.0.0.apk`
3. Follow the installation steps below

---

## 📲 Installing the APK on Android

### Step-by-Step Instructions

#### For Android 8.0 and above:
1. **Download the APK** to your device
2. **Open the APK file** from your Downloads folder or notification
3. You'll see a prompt: "For your security, your phone is not allowed to install unknown apps from this source"
4. Tap **Settings**
5. Enable **Allow from this source**
6. Go back and tap **Install**
7. Wait for installation to complete
8. Tap **Open** to launch the app

#### For Android 7.0 and below:
1. **Download the APK** to your device
2. Go to **Settings** → **Security**
3. Enable **Unknown Sources** (or **Install from Unknown Sources**)
4. Tap **OK** on the warning dialog
5. **Open the APK file** from Downloads
6. Tap **Install**
7. Wait for installation to complete
8. Tap **Open** to launch the app

---

## 🔒 Security Notice

### Why does Android show a warning?

Android shows a security warning when installing apps from outside the Google Play Store. This is a standard security feature to protect users.

**This app is safe because:**
- ✅ Open source code available on GitHub
- ✅ Built using official Flutter SDK
- ✅ No malicious code or hidden permissions
- ✅ Source code can be reviewed by anyone
- ✅ Built and signed properly

### Permissions Explained

The app requests the following permissions:

| Permission | Why We Need It | Required? |
|------------|----------------|-----------|
| **Internet** | For Firebase authentication and cloud sync | Optional* |
| **Contacts** | To import participants from your phone | Optional |

*Internet is only required if you want to use the login feature and sync data across devices. The app works fully offline without login.

---

## 🚀 First Launch

### What to Expect

1. **Splash Screen**: You'll see the app logo briefly
2. **Login/Skip**: Choose to login with email or skip for local use
3. **Permissions**: Grant contacts permission if you want to import participants
4. **Ready to Use**: Start creating groups and adding expenses!

### Tips for First-Time Users

- **Skip Login**: You can use the app without creating an account (data stays local)
- **Create Account**: Sign up to sync data across devices
- **Import Contacts**: Grant contacts permission to quickly add participants
- **Explore**: Try creating a test group to see how it works

---

## 🔄 Updating the App

When a new version is released:

1. **Download** the new APK file
2. **Install** over the existing app
3. Your data will be **preserved**
4. New features will be available immediately

> **Note**: Always download updates from the official GitHub repository

---

## ❓ Troubleshooting

### Installation Failed
- **Problem**: "App not installed"
- **Solution**: Make sure you have enough storage space (at least 100 MB free)

### Can't Find APK
- **Problem**: Downloaded APK disappeared
- **Solution**: Check your Downloads folder or use a file manager app

### Installation Blocked
- **Problem**: Can't enable "Unknown Sources"
- **Solution**: Some devices have additional security settings. Check your device manufacturer's documentation

### App Crashes on Launch
- **Problem**: App closes immediately after opening
- **Solution**: 
  1. Clear app data: Settings → Apps → Split Expenses → Storage → Clear Data
  2. Reinstall the app
  3. Make sure your Android version is 5.0 or higher

### Firebase Not Working
- **Problem**: Can't login or register
- **Solution**: 
  1. Check your internet connection
  2. Make sure you're using a valid email address
  3. Try skipping login and using the app locally

---

## 🗑️ Uninstalling

To uninstall the app:

1. Go to **Settings** → **Apps**
2. Find **Split Expenses**
3. Tap **Uninstall**
4. Confirm

> **Note**: Uninstalling will delete all local data. If you're logged in, your data is backed up in the cloud.

---

## 📱 System Requirements

### Minimum Requirements
- **OS**: Android 5.0 (Lollipop) or higher
- **RAM**: 2 GB
- **Storage**: 100 MB free space
- **Internet**: Optional (required for login and sync)

### Recommended
- **OS**: Android 8.0 (Oreo) or higher
- **RAM**: 4 GB or more
- **Storage**: 200 MB free space
- **Internet**: WiFi or mobile data for cloud features

---

## 🆘 Need Help?

### Get Support

- **GitHub Issues**: [Report a bug](https://github.com/369KeYuRmIsTrY/split_expenses/issues)
- **Documentation**: [Read the README](https://github.com/369KeYuRmIsTrY/split_expenses#readme)
- **Release Notes**: [Check what's new](./RELEASE_NOTES_v1.0.0.md)

### Before Reporting Issues

Please check:
1. You're using the latest version
2. Your device meets minimum requirements
3. You've tried reinstalling the app
4. The issue hasn't been reported already

---

## 🎉 Enjoy!

You're all set! Start splitting expenses with friends and family.

**Happy Expense Tracking! 💰**

---

*Last Updated: January 10, 2026*  
*Version: 1.0.0*
