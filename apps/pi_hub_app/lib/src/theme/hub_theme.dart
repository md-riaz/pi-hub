import 'package:flutter/material.dart';

class HubTheme {
  HubTheme._();

  // Background colors
  static const bg = Color(0xFF07090D);
  static const panel = Color(0xFF0D1117);
  static const panel2 = Color(0xFF111827);
  static const card = Color(0xFF151D29);
  static const line = Color(0xFF263140);
  static const softLine = Color(0xFF1B2635);

  // Text colors
  static const text = Color(0xFFE7EDF7);
  static const text2 = Color(0xFFAAB6C8);
  static const text3 = Color(0xFF68768B);

  // Accent colors
  static const blue = Color(0xFF67A7FF);
  static const green = Color(0xFF5EE19A);
  static const yellow = Color(0xFFF8C471);
  static const red = Color(0xFFFF7A7A);
  static const purple = Color(0xFFB794F4);
  static const cyan = Color(0xFF65D7E0);
  static const orange = Color(0xFFF59E55);

  // Semantic colors for session states
  static const stateRunning = green;
  static const stateTool = cyan;
  static const stateWaiting = yellow;
  static const stateIdle = text3;
  static const stateError = red;
  static const stateLive = green;

  // Text styles
  static const headingL = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: text,
    letterSpacing: -0.5,
  );
  static const headingM = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: text,
  );
  static const body = TextStyle(fontSize: 14, color: text, height: 1.5);
  static const bodySmall = TextStyle(fontSize: 12, color: text2);
  static const caption = TextStyle(fontSize: 11, color: text3);
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
  static const radiusL = BorderRadius.all(Radius.circular(24));
  static const radiusM = BorderRadius.all(Radius.circular(20));
  static const radiusS = BorderRadius.all(Radius.circular(14));
  static const radiusFull = BorderRadius.all(Radius.circular(999));

  // Box decorations
  static BoxDecoration panelDecoration = BoxDecoration(
    color: panel,
    border: Border.all(color: line, width: 1),
    borderRadius: BorderRadius.circular(20),
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: card,
    border: Border.all(color: softLine, width: 1),
    borderRadius: BorderRadius.circular(20),
  );

  // Flutter ThemeData
  static ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.dark(
      primary: blue,
      secondary: green,
      surface: panel,
      error: red,
    ),
    useMaterial3: true,
  );
}
