import 'package:flutter/material.dart';

class ConnectionBar extends StatelessWidget {
  const ConnectionBar({
    super.key,
    required this.serverController,
    required this.tokenController,
    required this.connecting,
    required this.connected,
    required this.onConnect,
  });

  final TextEditingController serverController;
  final TextEditingController tokenController;
  final bool connecting;
  final bool connected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 680;
        final fields = [
          TextField(
            controller: serverController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: '10.0.2.2:17878 or hub-host-ip:17878',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            controller: tokenController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Token',
              hintText: '~/.pi/agent/pi-hub/config.json',
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: narrow ? Alignment.centerLeft : Alignment.center,
            child: FilledButton.icon(
              onPressed: connecting ? null : onConnect,
              icon: connecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(connected ? 'Reconnect' : 'Connect'),
            ),
          ),
        ];

        if (narrow) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                fields[0],
                const SizedBox(height: 8),
                fields[1],
                const SizedBox(height: 8),
                fields[2],
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(flex: 2, child: fields[0]),
              const SizedBox(width: 12),
              Expanded(child: fields[1]),
              const SizedBox(width: 12),
              fields[2],
            ],
          ),
        );
      },
    );
  }
}
