import 'package:flutter/material.dart';

class SkillBridgeAvatar extends StatelessWidget {
  final String? profileImageUrl;
  final String? name;
  final double size;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SkillBridgeAvatar({
    super.key,
    this.profileImageUrl,
    this.name,
    this.size = 40,
    this.borderRadius,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = profileImageUrl?.trim() ?? '';
    final displayName = name?.trim() ?? '';
    final initial = displayName.isEmpty ? '' : displayName[0].toUpperCase();
    final fallbackBackground =
        backgroundColor ?? theme.colorScheme.primaryContainer;
    final fallbackForeground =
        foregroundColor ?? theme.colorScheme.onPrimaryContainer;
    final shape = borderRadius ?? BorderRadius.circular(size / 2);

    Widget fallback() {
      return ColoredBox(
        color: fallbackBackground,
        child: Center(
          child: initial.isEmpty
              ? Icon(
                  Icons.person_rounded,
                  size: size * 0.58,
                  color: fallbackForeground,
                )
              : Text(
                  initial,
                  style: TextStyle(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                    color: fallbackForeground,
                  ),
                ),
        ),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: shape,
        child: url.isEmpty
            ? fallback()
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return fallback();
                },
                errorBuilder: (context, error, stackTrace) => fallback(),
              ),
      ),
    );
  }
}
