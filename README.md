# Immy App 🧸✨

A Flutter mobile application for **Immy**, the AI-powered teddy bear that helps children express themselves through conversation. The Immy App allows guardians to view and monitor these interactions in a meaningful and user-friendly way.

---

## 📱 Overview

Immy App connects with the **Immy Brainy Bear** to log conversations and present insightful data for parents or guardians. It's designed to foster better understanding and emotional awareness between children and their caregivers.

---

## 🔑 Features

- 🧠 **AI Conversation Logging**: Securely syncs and displays logs of conversations between the child and Immy.
- 📊 **Insights Page**: Presents key insights and summaries from conversations.
- 🏠 **Home Page**: The central hub for navigating the app.
- 🧑‍🏫 **Coach Page**: Offers helpful guidance and tips based on the child’s interactions.
- 💳 **Payments Page**: Handles subscription and payment management.
- ⚙️ **Settings Page**: Allows customization and app preferences.
- 📜 **Terms & Conditions / Terms of Service**: Legal documentation presented within the app.
- 🧩 **Subscription Banner Widget**: Prominently displays subscription status or promotions.

---


##   Project structure
   lib/
├── main.dart
├── models/
│   ├── user_profile.dart
│   └── serial_number.dart
├── services/
│   ├── api_service.dart
│   ├── serial_service.dart
│   └── auth_service.dart 
|   └── users_auth_service.dart 
|
├── screens/
│   ├── home_page.dart
│   ├── settings_page.dart
│   ├── insights_page.dart
│   ├── coach_page.dart
│   ├── serial_management_screen.dart
│   ├── serial_lookup_screen.dart
│   └── terms_of_service_page.dart
└── widgets/
    ├── serial_info_card.dart
    ├── qr_display.dart
    └── subscription_banner.dart

## 🧩 Current Screens

- `home_page.dart`
- `coach_page.dart`
- `insights_page.dart`
- `payments_page.dart`
- `settings_page.dart`
- `terms_and_conditions_page.dart`
- `terms_of_service_page.dart`
- `login_screen.dart`
- `register_screen.dart`
- `admin_login_screen`
- `admin_dashboard_screen`
- `serial_management_screen`
- `serial_lookup_screen`

### Custom Widgets
- `subscription_banner.dart`

---

## 🛠️ Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0 <4.0.0)
- Dart

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/omara2001/immy_app.git
   cd immy_app
2. Get dependencies
   flutter pub get
3. Run the app
   flutter run

### Authentication process is handled by users_auth_service and backend_api_service 
  ##### steps to use

1. check the backend_api_service.dart code for the api end points
  

2. try to register by your email then you can access immy_App

3. Now you can sign in by your Account that you created your email and your password to immy_App  


📂 Assets
- assets/immy_BrainyBear.png: Used within the UI to represent the Immy character.
 
📦 Dependencies
flutter

cupertino_icons

shared_preferences

flutter_svg

flutter_icons_null_safety

🧪 Testing
Use the Flutter test framework:
flutter test

📃 License
This project is currently not published and remains private.

🚀 Future Features (Planned)
Voice playback of recorded conversations.

Parental dashboard with emotion analysis.

Real-time chat monitoring with alerts.

Multi-child profiles and settings.

👩‍💻 Author / Maintainers
Made with ❤️ by CF team.