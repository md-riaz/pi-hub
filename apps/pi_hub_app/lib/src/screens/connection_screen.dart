import 'package:flutter/material.dart';
import '../theme/hub_theme.dart';

class ConnectionScreen extends StatefulWidget {
  final TextEditingController serverController;
  final TextEditingController tokenController;
  final bool connecting;
  final String? error;
  final VoidCallback onConnect;

  const ConnectionScreen({
    super.key,
    required this.serverController,
    required this.tokenController,
    required this.connecting,
    this.error,
    required this.onConnect,
  });

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  @override
  Widget build(BuildContext context) {
    final canConnect = widget.serverController.text.trim().isNotEmpty &&
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
              // Pi logo
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF17243B), Color(0xFF281C45)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: HubTheme.line),
                ),
                child: const Center(
                  child: Text('π', style: TextStyle(color: HubTheme.blue, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Pi Hub', style: HubTheme.headingL),
              const SizedBox(height: 8),
              Text(
                'Connect to your hub server and control Pi sessions from your phone.',
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
                    color: canConnect ? HubTheme.blue : HubTheme.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.connecting)
                        const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: HubTheme.text3))
                      else
                        const Icon(Icons.wifi, size: 17, color: Color(0xFF06111F)),
                      const SizedBox(width: 8),
                      Text(
                        widget.connecting ? 'Connecting...' : 'Connect',
                        style: TextStyle(
                          color: canConnect ? const Color(0xFF06111F) : HubTheme.text3,
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
                    color: HubTheme.red.withOpacity(0.1),
                    border: Border.all(color: HubTheme.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: HubTheme.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.error!,
                          style: const TextStyle(color: HubTheme.red, fontSize: 12, height: 1.4),
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
                child: Text('RECENT CONNECTIONS', style: HubTheme.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              _RecentConn(name: 'Home Lab', url: 'http://100.101.44.8:8787', onTap: () {
                widget.serverController.text = 'http://100.101.44.8:8787';
                widget.tokenController.text = 'home-lab-token';
              }),
              const SizedBox(height: 8),
              _RecentConn(name: 'VPS', url: 'https://pi-hub.riyaz.dev', onTap: () {
                widget.serverController.text = 'https://pi-hub.riyaz.dev';
                widget.tokenController.text = 'vps-token';
              }),
              const SizedBox(height: 8),
              _RecentConn(name: 'Office Tunnel', url: 'http://192.168.1.100:8080', onTap: () {
                widget.serverController.text = 'http://192.168.1.100:8080';
                widget.tokenController.text = 'office-token';
              }),
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

  const _InputField({required this.icon, required this.label, required this.controller, required this.placeholder, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: HubTheme.text2),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: HubTheme.text2, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: HubTheme.text, fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: HubTheme.text3),
            filled: true,
            fillColor: HubTheme.panel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: HubTheme.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: HubTheme.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: HubTheme.blue)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
  const _RecentConn({required this.name, required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HubTheme.panel,
          border: Border.all(color: HubTheme.softLine),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: HubTheme.card, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.dns, size: 17, color: HubTheme.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: HubTheme.text, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(url, style: HubTheme.monoSmall, overflow: TextOverflow.ellipsis),
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
