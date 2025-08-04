# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Build & Run
- `flutter run` - Run the app in debug mode
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app
- `flutter build web` - Build web version

### Code Quality
- `flutter analyze` - Run static analysis (uses analysis_options.yaml with flutter_lints)
- `flutter test` - Run unit and widget tests

### Development Tools
- `flutter clean` - Clean build artifacts
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Upgrade dependencies
- `flutter doctor` - Check Flutter environment

## Project Architecture

### App Purpose
This is a Flutter app called "Parsel Sorgulama" (Parcel Query) that helps users extract parcel/property information from Sahibinden.com listings and query them through TKGM (Turkish Land Registry) system.

### Core Flow
1. **Share Intent Handling**: App receives shared URLs from Sahibinden.com via `receive_sharing_intent` package
2. **URL Processing**: Expands shortened URLs (shbd.io) and validates Sahibinden.com links
3. **Data Extraction**: Uses WebView with JavaScript injection to extract parcel data from Sahibinden pages
4. **TKGM Integration**: Queries TKGM APIs to find administrative IDs and construct proper TKGM URLs
5. **Location Services**: Calculates distances from user location to properties using Haversine formula

### Key Components

#### Main App Structure
- **main.dart**: App entry point with share intent handling, routes to SplashScreen
- **splash_screen.dart**: Animated splash screen with 3-second delay
- **parsel_searching_screen.dart**: Main screen with URL input, WebView, and data extraction logic
- **tkgm_webview_screen.dart**: TKGM query results with distance calculations and parcel measurements

#### Core Services
- **url_expander.dart**: Utility to expand shortened URLs (shbd.io → sahibinden.com)

#### BLoC Architecture
- **ParselSearchingBloc**: Manages URL loading, data extraction, and WebView interactions
- **TkgmBloc**: Handles TKGM page loading, location services, and parcel data processing

#### Screen Flow
1. **SplashScreen** → 2. **ParselSearchingScreen** → 3. **TKGMWebViewScreen**

### Key Dependencies
- `flutter_inappwebview: ^6.0.0` - WebView implementation for both URL loading and TKGM display
- `receive_sharing_intent: ^1.8.1` - Handle incoming shared URLs from other apps
- `geolocator: ^13.0.0` - Location services for distance calculations
- `http: ^1.4.0` - API calls to TKGM services
- `html: ^0.15.6` - HTML parsing if needed
- `flutter_bloc: ^8.1.6` - State management using BLoC pattern
- `equatable: ^2.0.6` - Simplifies BLoC state comparisons

### API Integration
- **TKGM APIs**: 
  - `https://parselsorgu.tkgm.gov.tr/app/modules/administrativeQuery/data/ilListe.json` - Province list
  - `https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/ilceListe/{ilId}` - District list
  - `https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/mahalleListe/{ilceId}` - Neighborhood list
  - `https://cbsapi.tkgm.gov.tr/megsiswebapi.v3/api/parsel/{mahalleId}/{adaNo}/{parselNo}` - Parcel data

### Data Extraction Logic
The app extracts parcel information from Sahibinden.com by:
1. Loading the URL in WebView
2. Injecting JavaScript to access `pageTrackData.customVars`
3. Extracting: il (province), ilce (district), mahalle (neighborhood), adaNo (block), parselNo (parcel)
4. Converting these to TKGM administrative IDs via API calls
5. Constructing TKGM URL: `https://parselsorgu.tkgm.gov.tr/#ara/idari/{mahalleId}/{adaNo}/{parselNo}`

### Location Features
- Distance calculation using Haversine formula
- Road distance estimation with terrain factors
- Parcel edge length calculations from coordinate geometry
- Turkey-specific geographic adjustments for distance estimates

### UI/UX Features
- Step indicator showing process progress
- Animated buttons with pulse effects
- Collapsible detail cards
- WebView show/hide toggle
- Material 3 design with custom theming