import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_info.dart';
import '../l10n/app_localizations.dart';
import '../ui/ui.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appName = AppInfo.nameForLanguage(l10n.localeName);
    final gamesPath = '${AppInfo.downloadDisplayRoot}/games';

    return Scaffold(
      key: const ValueKey<String>('help-page'),
      backgroundColor: context.uiColors.groupedBackground,
      appBar: AppBar(
        title: Text(l10n.help),
        backgroundColor: context.uiColors.groupedBackground,
        automaticallyImplyLeading: false,
        leading: UiBarIconButton(
          icon: LucideIcons.arrowLeft,
          semanticLabel: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: UiSpacing.xxxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UiSpacing.lg + UiSpacing.xs,
              UiSpacing.sm,
              UiSpacing.lg + UiSpacing.xs,
              UiSpacing.xs,
            ),
            child: Text(
              l10n.helpIntro,
              style: context.uiType.footnote.copyWith(
                color: context.uiColors.textSecondary,
              ),
            ),
          ),
          _HelpFaqSection(
            header: l10n.helpSectionLibrary,
            initiallyOpen: 0,
            items: [
              (l10n.helpFaqImportQ, l10n.helpFaqImportA),
              (l10n.helpFaqOhosQ, l10n.helpFaqOhosA(gamesPath)),
              (l10n.helpFaqIosQ, l10n.helpFaqIosA(appName)),
              (l10n.helpFaqLaunchQ, l10n.helpFaqLaunchA),
            ],
          ),
          _HelpFaqSection(
            header: l10n.helpSectionFiles,
            items: [
              (l10n.helpFaqManageQ, l10n.helpFaqManageA),
              (l10n.helpFaqArchiveQ, l10n.helpFaqArchiveA),
              (l10n.helpFaqRemoveQ, l10n.helpFaqRemoveA),
              (l10n.helpFaqMetadataQ, l10n.helpFaqMetadataA),
            ],
          ),
          _HelpFaqSection(
            header: l10n.helpSectionMore,
            items: [
              (l10n.helpFaqStatsQ, l10n.helpFaqStatsA),
              (l10n.helpFaqControlsQ, l10n.helpFaqControlsA),
              (l10n.helpFaqSettingsQ, l10n.helpFaqSettingsA),
              (l10n.helpFaqCompatQ, l10n.helpFaqCompatA),
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpFaqSection extends StatelessWidget {
  const _HelpFaqSection({
    required this.header,
    required this.items,
    this.initiallyOpen,
  });

  final String header;
  final List<(String, String)> items;
  final int? initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final answerStyle = context.uiType.body.copyWith(
      color: context.uiColors.textSecondary,
      height: 1.45,
    );

    return UiListSection(
      header: header,
      showDividers: false,
      children: [
        UiCollapseGroup(
          initialExpandedIndex: initiallyOpen,
          children: [
            for (final item in items)
              UiCollapse(
                title: item.$1,
                child: Text(item.$2, style: answerStyle),
              ),
          ],
        ),
      ],
    );
  }
}
