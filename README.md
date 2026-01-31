# 🏪 Vyapaar - Small Shop Management App

A Flutter application for **small shop/retail management** designed specifically for Indian shopkeepers. Manage inventory, track sales, and handle credit (Udhaar) - all in one app!

---

## ✨ Features

### 🔐 Authentication
- **Google Sign-In** - Quick and secure login with your Google account
- **Phone OTP via SMS** - Firebase-powered OTP authentication
- **Profile Onboarding** - Collect shop name on first login

### 📦 Inventory Management
- Add, update, and delete products
- Track stock levels with **low stock alerts**
- Set custom low-stock thresholds
- Products automatically update stock when sales are made

### 💰 Sales Management
- Quick sale entry with product selection from inventory
- Multiple **payment modes**: Cash, UPI, Card, Pay Later (Credit)
- Platform tracking: Offline, Online, WhatsApp
- Cart-based sales with automatic total calculation
- **Credit/Udhaar sales** with customer tracking
- Delete sales with long-press

### 📊 Dashboard
- **Total Sales** - All-time earnings at a glance
- **Today's Sales** - Daily performance tracking
- **Transaction Count** - Orders completed today
- **Udhaar Overview** - Total credit outstanding
- Recent transactions list with payment mode indicators

### 💳 Udhaar/Credit Management
- **Pay Later option** in payment modes
- **Customer Ledger** - Track how much each customer owes
- **Transaction History** - View all credit sales and payments per customer
- **Record Payments** - Mark partial or full payments received
- Quick amount buttons (₹100, ₹500, ₹1000, Full Amount)
- Search customers by name or phone
- Visual indicators for credit sales

### 📴 Offline Support
- **Automatic reconnect** when connection is lost
- Visual offline status banner

### ⚙️ Profile & Settings
- Edit profile name and shop name
- View account information
- Delete account option (removes all data)

---

## 🛠️ Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform UI framework (Material 3) |
| **Provider** | State management |
| **Firebase Auth** | Authentication (Google + Phone OTP) |
| **Cloud Firestore** | Real-time database |
| **connectivity_plus** | Network status monitoring |

---

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point & routing
├── models/
│   ├── product_model.dart       # Product data model
│   └── customer_model.dart      # Customer & LedgerEntry models
├── providers/
│   ├── user_provider.dart       # User state management
│   ├── sales_provider.dart      # Sales data & calculations
│   ├── inventory_provider.dart  # Product inventory state
│   └── credit_provider.dart     # Customer credit/ledger state
├── screens/
│   ├── splash_screen.dart       # App loading screen
│   ├── login_screen.dart        # Authentication screen
│   ├── home_screen.dart         # Main navigation container
│   ├── home_view.dart           # Dashboard with stats & transactions
│   ├── inventory_screen.dart    # Product management
│   ├── add_product_screen.dart  # Add/edit products
│   ├── add_sale_screen.dart     # Create new sales
│   ├── customer_ledger_screen.dart  # All customers & dues
│   ├── customer_detail_screen.dart  # Individual customer ledger
│   └── profile_screen.dart      # User profile view
├── services/
│   ├── firestore_service.dart   # Firestore CRUD operations
│   ├── connectivity_service.dart    # Network monitoring
│   └── otp_backend_service.dart # OTP API service
├── widgets/
│   ├── custom_button.dart       # Styled button component
│   ├── custom_textfield.dart    # Styled input field
│   ├── dashboard_card.dart      # Stats card widget
│   └── offline_banner.dart      # Offline status banner
└── utils/
    └── app_theme.dart           # Colors, text styles, decorations
```

---

## 🗄️ Database Schema (Firestore)

```
users/
└── {uid}/
    ├── name: string
    ├── email: string
    ├── phone: string
    ├── shop_name: string
    │
    ├── products/
    │   └── {productId}/
    │       ├── name: string
    │       ├── price: number
    │       ├── stock: number
    │       ├── low_stock_threshold: number
    │       └── created_at: timestamp
    │
    ├── sales/
    │   └── {saleId}/
    │       ├── amount: number
    │       ├── description: string
    │       ├── payment_mode: string (Cash/UPI/Card/Pay Later)
    │       ├── platform: string (Offline/Online/WhatsApp)
    │       ├── is_credit: boolean
    │       ├── customer_id: string (if credit)
    │       ├── customer_name: string (if credit)
    │       ├── items: array [{product_id, name, price, quantity}]
    │       └── created_at: timestamp
    │
    └── customers/
        └── {customerId}/
            ├── name: string
            ├── phone: string
            ├── balance_due: number
            │
            └── ledger/
                └── {entryId}/
                    ├── type: string (sale/payment)
                    ├── amount: number
                    ├── sale_id: string (if sale)
                    └── created_at: timestamp
```

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (3.10.4 or later)
   ```bash
   flutter doctor
   ```

2. **Firebase Project** with Android app configured

3. **Android device/emulator** for testing

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

2. Add an **Android app**:
   - Package name: `com.example.shop_app`
   - Download `google-services.json`
   - Place it in `android/app/google-services.json`

3. Enable Authentication methods:
   - **Google Sign-In** ✓
   - **Phone (SMS OTP)** ✓

4. Create **Firestore Database**:
   - Start in test mode (or configure rules)

5. Add **SHA-1 fingerprint** (required for Google Sign-In):
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Copy SHA-1 and add it in Firebase Console → Project Settings → Your Apps

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd small-shop-app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Build APK

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

---

## 🐛 Troubleshooting

### Google Sign-In Fails
- Verify SHA-1 fingerprint is added in Firebase Console
- Re-download `google-services.json` after adding SHA-1
- Clean build: `flutter clean && flutter pub get`

### Phone OTP Not Received
- Test on a real device (emulators may have issues)
- Check Firebase Auth Phone settings
- Verify phone number format: `+91XXXXXXXXXX`

### Build Errors
```bash
flutter clean
flutter pub get
flutter build apk
```

---

## 📄 License

MIT License

---

<p align="center">
  Made with ❤️ for small shopkeepers in India
</p>
