import 'package:flutter/material.dart';

enum MessageType { success, error, info }

class AppMessages {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, MessageType.success);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, MessageType.error);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, MessageType.info);
  }

  static void _show(BuildContext context, String message, MessageType type) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Clear existing snackbars first
    scaffoldMessenger.hideCurrentSnackBar();

    Color color1;
    Color color2;
    IconData icon;
    String title;

    switch (type) {
      case MessageType.success:
        color1 = const Color(0xFF00B09B); // Teal
        color2 = const Color(0xFF96C93D); // Light Green
        icon = Icons.check_circle_rounded;
        title = 'Success';
        break;
      case MessageType.error:
        color1 = const Color(0xFFF05053); // Red
        color2 = const Color(0xFFE1Eec3); // Soft tint or something similar? Actually let's use a cleaner red gradient
        color1 = const Color(0xFFFF5F6D);
        color2 = const Color(0xFFFFC371); // Orange/Red
        icon = Icons.error_rounded;
        title = 'Error';
        break;
      case MessageType.info:
        color1 = const Color(0xFF2193B0);
        color2 = const Color(0xFF6DD5ED);
        icon = Icons.info_rounded;
        title = 'Information';
        break;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color1, color2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color1.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.startsWith('Exception: ') ? message.substring(11) : message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => scaffoldMessenger.hideCurrentSnackBar(),
                icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
