import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EditorialPage extends StatelessWidget {
  const EditorialPage({
    super.key,
    required this.child,
    this.dark = false,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 28),
    this.centered = false,
    this.maxContentWidth,
  });

  final Widget child;
  final bool dark;
  final EdgeInsets padding;
  final bool centered;
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final blobColor = dark
        ? Colors.white.withValues(alpha: 0.04)
        : AppTheme.primaryFixed.withValues(alpha: 0.9);

    return DecoratedBox(
      decoration: AppTheme.editorialPageBackground(dark: dark),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -40,
            child: _BlurBlob(
              size: 220,
              color: blobColor,
            ),
          ),
          Positioned(
            left: -80,
            bottom: 40,
            child: _BlurBlob(
              size: 260,
              color: dark
                  ? AppTheme.secondaryContainer.withValues(alpha: 0.08)
                  : AppTheme.primaryContainer.withValues(alpha: 0.08),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final content = ConstrainedBox(
                constraints: maxContentWidth != null
                    ? BoxConstraints(maxWidth: maxContentWidth!)
                    : const BoxConstraints(),
                child: SizedBox(width: double.infinity, child: child),
              );

              final wrapped = centered
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - padding.vertical,
                      ),
                      child: Center(child: content),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: content,
                    );

              return SingleChildScrollView(
                padding: padding,
                child: wrapped,
              );
            },
          ),
        ],
      ),
    );
  }
}

class EditorialEyebrow extends StatelessWidget {
  const EditorialEyebrow({
    super.key,
    required this.label,
    this.icon,
    this.dark = false,
  });

  final String label;
  final IconData? icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.primary.withValues(alpha: 0.05);
    final foreground = dark ? Colors.white : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTheme.label(
              10,
              color: foreground,
              weight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class EditorialSectionTitle extends StatelessWidget {
  const EditorialSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.dark = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : AppTheme.onSurface;
    final muted = dark
        ? Colors.white.withValues(alpha: 0.7)
        : AppTheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.headline(
                  22,
                  color: foreground,
                  weight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTheme.body(12, color: muted, height: 1.45),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class GradientCtaButton extends StatelessWidget {
  const GradientCtaButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.enabled = true,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground =
        enabled ? Colors.white : AppTheme.onSurfaceVariant.withValues(alpha: 0.8);
    final background = enabled
        ? AppTheme.gradientBox(radius: compact ? 18 : 24)
        : BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(compact ? 18 : 24),
          );

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: compact ? 48 : 58,
        decoration: background,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 18 : 20, color: foreground),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTheme.headline(
                  compact ? 13 : 15,
                  color: foreground,
                  weight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 28,
    this.dark = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: dark
          ? AppTheme.darkGlass(radius: radius)
          : AppTheme.glassCard(radius: radius),
      padding: padding,
      child: child,
    );
  }
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 28,
    this.dark = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: dark
          ? AppTheme.darkGlass(radius: radius)
          : AppTheme.surfaceCard(radius: radius),
      padding: padding,
      child: child,
    );
  }
}

class TonalPanel extends StatelessWidget {
  const TonalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: padding,
      child: child,
    );
  }
}

class RiskBadge extends StatelessWidget {
  const RiskBadge({
    super.key,
    required this.label,
    this.color,
    this.background,
  });

  final String label;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppTheme.riskLevelColor(label);
    final resolvedBg = background ?? AppTheme.riskLevelBackground(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.label(
          10,
          color: resolvedColor,
          weight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class MetricRing extends StatelessWidget {
  const MetricRing({
    super.key,
    required this.score,
    required this.label,
    this.color,
    this.trackColor,
    this.size = 112,
    this.dark = false,
  });

  final int score;
  final String label;
  final Color? color;
  final Color? trackColor;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100);
    final resolvedColor = color ?? AppTheme.riskColor(score);
    final resolvedTrack = trackColor ??
        (dark
            ? Colors.white.withValues(alpha: 0.16)
            : AppTheme.surfaceContainerHigh);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 8,
                  color: resolvedTrack,
                ),
              ),
              SizedBox.expand(
                child: Transform.rotate(
                  angle: -math.pi / 2,
                  child: CircularProgressIndicator(
                    value: clamped / 100,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    color: resolvedColor,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              Text(
                '$clamped',
                style: AppTheme.headline(
                  size * 0.32,
                  color: resolvedColor,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: AppTheme.label(
            10,
            color: dark ? Colors.white.withValues(alpha: 0.72) : null,
            weight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

class MockTag extends StatelessWidget {
  const MockTag({super.key, this.label = 'Mock'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.secondaryContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.label(
          9,
          color: AppTheme.secondary,
          weight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class SplitBackgroundFill extends StatelessWidget {
  const SplitBackgroundFill({
    super.key,
    this.dark = false,
    this.height = 220,
  });

  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) {
    final panelColor = dark
        ? Colors.white.withValues(alpha: 0.05)
        : AppTheme.surfaceLowest.withValues(alpha: 0.45);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: panelColor,
      ),
      child: Stack(
        children: List.generate(
          6,
          (index) {
            final alignRight = index.isOdd;
            return Align(
              alignment:
                  alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(
                  top: 18.0 * index,
                  left: alignRight ? 70 : 18,
                  right: alignRight ? 18 : 70,
                ),
                height: 16,
                width: 120 + ((index % 3) * 34),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppTheme.surfaceContainerHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 120,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
