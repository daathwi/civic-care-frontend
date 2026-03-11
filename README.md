# 🏛️ CivicCare (Frontend)

**AI-Powered Civic Command Center** — A premium mobile and web experience for transparent civic governance.

This repository contains the Flutter-based frontend for the CivicCare platform. It features a sophisticated, role-based user interface that adapts dynamically for Citizens, Field Managers, and Field Assistants.

---

## ✨ Key Features

-   **📸 Geotagged Reporting:** Seamlessly capture and upload grievance photos with automatic GPS coordinate embedding.
-   **🎙️ Smart Voice Complaints:** Accessibility-first reporting with integrated voice recording and playback.
-   **🗺️ Interactive Mapping:** View, filter, and track grievances on an interactive map using OpenStreetMap.
-   **👥 Role-Based Portals:**
    -   **Citizen:** Personal dashboard, community feed, and grievance history.
    -   **Manager:** Workforce overview, task assignment, and escalation tracking.
    -   **Worker:** Dedicated task list, navigation help, and resolution reporting.
-   **📊 Visual Analytics:** Real-Time KPIs and impact metrics visualized with elegant charts.
-   **🔔 Live Synchronicity:** Real-time updates and notifications powered by WebSockets.

---

## 🛠️ Tech Stack

-   **Framework:** [Flutter](https://flutter.dev) (v3.11+ / Material 3)
-   **State Management:** [Riverpod](https://riverpod.dev) (Highly reactive & scalable)
-   **Animations:** [Flutter Animations](https://pub.dev/packages/animations) & Glassmorphism
-   **Maps:** [flutter_map](https://pub.dev/packages/flutter_map) + OpenStreetMap
-   **Charts:** [fl_chart](https://pub.dev/packages/fl_chart)
-   **Networking:** [http](https://pub.dev/packages/http), [web_socket_channel](https://pub.dev/packages/web_socket_channel)
-   **Typography:** Google Fonts (Outfit, Inter)

---

## ⚡ Quick Start

### Prerequisites
1.  **Flutter SDK:** [Install Flutter](https://docs.flutter.dev/get-started/install).
2.  **IDE:** VS Code or Android Studio with Flutter plugins.
3.  **Backend:** Ensure the [CivicCare Backend](../civic-care-backend/README.md) is running.

### Installation & Run

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/daathwi/civic-care-frontend.git
    cd civic-care-frontend
    ```

2.  **Fetch dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the application:**
    ```bash
    # For Mobile (iOS/Android)
    flutter run

    # For Web
    flutter run -d chrome
    ```

---

## 🏗️ Architecture

The app follows a robust **Repository Pattern** combined with **Provider-based State Management** to ensure a clean separation between UI and business logic:
- `/lib/core`: Theming, constants, and global configurations.
- `/lib/providers`: Riverpod state providers for auth, grievances, and settings.
- `/lib/screens`: Comprehensive UI screens organized by role.
- `/lib/widgets`: Reusable, atomic UI components.

---
*Built by Stack Syndicate · Digital Democracy*
