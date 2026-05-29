# Pi Hub App

Flutter Android dashboard for Pi Hub.

## Run in development

```bash
cd apps/pi_hub_app
flutter pub get
flutter run
```

## Build APK

```bash
cd apps/pi_hub_app
flutter build apk --release
```

APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Connect

Start Pi Hub from any Pi session first:

```text
/hub start
```

Then enter in app:

- Android emulator: `http://10.0.2.2:17878`
- Physical phone on LAN: `http://<Windows-VM-IP>:17878`
- Tailscale: `http://<Tailscale-IP>:17878`
- Token: read from `~/.pi/agent/pi-hub/config.json`

For physical phone access, keep server `host` set to `0.0.0.0` and allow TCP port `17878` through Windows firewall.

## Use

1. Tap **Connect**.
2. Pick session from left pane.
3. Read transcript and current tool status.
4. Send prompt with bottom text field.
5. Use **Abort**, **Compact**, **Model**, or **Shutdown** controls for selected session.

## Test

```bash
flutter analyze
flutter test
```
