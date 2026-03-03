# PocketServer

A minimal Flutter app that lets you transfer files between devices on the same WiFi. One device runs the app and starts the server; any other device on the same network can open the shown URL in a browser to upload files to the device or download files from it.

## Features

- **Start/stop server** – Run an HTTP server on your phone/tablet.
- **Web UI** – From a computer (or another device) on the same WiFi, open the URL in a browser to:
  - **Send to device** – Upload files (with progress bar).
  - **Get from device** – List and download files, or download all as ZIP.
- **Receiving / complete indicators** – On the device running the app: “Receiving files…” while an upload is in progress, then “Upload complete” for a few seconds.
- **mDNS** – Discoverable as “PocketServer” on the local network where supported.
- **QR code** – Scan to open the transfer URL on another device.

## How to run

1. **Flutter**: Ensure Flutter is installed (`flutter doctor`).
2. **Get dependencies**: `flutter pub get`
3. **Run**: `flutter run` (iOS/Android simulator or device).

On the device, tap **Start server**, then on your computer open the shown URL (e.g. `http://192.168.1.x:8080`) in a browser. Upload or download files as needed.

## Project structure

- `lib/main.dart` – App entry, provides `TransferStorage` and `WiFiTransferService`.
- `lib/screens/transfer_page.dart` – Single screen: server control, URL, copy, QR, receiving/complete banners.
- `lib/services/wifi_transfer_service.dart` – HTTP server (shelf), routes (/, /upload, /download, /download-all, /thumbnail, /api/items), mDNS, IP detection.
- `lib/services/transfer_storage.dart` – Simple file storage (application documents directory + JSON index). No encryption, no auth.
- `lib/models/transfer_item.dart` – Model: id, name, size, type (photo/video/other), path.

## Dependencies

- **shelf** / **shelf_router** – HTTP server.
- **network_info_plus** – WiFi IP.
- **mdns_responder** (git) / **mdns_dart** – mDNS for discovery.
- **archive** – ZIP for “download all”.
- **mime** – Multipart upload parsing.
- **provider** – State.
- **path_provider** – Storage directory.
- **qr_flutter** – QR code.
- **device_info_plus** – Emulator detection for adb reverse hint.

## License

Use as you like.
