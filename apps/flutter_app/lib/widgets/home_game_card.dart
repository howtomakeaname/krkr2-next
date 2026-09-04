import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/game_info.dart';
import '../ui/ui.dart';

/// Library-grid card and its game-specific context-menu presentation.
///
/// Navigation and mutations stay in the home page; this widget only renders the
/// current game snapshot and forwards user intent through callbacks.
class HomeGameCard extends StatelessWidget {
  const HomeGameCard({
    super.key,
    required this.game,
    required this.l10n,
    required this.onTap,
    required this.onLaunch,
    required this.onScrape,
    required this.onRename,
    required this.onRemove,
  });

  final GameInfo game;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback onLaunch;
  final VoidCallback onScrape;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  bool get _hasCover =>
      game.coverPath != null && File(game.coverPath!).existsSync();

  @override
  Widget build(BuildContext context) {
    return UiContextMenu(
      onTap: onTap,
      items: [
        UiMenuItem(
          label: l10n.launchGame,
          icon: LucideIcons.play,
          onSelected: onLaunch,
        ),
        UiMenuItem(
          label: l10n.scrapeMetadata,
          icon: LucideIcons.cloudDownload,
          onSelected: onScrape,
        ),
        UiMenuItem(
          label: l10n.rename,
          icon: LucideIcons.pencil,
          onSelected: onRename,
        ),
        UiMenuItem(
          label: l10n.remove,
          icon: LucideIcons.trash2,
          isDestructive: true,
          onSelected: onRemove,
        ),
      ],
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: UiRadius.brLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(context),
            _buildGradientOverlay(),
            _buildTitleOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    if (_hasCover) {
      return UiGameCover(
        image: FileImage(File(game.coverPath!)),
        placeholder: _buildPlaceholder(context),
        semanticLabel: game.displayTitle,
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colors = context.uiColors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surfaceElevated, colors.separator],
        ),
      ),
      child: Center(
        child: Icon(
          LucideIcons.gamepad2,
          size: 48,
          color: colors.brand.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 80,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black54],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleOverlay() {
    final lastPlayed = game.lastPlayed;
    final totalSeconds = game.playDurationSeconds ?? 0;
    final hasDuration = totalSeconds >= 60;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            game.displayTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (lastPlayed != null || hasDuration) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (lastPlayed != null) _formatDate(lastPlayed),
                if (hasDuration)
                  l10n.playDuration(GameInfo.formatPlayDuration(totalSeconds)),
              ].join(' · '),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
