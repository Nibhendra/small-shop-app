# 🏪 Vyapaar - Small Shop Management App

<p align="center">
  <img src="assets/images/logo.png" alt="Vyapaar Logo" width="120"/>
</p>

A comprehensive Flutter application for **small shop/retail management** designed specifically for Indian shopkeepers. Manage inventory, track sales, handle credit (Udhaar), and send WhatsApp payment reminders - all in one app!

---

## ✨ Features

### 🔐 Authentication
- **Google Sign-In** - Quick and secure login
- **Phone OTP via SMS** - Firebase-powered OTP authentication
- **Profile Onboarding** - Collect shop name, gender, address on first login

### 📦 Inventory Management
- Add, update, and delete products
- Track stock levels with **low stock alerts**
- Categorize products
- Set custom low-stock thresholds
- **Offline caching** - Products available even without internet

### 💰 Sales Management
- Quick sale entry with product selection
- Multiple **payment modes**: Cash, UPI, Card, Pay Later (Credit)
- Platform tracking: Offline, Online, WhatsApp
- Cart-based sales with automatic total calculation
- **Credit/Udhaar sales** with customer tracking
- Delete sales with long-press

### 📊 Dashboard & Analytics
- **Total Sales** - All-time earnings at a glance
- **Today's Sales** - Daily performance tracking
- **Transaction Count** - Orders completed today
- **Udhaar Overview** - Total credit outstanding
- Recent transactions list with payment mode indicators
- Weekly sales chart visualization

### 💳 Udhaar/Credit Management (NEW!)
- **Pay Later option** in payment modes
- **Customer Ledger** - Track how much each customer owes
- **Transaction History** - View all credit sales and payments per customer
- **Record Payments** - Mark partial or full payments received
- Quick amount buttons (₹100, ₹500, ₹1000, Full Amount)
- Search customers by name or phone
- Visual indicators for credit sales

### 📱 WhatsApp Integration (NEW!)
- **Send Payment Reminders** - One-tap WhatsApp message
- **Bulk Reminders** - Send to all customers with pending dues
- **Bilingual Messages** - Hindi + English reminder templates
- Pre-formatted professional messages

### 📴 Offline Mode (NEW!)
- **Local caching** with Hive database
- Products cached for offline browsing
- **Offline sales** - Add sales without internet
- **Automatic sync** - Data syncs when back online
- **Pending sync indicator** - Shows unsynced items count
- Visual offline status banner
- Manual sync option

---

## 🛠️ Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform UI framework (Material 3) |
| **Provider** | State management |
| **Firebase Auth** | Authentication (Google + Phone OTP) |
| **Cloud Firestore** | Real-time database |
| **Hive** | Local storage for offline mode |
| **connectivity_plus** | Network status monitoring |
| **url_launcher** | WhatsApp integration |
| **fl_chart** | Sales analytics charts |
| **intl** | Date/number formatting |

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
│   ├── home_view.dart           # Dashboard with cards & transactions
│   ├── inventory_screen.dart    # Product management
│   ├── add_product_screen.dart  # Add/edit products
│   ├── add_sale_screen.dart     # Create new sales
│   ├── customer_ledger_screen.dart  # All customers & dues
│   ├── customer_detail_screen.dart  # Individual customer ledger
│   ├── profile_screen.dart      # User profile view
│   └── profile_onboarding_screen.dart  # First-time setup
├── services/
│   ├── firestore_service.dart   # Firestore CRUD operations
│   ├── local_store.dart         # Hive local storage
│   ├── offline_sync_service.dart    # Offline queue & sync
│   ├── connectivity_service.dart    # Network monitoring
│   └── whatsapp_service.dart    # WhatsApp URL launcher
├── widgets/
│   ├── custom_button.dart       # Styled button component
│   ├── custom_textfield.dart    # Styled input field
│   ├── dashboard_card.dart      # Stats card widget
│   ├── weekly_chart.dart        # Sales chart widget
│   ├── offline_banner.dart      # Offline status banner
│   └── profile_settings_dialog.dart  # Settings modal
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
    ├── gender: string
    ├── address: string
    │
    ├── products/
    │   └── {productId}/
    │       ├── name: string
    │       ├── price: number
    │       ├── stock: number
    │       ├── category: string
    │       ├── low_stock_threshold: number
    │       ├── created_at: timestamp
    │       └── updated_at: timestamp
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
    │       ├── customer_phone: string (if credit)
    │       ├── items: array [{product_id, name, price, quantity}]
    │       └── created_at: timestamp
    │
    └── customers/
        └── {customerId}/
            ├── name: string
            ├── phone: string
            ├── phone_normalized: string
            ├── balance_due: number
            ├── last_sale_at: timestamp
            ├── created_at: timestamp
            ├── updated_at: timestamp
            │
            └── ledger/
                └── {entryId}/
                    ├── type: string (sale/payment)
                    ├── amount: number
                    ├── sale_id: string (if sale)
                    ├── description: string
                    ├── note: string (if payment)
                    └── created_at: timestamp
```

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (3.10.4 or later)
   ```bash
   # Check installation
   flutter doctor
   ```

2. **Firebase Project** with Android app configured

3. **Android device/emulator** for testing

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

2. Add an **Android app**:
   - Package name: `com.example.shop_app` (or your custom package)
   - Download `google-services.json`
   - Place it in `android/app/google-services.json`

3. Enable Authentication methods:
   - **Google Sign-In** ✓
   - **Phone (SMS OTP)** ✓

4. Create **Firestore Database**:
   - Start in test mode (or configure rules)
   - Location: Choose nearest region

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

APK location: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📱 App Screenshots

| Dashboard | Add Sale | Customer Ledger |
|-----------|----------|-----------------|
| Sales overview, stats cards, recent transactions | Product grid, cart, payment options | Dues list, search, WhatsApp reminders |

| Customer Detail | Inventory | Offline Mode |
|-----------------|-----------|--------------|
| Transaction history, record payments | Product list, stock management | Offline indicator, pending sync |

---

## 🔧 Configuration

### App Theme (`lib/utils/app_theme.dart`)

```dart
static const Color primaryColor = Color(0xFF6C63FF);   // Purple
static const Color secondaryColor = Color(0xFF03DAC6); // Teal
static const Color backgroundColor = Color(0xFFF7F9FC); // Light grey
static const Color errorColor = Color(0xFFB00020);     // Red
```

### WhatsApp Message Template (`lib/services/whatsapp_service.dart`)

The reminder message is bilingual (Hindi + English):

```
🙏 नमस्ते [Name] जी,

यह एक friendly reminder है कि आपके [Shop] में ₹[Amount] बकाया है।

जब भी सुविधाजनक हो, कृपया भुगतान कर दें।

धन्यवाद! 🙏

---

Hello [Name],

This is a friendly reminder that you have a pending balance of ₹[Amount] at [Shop].

Please clear the dues at your earliest convenience.

Thank you!
```

---

## 🔒 Security Rules (Firestore)

Recommended production rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /products/{productId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /sales/{saleId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /customers/{customerId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        
        match /ledger/{entryId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
      }
    }
  }
}
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

### Offline Mode Issues
- Ensure Hive is initialized in `main.dart`
- Check `LocalStore.init()` is called before `runApp()`

### WhatsApp Not Opening
- Ensure WhatsApp is installed on device
- Phone number must be in E.164 format: `+919876543210`
- Check `url_launcher` permission in AndroidManifest

### Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk
```

---

## 📋 Roadmap / Future Features

- [ ] Barcode/QR scanner for products
- [ ] Export sales reports (PDF/Excel)
- [ ] Multi-language support
- [ ] Dark mode theme
- [ ] Expense tracking
- [ ] Supplier management
- [ ] Low stock notifications (push)
- [ ] Sales targets & goals
- [ ] Backup/restore data

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License.

---

## 📞 Support

For issues or feature requests, please open an issue on GitHub.

---

<p align="center">
  Made with ❤️ for small shopkeepers in India
</p>
