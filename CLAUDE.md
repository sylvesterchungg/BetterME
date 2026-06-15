# BetterME - Flutter Wellness App

## Project Overview

**BetterME** is a Flutter-based personal wellness and fitness tracking application that helps users monitor their physical health, mental wellbeing, and daily tasks. The app integrates Firebase for authentication and data persistence, uses Google Sign-In for convenient login, and tracks real-time health metrics via pedometer.

### Key Features
- **Authentication**: Email/password and Google Sign-In via Firebase Auth
- **User Profiles**: Custom avatars, display names, streaks, and leaderboard scores
- **Health Tracking**: Sleep hours, mood scores, water intake, and step counting
- **Task Management**: Create tasks with custom categories, due dates, reminders, and recurring options
- **Daily Logging**: Record daily sleep, mood, triggers, and emotions with notes
- **Social Features**: Add friends, view leaderboards, and compete based on scores
- **Real-time Updates**: All data syncs via Firestore streams for instant UI updates

---

## Project Structure

```
betterme/
├── lib/
│   ├── main.dart              # App entry point, Firebase init, providers setup
│   ├── theme.dart             # Material Design theme (light/dark)
│   ├── firebase_options.dart  # Firebase platform-specific config (auto-generated)
│   ├── models/
│   │   └── models.dart        # Data models (User, Task, LogEntry, Friend, TaskCategory)
│   ├── services/
│   │   └── database_service.dart  # Firestore & Firebase Storage operations
│   ├── providers/
│   │   └── app_provider.dart  # Provider state management (Auth, UI state, listeners)
│   └── screens/
│       ├── login_screen.dart
│       ├── main_screen.dart   # Tab navigation hub
│       ├── dashboard_tab.dart # Home/overview with step count & streaks
│       ├── daily_log_tab.dart # Sleep/mood logging
│       ├── health_tasks_tab.dart  # Task management
│       ├── friends_tab.dart   # Social/friends list
│       ├── profile_tab.dart   # User profile & settings
│       ├── trends_insights_screen.dart  # Charts & analytics
│       ├── personal_diary_screen.dart   # Extended notes/journaling
│       └── notifications_screen.dart    # App notifications
├── pubspec.yaml               # Dependencies & project config
└── android/, ios/, windows/   # Platform-specific files
```

---

## Architecture & Patterns

### State Management: Provider Pattern
- **AppProvider** (`app_provider.dart`) is the single source of truth for all app state
- Uses `ChangeNotifier` with `notifyListeners()` for reactive updates
- All screens consume `AppProvider` via `Provider.watch()` or `Provider.of()`
- Example:
  ```dart
  final appProvider = Provider.of<AppProvider>(context, listen: true);
  ```

### Real-time Data with Firestore Streams
- `DatabaseService` sets up stream subscriptions in `AppProvider._initUserListeners()`
- Streams are automatically canceled on logout or user switch
- Listeners update provider state which triggers UI rebuilds
- Active subscriptions:
  - User profile changes
  - Tasks (filtered by user)
  - Task categories (filtered by user)
  - Log entries (filtered by user, ordered by date descending)
  - Global leaderboard (top 10 users by score)
  - Friends list (updates when friendsIds change)

### Model Serialization
All models have:
- `toMap()` method for Firestore writes
- `fromMap(Map, String docId)` factory for Firestore reads
- Models handle type conversions (e.g., DateTime ↔ Firestore Timestamp)

---

## Key Files & Responsibilities

### `main.dart`
- Initializes Firebase with platform-specific options
- Sets up MultiProvider with AppProvider
- Configures MaterialApp theme and routes

### `app_provider.dart` (Core State Management)
**Key responsibilities:**
- Firebase Auth state listening and profile auto-creation
- Pedometer stream management for step counting
- All Firestore stream subscriptions
- Auth methods: `loginWithEmail()`, `loginWithGoogle()`, `logout()`, `registerWithEmail()`
- Task methods: `addTask()`, `toggleTask()`, `deleteTask()`, `addTaskCategory()`
- Logging methods: `addLog()`, `updateLog()`, `checkAndUpdateStreak()`
- Computed properties: `averageMood`, `averageSleep`, `taskCompletionRate`

**Important patterns:**
- Subscriptions are canceled when user logs out
- Streak logic checks logs from yesterday/today to determine continuation
- Friends stream is recreated when user's friendsIds change

### `database_service.dart` (Firestore Layer)
**Collections & operations:**
- **users**: User profiles, streaks, scores, water intake, friend IDs
- **tasks**: Task records with completion status, categories, reminders
- **taskCategories**: Custom categories per user (icon + name)
- **logs**: Sleep/mood entries with emotions and triggers
- **Leaderboard**: Streamed query of top 10 users by score

**Key patterns:**
- All writes use `set()` with `merge: true` to avoid overwriting
- Streams filter by userId for private data
- Friends stream handles up to 10 friend IDs (Firestore `whereIn` limit)
- Profile photos uploaded to Firebase Storage with userId-based paths

### `models.dart`
**Models:**
1. **User**: Profile info, streak, score, water intake, friends list
2. **Task**: Title, completion status, category, due date, reminder time, repeat interval
3. **TaskCategory**: Custom task categories with icons
4. **LogEntry**: Sleep hours, mood score, notes, triggers, emotions
5. **Friend**: Reference to friend with avatar, username, streak, activity

---

## Firebase Setup & Configuration

### Auth Methods
- **Email/Password**: Standard Firebase Auth
- **Google Sign-In**: Requires Google OAuth configuration (iOS/Android/Web)
- Auto-creates user profile on first login if none exists

### Firestore Security Rules (Recommended)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /tasks/{document=**} {
      allow read, write: if request.auth.uid == resource.data.userId;
    }
    match /taskCategories/{document=**} {
      allow read, write: if request.auth.uid == resource.data.userId;
    }
    match /logs/{document=**} {
      allow read, write: if request.auth.uid == resource.data.userId;
    }
  }
}
```

### Firebase Storage Rules (Avatars)
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /avatars/{userId}.jpg {
      allow read: if true;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

---

## Key Workflows & Patterns

### Authentication Flow
1. User enters email/password or taps Google Sign-In
2. `AppProvider.loginWithEmail()` or `loginWithGoogle()` called
3. Firebase Auth state changes → `_initAuthListener()` fires
4. If new user, `_loadOrCreateProfile()` creates default profile
5. `_initUserListeners()` sets up all data streams for that user

### Streak Logic
- Tracked in `User.streak` field in Firestore
- `checkAndUpdateStreak()` called after every log entry
- Logic: If logged yesterday AND not today → increment; if no logs yesterday/today → reset to 1
- Considers UTC date boundaries

### Task Repeat Pattern
- Task repeat intervals stored in `Task.repeatInterval` field
- Currently stored as string ("Daily", "Weekly", "Monthly", "Custom", "None")
- App reads this but doesn't yet auto-generate recurring instances
- Future enhancement: Auto-create next instances based on repeat interval

### Water Intake Tracking
- Stored as `waterIntake` and `waterGoal` on User document
- `addWaterIntake(amount)` increments intake for the day
- Displayed on dashboard with visual progress

### Step Counting via Pedometer
- `Pedometer.stepCountStream` is listened to in `_initPedometer()`
- Updates `currentSteps` in real-time
- Accessible via `AppProvider.currentSteps` in UI
- Gracefully handles permission errors and unsupported devices

---

## Dependencies

### Core Framework
- **flutter**: UI framework
- **provider**: State management
- **firebase_core**: Firebase initialization
- **firebase_auth**: Authentication
- **cloud_firestore**: Database
- **firebase_storage**: File storage for avatars
- **google_sign_in**: Google OAuth login

### Health & Tracking
- **pedometer**: Step counting (Android/iOS)

### UI & Design
- **google_fonts**: Google Fonts integration
- **fl_chart**: Charts for insights/trends
- **intl**: Internationalization and date formatting

### Image Handling
- **image_picker**: Camera/gallery image selection for profile photos

---

## Common Development Tasks

### Adding a New Feature
1. **Define Model** in `models.dart` if needed (with `toMap()` and `fromMap()`)
2. **Add Firestore Operations** in `database_service.dart` (CRUD methods and streams)
3. **Add Provider Methods** in `app_provider.dart` to manage state and call database
4. **Create Screen** in `screens/` and consume provider via `Provider.of<AppProvider>(context)`
5. **Wire Navigation** in `main_screen.dart` tabs or navigation

### Debugging Firestore Issues
- Check Firebase Console for data and permissions
- Use `debugPrint()` in listeners to verify stream updates
- Verify user UID matches in Firestore rules
- Check Network tab in Flutter DevTools

### Testing Authentication
- Use Firebase Emulator: `firebase emulators:start`
- Test flows: new user → login → logout → login again
- Verify streak resets correctly when checking logs

### Adding a New Task Category Icon
1. Choose icon from Material Icons
2. Create category with `AppProvider.addTaskCategory(name, 'icon_name')`
3. Reference icon in Task by `categoryIconKey` field

---

## Known Patterns & Conventions

### Naming
- Private methods/variables start with `_` (e.g., `_dbService`, `_initAuthListener`)
- Stream subscriptions named as `_{noun}Sub` (e.g., `_userSub`, `_logsSub`)
- Models are CapitalCase; instances are camelCase

### Error Handling
- Auth errors are handled via Firebase exceptions (not yet custom error handling)
- Firestore queries silently handle not-found documents (return null)
- Pedometer errors are logged but don't crash the app

### Future Improvements
- [ ] Implement recurring task instance generation
- [ ] Add rich notifications (local notifications for reminders)
- [ ] Implement offline sync with Firestore offline persistence
- [ ] Add dark mode support (theme.dart has skeleton)
- [ ] Add export/backup features
- [ ] Implement better error handling and user feedback
- [ ] Add analytics tracking

---

## Running the App

### Prerequisites
- Flutter SDK installed
- Firebase project created and configured
- iOS/Android/Web platform configured in Firebase Console

### Steps
```bash
cd betterme
flutter pub get
flutter run
```

For Web:
```bash
flutter run -d chrome
```

---

## Notes for Future Contributors
- Always update both `toMap()` and `fromMap()` when adding model fields
- Firestore document IDs are managed by Firebase (don't set manually)
- Streams are hot (listen once per user session, not per screen)
- The leaderboard is global and unfiltered—consider privacy implications
- Water intake is daily but currently not reset—future: implement daily reset or per-day tracking
