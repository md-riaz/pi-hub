import 'package:flutter/material.dart';

class HubTheme {
  HubTheme._();

  // Warm neutral surfaces
  static const bg = Color(0xFFFBF7F0);
  static const panel = Color(0xFFFFFCF7);
  static const panel2 = Color(0xFFF4EEE5);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE6D8C8);
  static const softLine = Color(0xFFF0E6DA);

  // Text colors
  static const text = Color(0xFF2F2A24);
  static const text2 = Color(0xFF74695F);
  static const text3 = Color(0xFFA4978A);

  // Accent colors
  static const blue = Color(0xFF9A6A4F);
  static const green = Color(0xFF7FA37A);
  static const yellow = Color(0xFFD09B4C);
  static const red = Color(0xFFC26A5A);
  static const purple = Color(0xFFA17AA8);
  static const cyan = Color(0xFF6E9E9B);
  static const orange = Color(0xFFC7834C);

  static const accent = blue;
  static const accentSoft = Color(0xFFE9D8C8);
  static const userBubble = Color(0xFFE8D8C6);
  static const assistantBubble = Color(0xFFFFFCF7);

  // Semantic colors for session states
  static const stateRunning = green;
  static const stateTool = cyan;
  static const stateWaiting = yellow;
  static const stateIdle = text3;
  static const stateError = red;
  static const stateLive = green;

  // Text styles
  static const headingL = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    color: text,
    letterSpacing: -0.6,
  );
  static const headingM = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: text,
    letterSpacing: -0.2,
  );
  static const body = TextStyle(fontSize: 15, color: text, height: 1.55);
  static const bodySmall = TextStyle(fontSize: 13, color: text2, height: 1.35);
  static const caption = TextStyle(fontSize: 12, color: text3, height: 1.35);
  static const mono = TextStyle(
    fontSize: 11,
    color: text2,
    fontFamily: 'monospace',
    fontWeight: FontWeight.w500,
  );
  static const monoSmall = TextStyle(
    fontSize: 10,
    color: text3,
    fontFamily: 'monospace',
  );

  // Border radius
  static const radiusL = BorderRadius.all(Radius.circular(28));
  static const radiusM = BorderRadius.all(Radius.circular(22));
  static const radiusS = BorderRadius.all(Radius.circular(16));
  static const radiusFull = BorderRadius.all(Radius.circular(999));

  // Box decorations
  static BoxDecoration panelDecoration = BoxDecoration(
    color: panel,
    border: Border.all(color: softLine, width: 1),
    borderRadius: BorderRadius.circular(24),
    boxShadow: [softShadow],
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: card,
    border: Border.all(color: softLine, width: 1),
    borderRadius: BorderRadius.circular(22),
    boxShadow: [softShadow],
  );

  static BoxShadow softShadow = BoxShadow(
    color: const Color(0xFF6F5845).withValues(alpha: 0.08),
    blurRadius: 24,
    offset: const Offset(0, 10),
  );

  // Flutter ThemeData
  static ThemeData get themeData => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: bg,
    fontFamily: 'System',
    colorScheme: const ColorScheme.light(
      primary: blue,
      secondary: green,
      surface: panel,
      error: red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: panel,
      foregroundColor: text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    useMaterial3: true,
  );
}
