# shop_app (Small Shop App)

A Flutter app for basic **small shop management**:

- **User auth**: Google sign-in + Phone OTP via SMS (Firebase Auth)
- **Inventory**: add/update/delete products
- **Sales**: add sales records (amount, payment mode/platform, optional items)
- **Dashboard/Analytics**: recent sales, weekly chart, and summary views

The app uses `provider` for state management, **Firebase Authentication** for sign-in, and **Cloud Firestore** for storing shop data per user.

## Tech stack

- Flutter (Material 3)
- State management: `provider`
- Auth: Firebase Auth (Google + Phone OTP via SMS)
- Database: Cloud Firestore
- Charts: `fl_chart`

## What happens when you share the APK?

- Users install the APK → sign in with Google or Phone (SMS OTP)
- Their shop data is stored centrally in Firestore under `users/{uid}/...`
- Developers can view all data in the Firebase Console (Firestore)

## Prerequisites

- Install Flutter SDK: https://docs.flutter.dev/get-started/install
- Run `flutter doctor` and fix any issues it reports

## Firebase setup (required)

1. Create a Firebase project
2. Add an **Android app** in Firebase console
3. Download `google-services.json` and place it at `android/app/google-services.json`
	- This repo already includes a file there; replace it with yours if needed.
4. Firebase Console → Authentication → Sign-in method:
	- Enable **Google**
	- Enable **Phone**
5. Add your Android **SHA-1** fingerprint in Firebase project settings (needed for Google sign-in; Phone auth may also require it)

> Phone OTP is sent via **SMS** using Firebase Auth.

## WhatsApp OTP

WhatsApp OTP requires a backend (it can't be done securely with Firebase SMS OTP alone). See [docs/whatsapp_otp.md](docs/whatsapp_otp.md).

## Run (Windows)

From the project root:

1. Install dependencies:

	`flutter pub get`

2. Run the app:

	`flutter run -d android`

> This project targets Android for Firebase Auth/Firestore out of the box.

To see available devices:

- `flutter devices`

## Common issues

- **Google sign-in fails**: ensure SHA-1 is added in Firebase console and you downloaded the updated `google-services.json`.
- **Phone OTP issues**: check Firebase Auth Phone settings and test with a real device.
- **Windows build tools missing**: in `flutter doctor`, install Visual Studio (Desktop development with C++ workload).

## Useful Flutter resources

- Flutter docs: https://docs.flutter.dev/
- Write your first Flutter app: https://docs.flutter.dev/get-started/codelab
- Flutter cookbook: https://docs.flutter.dev/cookbook
