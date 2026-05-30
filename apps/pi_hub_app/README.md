# Pi Hub Android App

Flutter Android client for Pi Hub mission control.

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

Then enter the hub URL and token in the app.

Common URLs:

- Android emulator: `http://10.0.2.2:17878`
- Physical phone on LAN: `http://<hub-host-lan-ip>:17878`
- Tailscale: `http://<hub-host-tailscale-ip>:17878`

Token file on the hub host:

```text
~/.pi/agent/pi-hub/config.json
```

For physical phone access, keep the hub bound to `0.0.0.0` and allow inbound TCP `17878` through the host firewall.

## Use

1. Tap **Connect**.
2. Select a session or attention item.
3. Review transcript, tools, health, inbox, approvals, or diff reviews.
4. Send prompts or run controls for the selected session.
5. Optional server features such as push registration and agent creation appear only when configured/enabled by the hub.

## Test

```bash
flutter analyze
flutter test
```
