# BetterME: An Integrated Cross-Platform Wellness and Productivity Ecosystem

BetterME is an integrated, cross-platform mobile application designed specifically for young adults and university students. It addresses the fragmentation in the digital wellness market by consolidating sleep logging, emotional state tracking, hydration monitoring, and daily task management into a single, cohesive interface. By repurposing the smartphone into a tool for structured self-improvement, BetterME promotes positive digital wellbeing through "Calm Technology" principles.

## Problem & Solution

The current digital wellness market forces users to navigate a disconnected ecosystem of specialized apps—one for sleep, another for mood, and a third for productivity. This fragmentation creates a heavy cognitive burden and obscures the relationships between biological states, emotional wellbeing, and task performance, leading to high user abandonment. BetterME solves this by offering a unified three-in-one interface that integrates multiple tracking domains into a single reflective feedback loop.

## Core Features

* **Daily Wellness Logging:** Granular mood tracking (using 1.0 to 10.0 sliders and emojis), sleep tracking (by hours or time), and hydration monitoring.


* **Task Management:** Integrated productivity tracking to contextualize daily tasks alongside biological and emotional states.


* **Symptom Tracking:** Log and rate the severity (Mild to Severe) of conditions such as Anxiety, Fatigue, Headache, Nausea, and Pain.


* **AI-Powered Insights:** Integrates the Google Gemini API (gemini-3.5-flash-lite) to act as a "digital mirror," translating rolling weekly self-reported data into personalized, plain-language wellness insights and coping suggestions.


* **Gamification & Social Accountability:** Habit consistency tracking through streaks, social leaderboards, and friend interactions to encourage sustained engagement.



## System Architecture

BetterME utilizes a **two-tier, cloud-connected reactive architecture**. To reduce operational complexity and infrastructure costs, the system deliberately eschews a traditional middle-tier application server, executing all business logic directly on a "thick client".

* **Presentation Layer (Reactive Component-Based UI):** Built with the Google Flutter framework and Dart. It employs a declarative, reactive widget architecture where the UI dynamically rebuilds based on state changes.


* **State Management (Provider Pattern):** Utilizes the Provider package (with `ChangeNotifier` in classes like `AppProvider`) to decouple business logic from the user interface.


* **Data and Cloud Layer (Backend-as-a-Service):** Powered by Google Firebase on the Spark tier. It uses Cloud Firestore, a NoSQL document database, for flexible data persistence. The application relies on real-time gRPC streams (WebSockets) to instantly push database mutations to the client, bypassing the need for REST API polling.


* **External SaaS Dependency:** Generative AI capabilities are supplied externally by the Google Gemini API.



## Sustainable Development Goals (SDG) Alignment

* **SDG 3 (Good Health and Well-being):** Aligns with Target 3.4 by offering preventative self-management tools to help users track well-being factors associated with stress and mental health.


* **SDG 9 (Industry, Innovation, and Infrastructure):** Drives user-centric mobile health innovation by resolving "app fragmentation" through a novel unified interface built on modern cross-platform framework infrastructure.



## Disclaimer

BetterME is designed strictly as a self-management wellness tool and is not a medical device. It is limited in its capacity to diagnose or treat clinical disorders (such as chronic insomnia, depression, or anxiety), and the data generated should not be used as a substitute for professional medical advice.

## Getting Started

### Prerequisites

* Flutter SDK (Latest stable version)
* Dart SDK
* Firebase CLI
* Visual Studio Code (Recommended IDE)



### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/BetterME.git

```


2. Navigate to the project directory:
```bash
cd BetterME/betterme

```


3. Install Flutter dependencies:
```bash
flutter pub get

```


4. Set up Firebase:
* Ensure your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are placed in their respective directories according to standard Firebase setup.


5. Run the app:
```bash
flutter run

```
