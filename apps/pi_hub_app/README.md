# Pi Hub App

Android Flutter dashboard for the Pi Hub extension.

## Run

```bash
flutter run
```

## Connect

- Android emulator: `http://10.0.2.2:17878`
- Physical phone on same LAN: `http://<Windows-VM-IP>:17878`
- Token: `~/.pi/agent/pi-hub/config.json`

For a physical phone, set Pi Hub server `host` to `0.0.0.0` and allow TCP port `17878` through Windows firewall.
