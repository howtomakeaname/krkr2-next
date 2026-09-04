import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/play_honor_localizations.dart';
import '../models/play_insights.dart';
import '../ui/ui.dart';

class PlayHonorCard extends StatelessWidget {
  const PlayHonorCard({
    super.key,
    required this.honor,
    required this.remainingDuration,
  });

  final PlayHonor honor;
  final String remainingDuration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? const Color(0xFFE9BC63) : const Color(0xFFAB741D);

    return UiCard(
      key: const ValueKey<String>('statistics-honor-card'),
      borderRadius: UiRadius.brXxl,
      border: Border.all(color: colors.border.withValues(alpha: 0.45)),
      padding: const EdgeInsets.all(UiSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HonorTrophy(isDark: isDark),
              const SizedBox(width: UiSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileHonorTitle,
                      style: context.uiType.footnote.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: UiSpacing.xs),
                    Text(
                      l10n.playHonorTier(honor.tier),
                      key: const ValueKey<String>('statistics-honor-title'),
                      style: context.uiType.title2.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: UiSpacing.xxl),
          if (honor.nextTier != null) ...[
            Semantics(
              container: true,
              label: l10n.profileHonorNextUnlock,
              value: '${(honor.progress * 100).floor()}%',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileHonorNextUnlock,
                      style: context.uiType.footnote.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: UiSpacing.sm),
                    UiProgress(
                      value: honor.progress,
                      height: 4,
                      color: gold,
                      backgroundColor: colors.separator.withValues(
                        alpha: isDark ? 0.12 : 0.10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: UiSpacing.sm),
          ],
          Text(
            l10n.playHonorRequirement(honor, remainingDuration),
            key: const ValueKey<String>('statistics-honor-requirement'),
            style: context.uiType.footnote.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HonorTrophy extends StatelessWidget {
  const _HonorTrophy({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final highlight = isDark
        ? const Color(0xFFF9DE96)
        : const Color(0xFFF0CB73);
    final gold = isDark ? const Color(0xFFE4AF49) : const Color(0xFFD4A044);
    final shade = isDark ? const Color(0xFFB98630) : const Color(0xFF9C681C);

    return ExcludeSemantics(
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF393025), Color(0xFF28231D)]
                : const [Color(0xFFFFF8E8), Color(0xFFF5E8CB)],
          ),
          border: Border.all(
            color: gold.withValues(alpha: isDark ? 0.18 : 0.12),
          ),
        ),
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [highlight, gold, shade],
            stops: const [0, 0.42, 1],
          ).createShader(bounds),
          child: const Icon(
            Icons.emoji_events_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
