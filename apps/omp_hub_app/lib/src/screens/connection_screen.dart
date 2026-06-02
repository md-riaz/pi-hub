import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class ConnectionScreen extends StatefulWidget {
  final TextEditingController serverController;
  final TextEditingController tokenController;
  final bool connecting;
  final String? error;
  final VoidCallback onConnect;
  final List<Map<String, String>> recentConnections;
  final ValueChanged<Map<String, String>>? onRecentConnection;

  const ConnectionScreen({
    super.key,
    required this.serverController,
    required this.tokenController,
    required this.connecting,
    this.error,
    required this.onConnect,
    this.recentConnections = const [],
    this.onRecentConnection,
  });

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  @override
  void initState() {
    super.initState();
    widget.serverController.addListener(_onChanged);
    widget.tokenController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.serverController.removeListener(_onChanged);
    widget.tokenController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final canConnect =
        widget.serverController.text.trim().isNotEmpty &&
        widget.tokenController.text.trim().isNotEmpty &&
        !widget.connecting;

    return Scaffold(
      backgroundColor: HubTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: HubTheme.accentSoft,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: HubTheme.softLine),
                  boxShadow: [HubTheme.softShadow],
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: HubTheme.accent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Hub Mobile', style: HubTheme.headingL),
              const SizedBox(height: 8),
              Text(
                'Connect to your hub server and continue conversations from your phone.',
                style: HubTheme.caption.copyWith(fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // URL field
              _InputField(
                icon: Icons.dns,
                label: 'Server URL',
                controller: widget.serverController,
                placeholder: 'http://host:port',
              ),
              const SizedBox(height: 16),
              // Token field
              _InputField(
                icon: Icons.key,
                label: 'Token',
                controller: widget.tokenController,
                placeholder: 'Access token',
                obscure: true,
              ),
              const SizedBox(height: 16),
              // Connect button
              GestureDetector(
                onTap: canConnect ? widget.onConnect : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: canConnect ? HubTheme.accent : HubTheme.panel2,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.connecting)
                        const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HubTheme.text3,
                          ),
                        )
                      else
                        const Icon(
                          Icons.wifi,
                          size: 17,
                          color: Colors.white,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        widget.connecting ? 'Connecting...' : 'Connect',
                        style: TextStyle(
                          color: canConnect ? Colors.white : HubTheme.text3,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HubTheme.red.withValues(alpha: 0.1),
                    border: Border.all(
                      color: HubTheme.red.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: HubTheme.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.error!,
                          style: const TextStyle(
                            color: HubTheme.red,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Recent connections
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'RECENT CONNECTIONS',
                  style: HubTheme.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.recentConnections.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No recent connections', style: HubTheme.caption),
                )
              else
                ...widget.recentConnections.map(
                  (conn) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecentConn(
                      name: conn['name'] ?? '',
                      url: conn['url'] ?? '',
                      onTap: () {
                        widget.serverController.text = conn['url'] ?? '';
                        widget.tokenController.text = conn['token'] ?? '';
                        widget.onRecentConnection?.call(conn);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final bool obscure;

  const _InputField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.placeholder,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: HubTheme.text2),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: HubTheme.text2,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(
            color: HubTheme.text,
            fontSize: 14,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: HubTheme.text3),
            filled: true,
            fillColor: HubTheme.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: HubTheme.softLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: HubTheme.softLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: HubTheme.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentConn extends StatelessWidget {
  final String name;
  final String url;
  final VoidCallback onTap;
  const _RecentConn({
    required this.name,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HubTheme.card,
          border: Border.all(color: HubTheme.softLine),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: HubTheme.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.dns, size: 17, color: HubTheme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: HubTheme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    url,
                    style: HubTheme.monoSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: HubTheme.text3),
          ],
        ),
      ),
    );
  }
}
