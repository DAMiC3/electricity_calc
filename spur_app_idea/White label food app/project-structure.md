# Project Structure: white-label-food-app

```
white-label-food-app/
│
├── backend/           # All backend (server) code
│   ├── app/           # Main FastAPI application (routes, models, etc.)
│   ├── tests/         # Automated tests for backend
│   ├── requirements.txt  # List of Python dependencies
│   └── README.md      # Info about backend setup
│
├── frontend/          # All Flutter mobile app code
│   ├── lib/           # Main Dart/Flutter code (screens, widgets, logic)
│   ├── assets/        # Images, logos, fonts, etc.
│   ├── test/          # Automated tests for Flutter app
│   └── pubspec.yaml   # Flutter dependencies and assets config
│
├── docs/              # Documentation (setup guides, architecture, etc.)
│
└── README.md          # Main project overview and instructions
```

## Folder Descriptions

- **backend/**  
  All code for your Python FastAPI server. Handles things like user accounts, menu data, orders, and talking to the database.

- **frontend/**  
  All code for your Flutter mobile app. This is what users download from the app store and use to order food.

- **docs/**  
  Any documentation you want to write: setup instructions, how to add a new restaurant, how to deploy, etc.

- **README.md**  
  A summary of the whole project, how to get started, and where to find things.

---
*Status: Step 2 Complete - Ready for Step 3 (Core Features)* 