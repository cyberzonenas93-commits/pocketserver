# PocketServer — Full Technical Report

**Document version:** 1.0  
**Project version:** 1.0.0+1  
**Date:** March 3, 2026

---

## 1. Executive Summary

**PocketServer** is a cross-platform Flutter application that turns a mobile or desktop device into a minimal HTTP file server on the local WiFi network. One device runs the app and starts the server; any other device on the same network can open the displayed URL in a browser to upload files to that device or download files from it. The app is designed for quick, cable-free file transfer between devices without cloud services or user accounts.

---

## 2. Project Overview

### 2.1 Purpose

- Provide a lightweight, local-only file transfer solution.
- Avoid cloud dependencies, authentication, or complex setup.
- Support both “send to device” (upload) and “get from device” (download, including “download all as ZIP”).
- Improve discoverability via mDNS (“PocketServer”) and a QR code for the transfer URL.

### 2.2 Target Platforms

| Platform   | Support | Notes                                                |
|-----------|---------|------------------------------------------------------|
| Android   | Yes     | Permissions: INTERNET, ACCESS_NETWORK_STATE, CHANGE_WIFI_MULTICAST_STATE |
| iOS       | Yes     | NSLocalNetworkUsageDescription, NSBonjourServices    |
| Web       | Present | Not primary; server runs in Flutter context          |
| macOS     | Present | Standard Flutter desktop target                      |
| Windows   | Present | Standard Flutter desktop target                     |
| Linux     | Present | Standard Flutter desktop target                     |

Primary use case is **mobile (Android/iOS)** as the server device, with a computer or another phone as the client via browser.

### 2.3 Technology Stack

| Layer        | Technology |
|-------------|------------|
| Framework   | Flutter (Dart SDK ^3.11.0) |
| HTTP server | shelf, shelf_router |
| State       | Provider (ChangeNotifier) |
| Network     | network_info_plus, NetworkInterface (dart:io) |
| Discovery   | mdns_responder (native), mdns_dart (fallback) |
| Storage     | path_provider, dart:io File |
| Archive     | archive (ZIP) |
| UI          | Material 3, qr_flutter |

---

## 3. System Architecture

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter App (PocketServer)                    │
├─────────────────────────────────────────────────────────────────┤
│  UI Layer                                                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  TransferPage (single screen)                               │ │
│  │  - Start/Stop server, URL display, Copy, QR code              │ │
│  │  - Receiving / Upload complete banners                       │ │
│  │  - Emulator hint (adb reverse)                               │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  State / Dependency injection                                    │
│  ┌──────────────────────┐  ┌──────────────────────────────────┐  │
│  │  TransferStorage     │  │  WiFiTransferService              │  │
│  │  (ChangeNotifier)    │  │  (ChangeNotifier)                 │  │
│  │  - items, init,      │  │  - start/stop, URL, isReceiving,  │  │
│  │    storeFile, index  │  │    mDNS, HTTP routes              │  │
│  └──────────────────────┘  └──────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│  HTTP / Network Layer                                            │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  shelf + shelf_router                                        │ │
│  │  - GET /, /api/items, /download/<id>, /download-all,         │ │
│  │    /thumbnail/<id>                                           │ │
│  │  - POST /upload (multipart)                                  │ │
│  │  - CORS middleware, request logging                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌──────────────────────┐  ┌──────────────────────────────────┐  │
│  │  mDNS (native/dart)  │  │  IP detection                     │  │
│  │  "PocketServer"      │  │  network_info_plus /              │  │
│  │  _http._tcp          │  │  NetworkInterface.list            │  │
│  └──────────────────────┘  └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │
         │ HTTP (same WiFi)
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Client (browser on computer or other device)                     │
│  - Upload form (multipart, progress), download links, ZIP          │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Data Flow

- **Start server:** User taps “Start server” → `WiFiTransferService.startServer()` → resolve IP, bind HTTP server (port 8080, fallback 8081–8090), start mDNS → UI shows URL and QR.
- **Upload:** Client POSTs multipart to `/upload` → server parses boundary, writes files via `TransferStorage.storeFile()`, updates in-memory index and JSON index file → “Receiving…” then “Upload complete” in UI.
- **Download:** Client GET `/download/<id>` or `/download-all` → server reads from `TransferStorage` and file system → streamed response.
- **List:** GET `/` returns HTML with current file list; GET `/api/items` returns JSON for programmatic use.

---

## 4. Component Specifications

### 4.1 Application Entry and Theme

**File:** `lib/main.dart`, `lib/app/theme.dart`

- **main.dart:** Instantiates `TransferStorage` and `WiFiTransferService`, wraps app in `MultiProvider`, sets `MaterialApp` theme and home to `TransferPage`.
- **theme.dart:** Centralized theme (Material 3, dark). Colors: primary `#0E0E11`, surface `#17171C`, accent `#2EE6A6`, warning `#FF6B6B`, text `#F5F5F7`. Radius 12.0.

### 4.2 Transfer Storage

**File:** `lib/services/transfer_storage.dart`

| Responsibility | Description |
|----------------|-------------|
| Persistence   | Application documents directory subdir `wifi_transfer_files/`. |
| Index         | JSON file `index.json` with version and list of item descriptors. |
| Item model    | See §4.4 (TransferItem). |
| Concurrency   | Single-threaded; no explicit locking. |
| Security      | No encryption, no authentication (documented). |

**Operations:**

- `init()`: Ensure root directory and load index.
- `storeFile(data, filename)`: Generate ID (`timestamp_micros`), derive type from extension, write file as `$id$ext`, append to `_items`, persist index, `notifyListeners()`.
- `getFilePath(itemId)`, `getThumbnailPath(itemId)`: Resolve paths from index; thumbnail currently always returns `null`.

**File type classification:** Photo (jpg, jpeg, png, gif, webp, heic, bmp), video (mp4, mov, m4v, avi, mkv, webm), else “other”.

### 4.3 WiFi Transfer Service (HTTP Server and mDNS)

**File:** `lib/services/wifi_transfer_service.dart`

**State (all exposed via getters where needed):**

- `_server`, `_serverUrl`, `_port` (default 8080), `_isRunning`
- `_mdnsServer` / `_usedNativeMdns`, `_mdnsDiscoverable`
- `_isReceiving`, `_showUploadComplete`, `_uploadCompleteTimer`
- `_maxUploadBytes = 300 * 1024 * 1024` (300 MB)

**IP resolution (order):**

1. On Android/iOS: `network_info_plus` WiFi IP.
2. Enumerate `NetworkInterface.list()`, skip `pdp_*`, `awdl0`, `utun*`; prefer `en0`/`wlan0` IPv4 non-loopback; else first non-loopback IPv4.
3. Fallback again to `network_info_plus`.
4. Final fallback: `localhost`.

**HTTP API:**

| Method + Path            | Handler            | Description |
|--------------------------|--------------------|-------------|
| GET /                    | _handleIndex       | HTML UI: upload form, file list, “Download all as ZIP”. |
| GET /api/items           | _handleList        | JSON array of items (id, name, size, type). |
| POST /upload             | _handleUpload      | Multipart form; parse boundary, save files via storage, 300 MB limit. |
| GET /thumbnail/<itemId>  | _handleThumbnail   | Serve thumbnail file if present (currently no thumbnails). |
| GET /download/<itemId>   | _handleDownload    | Stream file with attachment filename. |
| GET /download-all        | _handleDownloadAll | ZIP all stored files into `transfer-files.zip`, stream response; temp dir cleaned after 5 minutes. |

**Middleware:**

- CORS: `Access-Control-Allow-Origin: *`, allow GET/POST/OPTIONS and Content-Type.
- Logging: `debugPrint` of method and URL.

**Upload handling:**

- Sets `_isReceiving = true` before processing, `false` in `finally`; sets `_showUploadComplete` and 3-second timer. All state changes call `notifyListeners()`.

**mDNS:**

- When bound to a non-loopback IP: try native `mdns_responder` (MdnsResponder().publishService) on iOS/Android; on failure or non-mobile, use `mdns_dart` (MDNSServer). Service name `PocketServer`, type `_http._tcp`, port = server port. On stop, both native and dart mDNS are stopped.

**Port binding:**

- Prefer binding to the resolved local IP; on bind failure, fall back to `InternetAddress.anyIPv4`. If start fails and port &lt; 8090, increment port and retry `startServer()` once.

**Emulator detection:**

- `isLikelyEmulator`: Android and URL containing `10.0.2.` (emulator gateway). Used by UI to show adb reverse instructions.

### 4.4 Transfer Item Model

**File:** `lib/models/transfer_item.dart`

- **Fields:** `id`, `name`, `sizeBytes`, `type` (enum: photo, video, other), `relativePath`.
- **Serialization:** `toJson()` / `fromJson()` for index persistence and API.
- **displayName:** Getter returns `name`.

### 4.5 Transfer Page (UI)

**File:** `lib/screens/transfer_page.dart`

- **State:** `_isPhysicalDevice` (from device_info_plus) to show emulator hint only when not a physical device.
- **Layout:** AppBar “PocketServer”; column: receiving banner (spinner + “Receiving files…”), upload-complete banner (check + “Upload complete”), scrollable content (icon, status text, URL box, Copy URL, optional emulator card, mDNS note, QR code or “connect to WiFi” message, Start/Stop server button).
- **Behavior:** Copy URL to clipboard with SnackBar; Start/Stop toggles server with error SnackBar on start failure; QR shows only when `isReachableFromNetwork` (URL not localhost/127.0.0.1).

### 4.6 Web UI (Served at GET /)

- Single-page HTML with viewport and dark theme aligned to app (e.g. `#0e0e11`, `#2ee6a6`).
- **Send to device:** File input (multiple), Upload button, progress bar and status text, “Upload complete” or error message; XHR POST to `/upload` with progress; on success, reload after 1.5 s.
- **Get from device:** List of files (placeholder thumb, name as download link, size), “Download all as ZIP” link when list non-empty.
- No authentication; same WiFi is the only access control.

---

## 5. Dependencies (Detailed)

| Package            | Version / Source | Role |
|--------------------|------------------|------|
| flutter            | SDK              | UI and platform. |
| provider           | ^6.1.1           | DI and reactive state. |
| path_provider       | ^2.1.1           | Application documents directory. |
| path               | ^1.8.3           | Path manipulation. |
| shelf               | ^1.4.2           | HTTP server. |
| shelf_router        | ^1.1.4           | Routing for server. |
| network_info_plus   | ^7.0.0           | WiFi IP (Android/iOS). |
| mime                | ^1.0.6           | Multipart boundary parsing. |
| archive             | ^4.0.0           | ZIP for “download all”. |
| qr_flutter          | ^4.1.0           | QR code for server URL. |
| mdns_dart           | ^2.2.1           | mDNS fallback. |
| mdns_responder      | git (eelco2k)    | Native mDNS on iOS/Android. |
| device_info_plus    | ^12.1.0          | Physical vs emulator. |
| cupertino_icons     | ^1.0.8           | Icons. |

**Dev:** flutter_test, flutter_lints (^6.0.0). Analysis uses `package:flutter_lints/flutter.yaml`.

---

## 6. Platform Configuration

### 6.1 Android

- **Min SDK / target:** Defined in `android/app/build.gradle.kts` (not duplicated here; standard Flutter defaults).
- **Permissions:** INTERNET, ACCESS_NETWORK_STATE, CHANGE_WIFI_MULTICAST_STATE.
- **Label:** PocketServer. No special network security config; cleartext is local only.

### 6.2 iOS

- **Info.plist:** NSLocalNetworkUsageDescription (local network for file transfer), NSBonjourServices with `_http._tcp` for mDNS.
- **Display name:** PocketServer. Orientations: portrait and landscape; iPad all orientations.

---

## 7. Security and Limitations

### 7.1 Security

- **Authentication:** None. Anyone on the same WiFi can access the server.
- **Encryption:** No TLS; traffic is HTTP on the LAN.
- **Storage:** Files and index are unencrypted in app documents directory.
- **Input:** Filenames from multipart are sanitized (path separators stripped); HTML/JSON escaped in responses. Upload size capped at 300 MB.

### 7.2 Limitations

- Single upload request holds full body in memory (bounded by 300 MB).
- No thumbnail generation; `/thumbnail/<id>` always 404 from current storage implementation.
- No delete/rename in UI or API; storage is append-only from uploads.
- mDNS may not work on all networks (e.g. some guest or enterprise WiFi).
- Port range 8080–8090; no user-configurable port.
- Designed for same-WiFi use; no relay or internet access.

---

## 8. Testing and Quality

- **Linting:** `analysis_options.yaml` includes `flutter_lints`; no extra custom rules.
- **Tests:** `test/widget_test.dart` present (default Flutter widget test). No dedicated unit tests for `TransferStorage` or `WiFiTransferService` referenced in this report.
- **Manual flow:** Start server on device → open URL in browser → upload/download and “download all as ZIP”.

---

## 9. Build and Run

- **Requirements:** Flutter SDK ^3.11.0, `flutter doctor` clean for target platform.
- **Commands:**  
  - `flutter pub get`  
  - `flutter run` (device or simulator)
- **Deploy:** Standard Flutter build (e.g. `flutter build apk`, `flutter build ios`, etc.).

---

## 10. File and Directory Structure (Key)

```
lib/
  main.dart                 # Entry, providers, MaterialApp
  app/theme.dart            # AppTheme colors and darkTheme
  models/transfer_item.dart  # TransferItem + TransferItemType
  screens/transfer_page.dart
  services/
    transfer_storage.dart    # File storage + JSON index
    wifi_transfer_service.dart # HTTP server, mDNS, routes
android/ ...                # Android app and permissions
ios/ ...                    # iOS app, Info.plist (local network, Bonjour)
linux/, macos/, windows/, web/  # Other Flutter targets
pubspec.yaml
analysis_options.yaml
README.md
```

---

## 11. Conclusion

PocketServer is a minimal, same-WiFi file transfer server implemented in Flutter. It uses the shelf stack for HTTP, Provider for state, and a simple file store with a JSON index. mDNS and QR code improve discoverability; the web UI provides upload with progress and download (single file or ZIP). The design favors simplicity and local use over authentication, encryption, and multi-user features. This report describes the architecture, components, APIs, dependencies, platform setup, and security and operational limitations for maintenance and extension.
