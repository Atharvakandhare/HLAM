import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../main.dart';

enum MessageType { success, error, info }

class AppMessages {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, MessageType.success);
  }

  static void showError(BuildContext context, dynamic error) {
    String displayMessage = '';
    if (error is ApiException) {
      displayMessage = error.userMessage;
    } else {
      final errStr = error.toString();
      displayMessage = errStr.startsWith('Exception: ') ? errStr.substring(11) : errStr;
    }

    final lastApi = ApiService.lastApiException;
    final hasDetails = lastApi != null && 
        (error.toString().contains(lastApi.userMessage) || 
         error.toString().contains(lastApi.devDetails) ||
         lastApi.userMessage.contains(error.toString()));

    _show(context, displayMessage, MessageType.error, rawError: hasDetails ? lastApi : error);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, MessageType.info);
  }

  static void _show(BuildContext context, String message, MessageType type, {dynamic rawError}) {
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
        duration: const Duration(seconds: 6),
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
              const SizedBox(width: 12),
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
                      message,
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
              if (type == MessageType.error) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    scaffoldMessenger.hideCurrentSnackBar();
                    final targetContext = context.mounted ? context : (MyApp.navigatorKey.currentContext ?? context);
                    _showErrorDetailsDialog(targetContext, rawError ?? message);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Details',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(width: 4),
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

  static void _showErrorDetailsDialog(BuildContext context, dynamic error) {
    String devDetails = error.toString();
    String? url;
    int? statusCode;

    if (error is ApiException) {
      devDetails = error.devDetails;
      url = error.url;
      statusCode = error.statusCode;
    }

    final targetContext = context.mounted ? context : (MyApp.navigatorKey.currentContext ?? context);

    showDialog(
      context: targetContext,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bug_report_rounded, color: Color(0xFFEF4444), size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Technical Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxHeight: 350),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (url != null) ...[
                    const Text(
                      'Request URL:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      url,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (statusCode != null) ...[
                    const Text(
                      'HTTP Status Code:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      '$statusCode',
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Stack Trace / Exception Logs:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SelectableText(
                      devDetails,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
