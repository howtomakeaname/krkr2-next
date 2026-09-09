import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_info.dart';
import '../l10n/app_localizations.dart';
import '../ui/ui.dart';
import 'legal_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static String get _iconAsset => Platform.operatingSystem == 'ohos'
      ? 'assets/branding/app_icon_ohos.png'
      : 'assets/branding/app_icon.png';

  void _openLegal(BuildContext context, LegalSection section) {
    UiMotion.push<void>(context, LegalPage(initialSection: section));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;

    return Scaffold(
      key: const ValueKey<String>('about-page'),
      backgroundColor: colors.groupedBackground,
      appBar: AppBar(
        title: Text(l10n.settingsAbout),
        backgroundColor: colors.groupedBackground,
        automaticallyImplyLeading: false,
        leading: UiBarIconButton(
          icon: LucideIcons.arrowLeft,
          semanticLabel: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: UiSpacing.xl),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                _iconAsset,
                key: const ValueKey<String>('about-app-icon'),
                width: 88,
                height: 88,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: UiSpacing.md),
          Text(
            AppInfo.nameForLanguage(l10n.localeName),
            key: const ValueKey<String>('about-app-name'),
            textAlign: TextAlign.center,
            style: context.uiType.title2,
          ),
          const SizedBox(height: UiSpacing.xxl),
          UiListSection(
            children: [
              UiListTile(title: l10n.version, trailingText: AppInfo.version),
              UiListTile(
                title: l10n.legalOpenSourceTitle,
                showChevron: true,
                onTap: () => _openLegal(context, LegalSection.openSource),
              ),
              UiListTile(
                title: l10n.legalPrivacyTitle,
                showChevron: true,
                onTap: () => _openLegal(context, LegalSection.privacy),
              ),
              UiListTile(
                title: l10n.legalDisclaimerTitle,
                showChevron: true,
                onTap: () => _openLegal(context, LegalSection.disclaimer),
              ),
            ],
          ),
          const SizedBox(height: UiSpacing.xxxl),
          Text(
            key: const ValueKey<String>('about-copyright'),
            AppInfo.copyrightLine(l10n.localeName),
            textAlign: TextAlign.center,
            style: context.uiType.footnote.copyWith(
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: UiSpacing.xxs),
          Text(
            'All rights reserved.',
            textAlign: TextAlign.center,
            style: context.uiType.footnote.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
