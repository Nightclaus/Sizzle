# Sizzle: A Collaborative Task Management Platform

Sizzle is a modern, cross-platform application designed to streamline task and team management for dynamic work environments, such as farms, tutor houses, or small businesses. It provides a real-time, collaborative platform for creating, assigning, and tracking tasks, ensuring accountability and clear communication across teams.

Built with Flutter and powered by Google Firebase, Sizzle offers a seamless experience on both web and mobile devices.

<!-- It's highly recommended to replace this with an actual screenshot of your app -->
![Sizzle App Screenshot](https://i.imgur.com/your-screenshot-url.png) 

## Table of Contents

- [Core Features](#core-features)
- [Intended Purpose & Problem Solved](#intended-purpose--problem-solved)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [1. Firebase Setup](#1-firebase-setup)
  - [2. Flutter Configuration](#2-flutter-configuration)
  - [3. Environment Variables](#3-environment-variables)
  - [4. Run the Application](#4-run-the-application)
- [How it Works: Automatic Document Creation](#how-it-works-automatic-document-creation)
- [Key Architectural Concepts](#key-architectural-concepts)

## Core Features

*   **Workspace Management:** Create separate, secure workspaces for different teams. Invite members with a unique join code.
*   **User-Centric Task Board:** A powerful Kanban-style task view where columns represent team members, showing a clear overview of who is assigned to what.
*   **Personal Task Dashboard:** A private Kanban board for users to manage their own personal to-do lists and tasks.
*   **Clipboard Aggregator:** A unique dashboard that aggregates all tasks relevant to a user—both personal and assigned from multiple workspaces—into a single, manageable grid.
*   **Real-Time Collaboration:** Powered by Firestore, all task assignments, updates, and communications happen in real-time across all devices.
*   **Comprehensive Audit Trail:** Every significant action within a workspace is logged with a timestamp, description, and the responsible user, ensuring full accountability.
*   **Secure Authentication:** Supports standard Email/Password login as well as Google Sign-In for seamless and secure access.
*   **Cross-Platform:** A single codebase delivers a consistent experience on Web, Android, and iOS.

## Intended Purpose & Problem Solved

Sizzle was designed to solve the common communication and accountability gaps found in teams that operate in shifts or across different locations. In environments like farms or tutoring centers, crucial tasks can be missed, duplicated, or miscommunicated between shifts. The lack of a central, persistent "source of truth" leads to inefficiency and errors.

This application solves this by providing:
1.  **A Persistent Digital Record:** Tasks and their statuses are stored centrally, accessible to all team members at any time.
2.  **Clear Accountability:** The user-centric Kanban board makes it immediately obvious who is responsible for each task.
3.  **An Immutable Audit Trail:** The logging system provides a complete history of all actions, which is invaluable for management and for resolving disputes.
4.  **A Bridge Between Personal and Team Responsibilities:** The Clipboard allows users to see their entire workload in one place, helping them prioritize and manage their time effectively.

## Tech Stack

*   **Framework:** [Flutter](https://flutter.dev/) (v3.x.x)
*   **Language:** [Dart](https://dart.dev/)
*   **Backend & Database:** [Google Firebase](https://firebase.google.com/)
    *   **Firestore:** Real-time NoSQL database for all application data.
    *   **Firebase Authentication:** For secure user management.
*   **State Management:** [GetX](https://pub.dev/packages/get)
*   **Key Packages:** `get`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`, `dotted_border`.

## Getting Started

Follow these steps to set up and run the Sizzle project on your local machine.

### Prerequisites

*   You must have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
*   You must have a code editor like [Visual Studio Code](https://code.visualstudio.com/) or [Android Studio](https://developer.android.com/studio) installed.
*   You need a Google account to create a Firebase project.

### 1. Firebase Setup

This application requires a Firebase project to function.

1.  **Create a Firebase Project:** Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
2.  **Enable Services:**
    *   In the project dashboard, go to **Authentication** -> **Sign-in method** and enable **Email/Password** and **Google**.
    *   Go to **Firestore Database** and create a new database. Start in **test mode** for easy setup (you can secure it later with the provided rules).
3.  **Register Your Apps:**
    *   You need to register at least one app (Web, Android, or iOS). Follow the on-screen instructions in **Project Settings** -> **General**.
    *   For **Web**, Firebase will give you a configuration object.
    *   For **Android/iOS**, you will need to download a `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) file.
4.  **Install the Firebase CLI:** If you haven't already, [install the Firebase CLI](https://firebase.google.com/docs/cli#install_the_cli) on your machine.
5.  **Configure FlutterFire:** In your terminal, at the root of this project folder, run the following command. This will automatically connect your Flutter app to your Firebase project.

    flutterfire configure
    
    Follow the prompts to select your Firebase project and the apps you registered.

### 2. Flutter Configuration

Once Firebase is configured, get the necessary Flutter packages.

    flutter pub get

### 3. Environment Variables

For Google Sign-In on the web, you need to provide your Google Client ID.

1.  Create a file named `.env` in the root of the project.
2.  Add your Google Client ID (found in your Firebase project settings or Google Cloud Console) to this file:
    ```
    GOOGLE_CLIENT_ID=your-google-client-id-goes-here.apps.googleusercontent.com
    ```

### 4. Run the Application

You are now ready to run the app.

    flutter run

Select the device (e.g., Chrome for web, an emulator for mobile) you wish to run on.

## How it Works: Automatic Document Creation

The Sizzle application is designed to be self-initializing. You **do not** need to manually create any collections or documents in Firestore before running the app for the first time.

*   **On User Sign-Up:** The `AuthController` automatically detects a new user. If their profile document (`/UserData/{userId}/ProfileData/main`) is missing, it will prompt them to create it.
*   **On Workspace Creation:** The `WorkspacesController` creates the main workspace document, its `members` array, and the user's reference to it.
*   **On Task Creation:** The `TasksController` creates the task document in the correct subcollection (`/UserData/{userId}/Tasks` or `/Workspaces/{workspaceId}/Tasks`).
*   **On First Categorization:** The `ClipboardController` automatically creates a "Checkbox" document the first time a user drags a task into a new category.

This "lazy-initialization" approach ensures that the database remains clean and only contains the data structures that are actively needed by users.

## Key Architectural Concepts

*   **MVVM with GetX:** The project strictly follows the Model-View-ViewModel pattern, where GetX Controllers act as the ViewModel, separating business logic from the UI (View).
*   **Global Services:** A `WorkspaceService` is used to manage the globally selected workspace, making the application's context available everywhere without direct controller-to-controller communication.
*   **General Purpose Widgets (GPW):** A suite of custom, reusable widgets (`GPFormDialog`, `GPSelectableCard`, `GPColumn`) were created to accelerate UI development and ensure a consistent user experience.
*   **Dual-Mode Controller:** The `TasksController` is a powerful, reusable component that can operate in two modes ("Personal" or "Workspace") based on a boolean flag, allowing it to power two different screens with the same core logic.