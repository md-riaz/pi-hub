# Pi Hub Android App

Flutter Android client for Pi Hub mission control (v2.0.36+36).

## Run from source

```bash
cd apps/pi_hub_app
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

Start the hub from a Pi session first:

```text
/hub start
```

Then enter the hub URL and token in the app. The app adds `http://` automatically if you enter only `host:port`.

Common URLs:

- Android emulator: `http://10.0.2.2:17878`
- Physical phone on LAN: `http://<hub-host-lan-ip>:17878`
- Tailscale: `http://<hub-host-tailscale-ip>:17878`

Token file on the hub host:

```text
~/.pi/agent/pi-hub/config.json
```

For physical phone access, the hub binds `0.0.0.0` by default. Keep it on trusted LAN/VPN/Tailscale paths and allow inbound TCP `17878` through the host firewall if needed.

## Use

1. Tap **Connect**.
2. Select a session.
3. Review chat-style conversation history with collapsible tool, terminal, and edit groups.
4. Send prompts, attach files, paste from clipboard, or run server file browse.
5. Run controls: abort, compact, switch model, or shutdown for the selected session.
6. Create new Pi sessions from any existing directory on the hub host.

## Test

```bash
flutter analyze
flutter test
```
