import 'package:flutter/material.dart';

class AppColors {
  // Primary - Deep Medical Emerald
  static const Color primary = Color(0xFF005F54);
  static const Color primaryDark = Color(0xFF0B3C35);
  static const Color primaryLight = Color(0xFF00857A);
  static const Color primaryGlow = Color(0x33005F54);

  // Secondary backgrounds
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF243447);

  // Accent - Warm Amber/Gold
  static const Color accent = Color(0xFFD97706);
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color accentGlow = Color(0x33D97706);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Connected Status palette
  static const Color connected = Color(0xFF10B981);
  static const Color busy = Color(0xFFF59E0B);
  static const Color noAnswer = Color(0xFF6B7280);
  static const Color callBack = Color(0xFF3B82F6);
  static const Color notInterested = Color(0xFFDC2626);
  static const Color interested = Color(0xFF8B5CF6);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnDark = Color(0xFFF8FAFC);
  static const Color textOnDarkSecondary = Color(0xFF94A3B8);

  // Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF005F54), Color(0xFF0B3C35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient roleSelectorGradient = LinearGradient(
    colors: [Color(0xFF0B3C35), Color(0xFF0F172A), Color(0xFF1a1040)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.6, 1.0],
  );

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return connected;
      case 'order received':
        return const Color(0xFF0D9488);
      case 'busy':
        return busy;
      case 'no answer':
        return noAnswer;
      case 'call back':
        return callBack;
      case 'not interested':
        return notInterested;
      case 'interested':
        return interested;
      default:
        return noAnswer;
    }
  }
}
