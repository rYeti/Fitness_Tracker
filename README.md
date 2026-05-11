# ForgeForm

ForgeForm is a Flutter mobile application designed to help users track their nutrition, gym progress, and overall fitness journey.  
The app combines barcode-based food calorie tracking, workout logging, and a planned trainer–client system for personalized coaching and progress tracking.

---

## Features

### Nutrition Tracking
- Scan food products using barcodes.  
- Automatically fetch nutritional information (calories, protein, fats, carbohydrates, etc.).  
- Categorize and save foods under breakfast, lunch, and dinner.  
- View total daily calorie and macronutrient intake.

### Workout Tracking
- Log exercises with sets, repetitions, and weights.  
- Track progress for each exercise over time.  
- Create and schedule workouts using a calendar-based date picker.  
- Visualize performance trends (upcoming feature).

### Trainer–Client System (Upcoming)
- Trainers can create custom workout and meal plans for their clients.  
- Clients can track progress and communicate with their trainer.  
- Shared dashboard for performance monitoring.

### Future Features
- Gamification (badges, levels, and streaks).  
- Integration with wearable fitness devices.  
- Cloud synchronization for multi-device access.

---

## Architecture Overview

The app follows a clean architecture structure to ensure maintainability, scalability, and separation of concerns.

```
lib/
 ┣ core/                  # App-wide utilities, database setup, and dependency injection
 ┣ features/
 ┃ ┣ food_tracking/       # Barcode scanning and nutrition tracking
 ┃ ┣ workout_tracking/    # Exercise logging and scheduling
 ┃ ┗ trainer/             # Trainer–client relationship (upcoming feature)
 ┣ app.dart               # Root MaterialApp setup
 ┗ main.dart              # App entry point
```

### Technologies Used
- Flutter (UI framework)  
- Drift (local database)  
- GetIt (dependency injection)  
- shared_preferences (local storage)  
- mobile_scanner (barcode scanning)  
- table_calendar (date picker and scheduling)

---

## Getting Started

### Prerequisites
- Flutter SDK: [Install Flutter](https://docs.flutter.dev/get-started/install)  
- Android Studio or Visual Studio Code  
- A connected device or emulator

### Installation
```bash
git clone https://github.com/rYeti/FitTracker.git
cd FitTracker
flutter pub get
flutter run
```

---

## Screens (In Progress)
- Barcode Scanner  
- Daily Food Overview  
- Workout Log  
- Workout Schedule Calendar  

---

## Learning and Development Focus

This project is being developed using a task-based, hands-on learning approach.  
Each feature is implemented step by step to strengthen understanding of:
- Flutter UI structure and layout  
- State management  
- Database integration using Drift  
- Clean architecture and modular code design  
- API integration and local persistence  

---

## Contributing

Contributions and suggestions are welcome.  
You can open issues or submit pull requests to help improve the application and documentation.

---

## License

This project is licensed under the MIT License.

---

## Author

**Robert Stertz**  
Junior Developer | Fitness and Health Enthusiast  
GitHub: [@rYeti](https://github.com/rYeti)
