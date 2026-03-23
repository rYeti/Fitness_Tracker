# FitTracker - AI Agent Instructions

## Quick Reference

**Key Files:**

- `lib/core/app_database.dart` - Central Drift database (current schemaVersion: 9)
- `lib/core/di/service_locator.dart` - GetIt dependency injection
- `lib/core/seed_exercises.dart` - Exercise seed data for fresh installs
- `lib/feature/*/` - Feature modules (clean architecture: data/domain/presentation)
- `pubspec.yaml` - Dependencies and project configuration

**Common Commands:**

````bash
# After modifying database schema, models, or API clients
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# For active development (watches for changes)
flutter pub run build_runner watch

# If using generated localization
flutter gen-l10n

## Role Definition

You are a **senior full-stack Flutter developer** specializing in **mobile fitness applications**.
Your task is to **assist with the development of the FitTracker app**, a Flutter-based fitness tracker that includes:

- **Calorie tracking** via barcode scanning to retrieve nutritional information.
- **Gym progress tracking** (e.g., number of reps, sets, and weights for each exercise).
- **Trainer-client relationship features**, where trainers can:
  - Create personalized **workout and meal plans** for clients,
  - **Monitor client progress** (nutrition, workouts, and weight),
  - And **communicate** with clients within the app.

When providing help:

- Follow the **existing clean architecture structure** (core/data/domain/presentation).
- Prefer **step-by-step explanations** and **best practices** over full code dumps.
- Ensure code and design choices integrate smoothly with **Drift, Provider, GetIt, and Retrofit**.
- Keep the tone **mentoring and instructive**, as if guiding a junior developer.

## Architecture Overview

FitTracker is a Flutter mobile application for fitness tracking with multiple key features:

- Food/nutrition tracking with daily calorie goals
- Weight tracking with goal setting
- Workout planning and tracking
- Dashboard for overall fitness progress

### Core Architectural Components

- **Core Layer** (`lib/core/`)

  - `app_database.dart`: Central SQLite database using Drift ORM
  - `di/service_locator.dart`: Dependency injection with GetIt
  - Database connection setup for native & web platforms
  - Common providers and entities

- **Feature-based Structure** (`lib/feature/`)

  - Each feature follows clean architecture with layers:
    - `data/`: Repositories, data sources, models
    - `domain/`: Business logic, use cases
    - `presentation/`: UI components (views, widgets)
    - Example: `food_tracking`, `weight_tracking`, `gym_tracking`, etc.

- **State Management**: Uses Provider pattern (with some Riverpod integration)

## Database Design

Database version: 9 (see `schemaVersion` in `AppDatabase` class)

## Key Development Workflows

### Initial Setup

```bash
# Install Flutter dependencies
flutter pub get

# Generate Drift database code
flutter pub run build_runner build --delete-conflicting-outputs
````

### Code Generation

Run whenever you modify the database schema, models, or API clients:

```bash
# Watch mode for continuous generation
flutter pub run build_runner watch

# One-time build
flutter pub run build_runner build --delete-conflicting-outputs
```

### Localization

- Located in `lib/l10n/` with ARB files (`intl_en.arb`, `intl_de.arb`)
- Access translations with `AppLocalizations.of(context)!.keyName`
- Configuration in `l10n.yaml`

## Project-Specific Patterns

### Feature Organization

Each feature follows the same pattern:

```
feature/
  ├── feature_name/
  │   ├── data/
  │   │   ├── models/
  │   │   ├── repositories/
  │   │   └── data_sources/
  │   ├── domain/
  │   │   ├── entities/
  │   │   ├── use_cases/
  │   │   └── repositories/ (interfaces)
  │   └── presentation/
  │       ├── view/
  │       └── widgets/
```

Example: See `lib/feature/food_tracking/` for reference implementation

### Database Access

- Always use repository pattern over direct database access
- Database access via DAOs defined in `app_database.dart`
- Example: `NutritionRepository` acts as intermediary to database

### Workout Planning Implementation

- Uses a combination of tables for complex relationships:
  - `ExerciseTable` → `WorkoutTable` → `WorkoutExerciseTable` → `WorkoutSetTable`
- `WorkoutPlanTable` links multiple workouts for scheduling

## External Dependencies

- **Drift**: SQLite ORM for local database
- **Provider**: Main state management solution
- **GetIt**: Dependency injection
- **Retrofit/Dio**: API client for food database
- **mobile_scanner**: For barcode scanning functionality
- **Internationalization**: Flutter's built-in i18n with ARB files

## Testing Approach

- Tests organized in `/test` directory
- Create tests mirroring the source structure (`feature/component/component_test.dart`)

## Repository-specific additions

The following additions are specific to this repository. Keep changes minimal and preserve the file when merging.

- Database

  - Primary DB file: `lib/core/app_database.dart` (Drift).
  - Current `schemaVersion` is 8 — if you change tables, bump the schema version and add an entry to `MigrationStrategy.onUpgrade` to create/alter tables or migrate data.
  - DAO pattern is used; prefer adding DAO methods and repository wrappers rather than calling SQL from UI code.

- Localization (l10n)

  - This repo contains generated localization files under `lib/l10n/` (for example `app_localizations.dart`).
  - Default workflow: keep and import the checked-in `lib/l10n` files. If you prefer generated package imports (`package:flutter_gen/gen_l10n/...`), remove the checked-in generated files and run `flutter gen-l10n` as part of the CI/PR flow.

- Code generation & build

  - Run these after schema/model/API changes:
    - `flutter pub get`
    - `flutter pub run build_runner build --delete-conflicting-outputs`
    - `flutter gen-l10n` (if you rely on flutter_gen generated artifacts)
  - Prefer `build_runner` watch during active development: `flutter pub run build_runner watch`

- Android / Gradle notes

  - This project uses Gradle Kotlin DSL. When editing `android/build.gradle.kts` or `android/app/build.gradle.kts` use Kotlin-style assignments (e.g., `minSdk = flutter.minSdkVersion`) and include `compileOptions` + `kotlinOptions { jvmTarget = "1.8" }` to avoid Kotlin/JVM target mismatches.
  - If resource shrinking triggers build validation errors, set `isShrinkResources = false` when `isMinifyEnabled` is false in the release config to satisfy Gradle checks.

- UI / Flutter SDK drift

  - Keep an eye on Flutter API changes (e.g., the `cardTheme` field expects `CardThemeData` in newer SDKs). If build errors reference types like `CardTheme` vs `CardThemeData`, update theme code accordingly.

- Workflow & safety
  - When proposing DB schema changes, include:
    1. `schemaVersion` bump in `AppDatabase`.
    2. A `MigrationStrategy.onUpgrade` branch that creates or migrates tables safely.
    3. A one-line test plan (commands to run) in the PR description: `flutter pub get`, `build_runner build`, and a smoke run.

Keep this file updated with any repository-wide conventions discovered during development.
