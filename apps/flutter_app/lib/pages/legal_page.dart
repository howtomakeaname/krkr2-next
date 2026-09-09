import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../legal/legal_documents.dart';
import '../ui/ui.dart';

enum LegalSection { openSource, privacy, disclaimer }

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, this.initialSection = LegalSection.openSource});

  final LegalSection initialSection;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late LegalSection _section = widget.initialSection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final documents = LegalDocuments(l10n.localeName);
    final body = switch (_section) {
      LegalSection.openSource => documents.openSource,
      LegalSection.privacy => documents.privacy,
      LegalSection.disclaimer => documents.disclaimer,
    };
    final title = switch (_section) {
      LegalSection.openSource => l10n.legalOpenSourceTitle,
      LegalSection.privacy => l10n.legalPrivacyTitle,
      LegalSection.disclaimer => l10n.legalDisclaimerTitle,
    };

    return Scaffold(
      key: const ValueKey<String>('legal-page'),
      backgroundColor: context.uiColors.groupedBackground,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: context.uiColors.groupedBackground,
        automaticallyImplyLeading: false,
        leading: UiBarIconButton(
          icon: LucideIcons.arrowLeft,
          semanticLabel: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: UiSegmented<LegalSection>(
                value: _section,
                items: [
                  UiSegmentedItem(
                    value: LegalSection.openSource,
                    label: l10n.legalTabOpenSource,
                  ),
                  UiSegmentedItem(
                    value: LegalSection.privacy,
                    label: l10n.legalTabPrivacy,
                  ),
                  UiSegmentedItem(
                    value: LegalSection.disclaimer,
                    label: l10n.legalTabDisclaimer,
                  ),
                ],
                onChanged: (value) {
                  if (value == _section) return;
                  setState(() => _section = value);
                },
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: ValueKey<LegalSection>(_section),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                Text(
                  l10n.legalUpdated(LegalDocuments.updatedOn),
                  style: context.uiType.footnote.copyWith(
                    color: context.uiColors.textSecondary,
                  ),
                ),
                const SizedBox(height: UiSpacing.md),
                UiCard(
                  key: ValueKey<String>('legal-section-${_section.name}'),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: SelectableText(
                    body.trim(),
                    style: context.uiType.body.copyWith(
                      height: 1.5,
                      color: context.uiColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
