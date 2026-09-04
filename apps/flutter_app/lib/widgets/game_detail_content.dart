import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/game_engine.dart';
import '../models/game_info.dart';
import '../ui/ui.dart';

/// The informational and action sheet below the game-detail hero.
///
/// The page owns navigation and mutations. This component owns only local
/// presentation state such as expanded descriptions and keyword visibility.
class GameDetailContent extends StatefulWidget {
  const GameDetailContent({
    super.key,
    required this.game,
    required this.onLaunch,
    required this.onSetCover,
    required this.onRename,
    required this.onScrape,
    required this.onPackUnpack,
    required this.onRemove,
  });

  static const double sheetRadius = 24;

  final GameInfo game;
  final VoidCallback onLaunch;
  final ValueChanged<Rect> onSetCover;
  final VoidCallback onRename;
  final VoidCallback onScrape;
  final VoidCallback onPackUnpack;
  final VoidCallback onRemove;

  @override
  State<GameDetailContent> createState() => _GameDetailContentState();
}

class _GameDetailContentState extends State<GameDetailContent> {
  static const int _collapsedKeywordCount = 6;

  bool _showAllKeywords = false;

  GameInfo get game => widget.game;
  bool get _isXp3 => game.path.toLowerCase().endsWith('.xp3');
  bool get _hasScrapedText =>
      (game.description?.trim().isNotEmpty ?? false) ||
      game.keywords.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(GameDetailContent.sheetRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoSection(l10n),
          if (_hasScrapedText) _buildMetadataSection(l10n),
          _buildLaunchButton(l10n),
          _buildManageSection(l10n),
          _buildDangerSection(l10n),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(AppLocalizations l10n) {
    final colors = context.uiColors;
    final description = game.description?.trim();
    final keywords = game.keywords
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toList(growable: false);
    final visibleKeywords = _showAllKeywords
        ? keywords
        : keywords.take(_collapsedKeywordCount).toList(growable: false);
    final hiddenKeywordCount = keywords.length - visibleKeywords.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: UiCard(
        color: colors.surfaceElevated,
        padding: const EdgeInsets.all(UiSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null && description.isNotEmpty) ...[
              _metadataHeading(l10n.gameDescription),
              const SizedBox(height: UiSpacing.sm),
              _ExpandableDescription(
                text: description,
                moreLabel: l10n.showMore,
                lessLabel: l10n.showLess,
              ),
            ],
            if (description != null &&
                description.isNotEmpty &&
                keywords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: UiSpacing.lg),
                child: Divider(height: 1, color: colors.separator),
              ),
            if (keywords.isNotEmpty) ...[
              _metadataHeading(l10n.gameKeywords),
              const SizedBox(height: UiSpacing.sm),
              AnimatedSize(
                duration: UiDuration.base,
                curve: UiCurves.iosSmooth,
                alignment: Alignment.topLeft,
                child: Wrap(
                  key: ValueKey<bool>(_showAllKeywords),
                  spacing: UiSpacing.sm,
                  runSpacing: UiSpacing.sm,
                  children: [
                    for (final keyword in visibleKeywords)
                      UiTag(label: keyword, dense: true),
                    if (hiddenKeywordCount > 0)
                      UiTag(
                        label: '+$hiddenKeywordCount',
                        tone: UiTagTone.brand,
                        dense: true,
                        onTap: () => setState(() => _showAllKeywords = true),
                      )
                    else if (_showAllKeywords &&
                        keywords.length > _collapsedKeywordCount)
                      UiTag(
                        label: l10n.showLess,
                        tone: UiTagTone.brand,
                        dense: true,
                        onTap: () => setState(() => _showAllKeywords = false),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metadataHeading(String text) {
    return Text(
      text,
      style: context.uiType.footnote.copyWith(
        color: context.uiColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInfoSection(AppLocalizations l10n) {
    final lastPlayed = game.lastPlayed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            LucideIcons.folder,
            game.path,
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: game.path));
              UiSnackbar.show(
                context,
                message: l10n.copiedToClipboard,
                type: UiSnackbarType.success,
                duration: const Duration(seconds: 1),
              );
            },
          ),
          if (lastPlayed != null) ...[
            const SizedBox(height: 8),
            _infoRow(
              LucideIcons.clock,
              l10n.lastPlayed(_formatDate(lastPlayed, l10n)),
            ),
          ],
          if ((game.playDurationSeconds ?? 0) >= 60) ...[
            const SizedBox(height: 8),
            _infoRow(
              LucideIcons.timer,
              l10n.playDuration(
                GameInfo.formatPlayDuration(game.playDurationSeconds!),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _infoRow(
            LucideIcons.package,
            game.engine == GameEngine.artemis
                ? l10n.gameTypeArtemis
                : _isXp3
                ? l10n.gameTypeXp3
                : l10n.gameTypeDirectory,
          ),
          const SizedBox(height: 8),
          _infoRow(LucideIcons.cpu, l10n.gameEngine(game.engine.label)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onLongPress}) {
    final colors = context.uiColors;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.uiType.footnote.copyWith(
                color: colors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunchButton(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: UiButton(
        label: l10n.launchGame,
        leadingIcon: LucideIcons.play,
        size: UiButtonSize.large,
        fullWidth: true,
        onPressed: widget.onLaunch,
      ),
    );
  }

  Widget _buildManageSection(AppLocalizations l10n) {
    final colors = context.uiColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: UiCard(
        color: colors.surfaceElevated,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            UiListTile(
              icon: LucideIcons.image,
              title: l10n.setCover,
              showChevron: true,
              onTapRect: widget.onSetCover,
            ),
            UiListTile(
              icon: LucideIcons.pencil,
              title: l10n.rename,
              showChevron: true,
              onTap: widget.onRename,
            ),
            UiListTile(
              icon: LucideIcons.cloudDownload,
              title: l10n.scrapeMetadata,
              showChevron: true,
              onTap: widget.onScrape,
            ),
            // XP3 pack/unpack only applies to KiriKiri entries; Artemis
            // packs (.pfs) are consumed in place by the engine.
            if (game.engine == GameEngine.krkr2)
              UiListTile(
                icon: _isXp3 ? LucideIcons.packageOpen : LucideIcons.archive,
                title: _isXp3 ? l10n.unpackXp3 : l10n.packXp3,
                showChevron: true,
                onTap: widget.onPackUnpack,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerSection(AppLocalizations l10n) {
    final colors = context.uiColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: UiCard(
        color: colors.surfaceElevated,
        padding: EdgeInsets.zero,
        child: UiListTile(
          icon: LucideIcons.trash2,
          iconColor: colors.danger,
          title: l10n.remove,
          showChevron: true,
          onTap: widget.onRemove,
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Keeps the existing [UiButton] styling while continuously collapsing the
/// toolbar action from its labelled form into the compact icon-only form.
class GameDetailCollapsingLaunchButton extends StatelessWidget {
  const GameDetailCollapsingLaunchButton({
    super.key,
    required this.progress,
    required this.label,
    required this.onPressed,
  });

  static const double _compactWidth = 32;

  final double progress;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: context.uiType.button.copyWith(fontSize: 14),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final expandedWidth = (textPainter.width + 56)
        .clamp(76.0, 176.0)
        .toDouble();
    final width = ui.lerpDouble(expandedWidth, _compactWidth, progress)!;
    final compactOpacity = _intervalProgress(progress, 0.48, 1);
    final expandedOpacity = 1 - _intervalProgress(progress, 0.20, 0.88);

    return Semantics(
      key: const ValueKey<String>('game-detail-toolbar-launch'),
      button: true,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: 32,
          child: ClipRect(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 0,
                  width: expandedWidth,
                  child: IgnorePointer(
                    ignoring: progress >= 0.58,
                    child: Opacity(
                      opacity: expandedOpacity,
                      child: UiButton(
                        label: label,
                        leadingIcon: LucideIcons.play,
                        size: UiButtonSize.small,
                        onPressed: onPressed,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  width: _compactWidth,
                  child: IgnorePointer(
                    ignoring: progress < 0.58,
                    child: Opacity(
                      opacity: compactOpacity,
                      child: UiButton.icon(
                        icon: LucideIcons.play,
                        size: UiButtonSize.small,
                        variant: UiButtonVariant.primary,
                        onPressed: onPressed,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _intervalProgress(double value, double begin, double end) {
    return ((value - begin) / (end - begin)).clamp(0.0, 1.0).toDouble();
  }
}

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({
    required this.text,
    required this.moreLabel,
    required this.lessLabel,
  });

  final String text;
  final String moreLabel;
  final String lessLabel;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  static const int _collapsedLines = 4;
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _ExpandableDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final style = context.uiType.body.copyWith(color: colors.textPrimary);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final canExpand = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: UiDuration.base,
              curve: UiCurves.iosSmooth,
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : _collapsedLines,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            if (canExpand || _expanded) ...[
              const SizedBox(height: UiSpacing.xs),
              Semantics(
                button: true,
                expanded: _expanded,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: UiSpacing.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded ? widget.lessLabel : widget.moreLabel,
                          style: context.uiType.footnote.copyWith(
                            color: colors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: UiSpacing.xs),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: UiDuration.base,
                          curve: UiCurves.iosSmooth,
                          child: Icon(
                            LucideIcons.chevronDown,
                            size: 14,
                            color: colors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
