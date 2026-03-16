# How to Run Flutter App

Prerequisites:
- Flutter 3.x installed
- Android Studio or VS Code
- Android emulator or physical device

Steps:
1. Open a terminal in this `flutter_app` folder
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to launch the app on your connected device or emulator

## Test Credentials

**Admin User:**
- Email: `admin@pqcapp.com`
- Password: `Admin@123456`

**Employee User:**
- Email: `employee@pqcapp.com`
- Password: `Employee@123456`

> **Note on MFA:** When logging in, the backend sends an MFA requirement. Check the Supabase database `users` table for the specific user's `mfa_secret` to generate the 6-digit TOTP code, or disable MFA in the dart code for testing.
