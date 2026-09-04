import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../ui/ui.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
        padding: const EdgeInsets.symmetric(vertical: UiSpacing.sm),
        children: [
          UiListSection(
            showDividers: false,
            children: [
              UiListTile(
                icon: LucideIcons.folderOpen,
                title: l10n.helpImportTitle,
                subtitle: l10n.helpImportBody,
              ),
              UiListTile(
                icon: LucideIcons.play,
                title: l10n.helpLaunchTitle,
                subtitle: l10n.helpLaunchBody,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
