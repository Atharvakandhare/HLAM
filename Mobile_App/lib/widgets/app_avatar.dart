import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? fallback;
  final Color? backgroundColor;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    this.fallback,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color defaultBgColor = backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.08);

    Widget fallbackWidget = fallback ?? Icon(
      Icons.person_rounded,
      color: Theme.of(context).primaryColor,
      size: radius,
    );

    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: defaultBgColor,
        child: fallbackWidget,
      );
    }

    return ClipOval(
      child: Image.network(
        imageUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If the network image fails to load (e.g. 404), fallback to the placeholder
          return CircleAvatar(
            radius: radius,
            backgroundColor: defaultBgColor,
            child: fallbackWidget,
          );
        },
      ),
    );
  }
}
