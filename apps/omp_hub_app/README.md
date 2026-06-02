# OMP Hub Android App

Flutter Android client for OMP Hub mission control (v2.0.45+45).

## Run from source

```bash
cd apps/omp_hub_app
flutter pub get
flutter run
```

## Build APK

Release build:

```bash
flutter build apk --release
```

Debug build for local testing:

```bash
flutter build apk --debug
```

APK outputs are written under:

```text
build/app/outputs/flutter-apk/
```

## Connect

Start the hub from an OMP session first:

```text
/hub start
```

Then enter the hub URL and token in the app. The app adds `http://` automatically if you enter only `host:port`.

Common URLs:

- Android emulator: `http://10.0.2.2:18878`
- Physical phone on LAN: `http://<hub-host-lan-ip>:18878`
- Tailscale: `http://<hub-host-tailscale-ip>:18878`

Token file on the hub host:

```text
~/.omp/agent/omp-hub/config.json
```

For physical phone access, the hub binds `0.0.0.0` by default. Keep it on trusted LAN/VPN/Tailscale paths and allow inbound TCP `18878` through the host firewall if needed.

## Use

1. Tap **Connect**.
2. Select a session.
3. Review chat-style conversation history with collapsible tool, terminal, and edit groups.
4. Send prompts, attach files, paste from clipboard, or run server file browse.
5. Run controls: abort, compact, switch model, or shutdown for the selected session.
6. Create new OMP sessions from any existing directory on the hub host.

## Test

```bash
flutter analyze
flutter test
```
