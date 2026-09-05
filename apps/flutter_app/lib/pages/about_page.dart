import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../ui/ui.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _email = 'wangguanzhiabcd@126.com';
  static final _repository = Uri.parse(
    'https://github.com/reAAAq/KrKr2-Next',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      key: const ValueKey<String>('about-page'),
      backgroundColor: context.uiColors.groupedBackground,
      appBar: AppBar(
        title: Text(l10n.settingsAbout),
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
            children: [
              UiListTile(
                icon: LucideIcons.flaskConical,
                title: l10n.version,
                subtitle: l10n.aboutVersionDesc,
                trailingText: '1.0.0',
              ),
              UiListTile(
                icon: LucideIcons.user,
                title: l10n.aboutAuthor,
                trailingText: 'reAAAq',
              ),
            ],
          ),
          const SizedBox(height: UiSpacing.sm),
          UiListSection(
            children: [
              UiListTile(
                icon: LucideIcons.mail,
                title: l10n.aboutEmail,
                subtitle: _email,
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: _email));
                  UiSnackbar.show(
                    context,
                    message: l10n.aboutEmailCopied,
                    type: UiSnackbarType.success,
                    duration: const Duration(seconds: 2),
                  );
                },
              ),
              UiListTile(
                icon: LucideIcons.code,
                title: 'GitHub',
                subtitle: 'github.com/reAAAq/KrKr2-Next',
                showChevron: true,
                onTap: () => launchUrl(
                  _repository,
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
