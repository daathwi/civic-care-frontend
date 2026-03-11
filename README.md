# 🏛️ CivicCare (Frontend)

**AI-Powered Civic Grievance Command Center** — Mobile & Web frontend for transparent civic governance.

This repository contains the Flutter-based frontend for the CivicCare platform. It features a role-based UI that adapts for Citizens, Field Managers, Field Assistants, and Administrators.

---

## ✨ Key Features

-   **📸 Geotagged Evidence:** Capture photos with automatic GPS coordinates.
-   **🎙️ Voice Descriptions:** Accessibility-first reporting with voice recording.
-   **📡 Real-Time Updates:** Live status tracking via WebSockets.
-   **🗺️ Interactive Maps:** OpenStreetMap integration to view and filter grievances.
-   **📊 Analytics Dashboard:** Visualized KPIs and impact metrics via `fl_chart`.
-   **👥 Role-Based Portals:** Dedicated interfaces for Citizens, Managers, and Ground Workers.

---

## 🛠️ Tech Stack

-   **Framework:** [Flutter](https://flutter.dev) (v3.11+)
-   **State Management:** [Riverpod](https://riverpod.dev)
-   **Maps:** [flutter_map](https://pub.dev/packages/flutter_map) + OpenStreetMap
-   **Charts:** [fl_chart](https://pub.dev/packages/fl_chart)
-   **Icons & Fonts:** [Google Fonts](https://pub.dev/packages/google_fonts) (Inter, Outfit)
-   **Networking:** [http](https://pub.dev/packages/http), [web_socket_channel](https://pub.dev/packages/web_socket_channel)

---

## ⚡ Quick Start

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured.
- A running instance of the [CivicCare Backend](backend/api/README.md).

### Installation
1.  **Clone the repository:**
    ```bash
    git clone https://github.com/daathwi/civic-care-frontend.git
    cd civic-care-frontend
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the application:**
    ```bash
    # For Android/iOS
    flutter run

    # For Web
    flutter run -d chrome
    ```

---

## 📑 Full Documentation

For detailed architecture, user guides, and the backend API reference, see the full [Documentation Site](docs/index.html).

---
*Built by Stack Syndicate · Digital Democracy*
