import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../l10n/file_manager_localizations.dart';
import '../services/file_manager_controller.dart';
import '../services/file_operation_error.dart';
import '../services/local_file_service.dart';
import '../ui/ui.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({super.key, required this.controller});

  final FileManagerController controller;

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  FileManagerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChanged);
    if (controller.grant == null && !controller.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.grant == null && !controller.loading) {
          controller.load();
        }
      });
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    final error = controller.lastError;
    if (error == null) return;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    UiToast.show(
      context,
      message: l10n.fileOperationError(error.code),
      type: UiToastType.error,
    );
    controller.lastError = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 8),
            child: SizedBox(
              height: UiNavigationMetrics.buttonExtent,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.selecting
                          ? l10n.managerItemsSelected(
                              controller.selected.length,
                            )
                          : l10n.tabManage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiType.headline.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (controller.grant != null)
                    UiGlassToolbar(
                      children: [
                        UiGlassIconButton(
                          icon: controller.selecting
                              ? LucideIcons.check
                              : LucideIcons.listChecks,
                          semanticLabel: controller.selecting
                              ? l10n.managerDone
                              : l10n.managerSelect,
                          contained: false,
                          onPressed: () =>
                              controller.toggleSelecting(!controller.selecting),
                        ),
                        Builder(
                          builder: (buttonContext) => UiGlassIconButton(
                            icon: LucideIcons.ellipsis,
                            semanticLabel: l10n.tabManage,
                            contained: false,
                            onPressed: () => _showMenu(buttonContext, l10n),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (controller.grant != null) _buildBreadcrumb(l10n),
          if (controller.task != null) _buildProgress(l10n),
          Expanded(child: _buildBody(l10n)),
          if (controller.selecting && controller.selected.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 12),
              child: UiGlassToolbar(
                variant: UiGlassVariant.regular,
                children: [
                  UiGlassIconButton(
                    icon: LucideIcons.copy,
                    semanticLabel: l10n.managerCopy,
                    contained: false,
                    onPressed: () => _pickDestination(copy: true),
                  ),
                  UiGlassIconButton(
                    icon: LucideIcons.folderInput,
                    semanticLabel: l10n.managerMove,
                    contained: false,
                    onPressed: () => _pickDestination(copy: false),
                  ),
                  UiGlassIconButton(
                    icon: LucideIcons.trash2,
                    semanticLabel: l10n.managerTrash,
                    contained: false,
                    foregroundColor: colors.danger,
                    onPressed: () => _confirmTrash(l10n),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(AppLocalizations l10n) {
    final labels = controller.breadcrumbLabels();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: UiBreadcrumb(
        items: [
          for (var i = 0; i < labels.length; i++)
            UiBreadcrumbItem(
              label: i == 0 ? controller.grant!.displayRoot : labels[i],
              onTap: () => controller.openBreadcrumb(i),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress(AppLocalizations l10n) {
    final task = controller.task!;
    final value = task.total <= 0 ? null : task.completed / task.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.currentName.isEmpty ? l10n.managerWorking : task.currentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiType.caption,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: UiProgress(value: value)),
              const SizedBox(width: 8),
              UiButton(
                label: l10n.managerCancel,
                variant: UiButtonVariant.ghost,
                size: UiButtonSize.small,
                onPressed: controller.cancelTask,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (controller.loading) {
      return const Center(child: UiLoader());
    }
    if (controller.grant == null) {
      return UiEmpty(
        icon: LucideIcons.folderLock,
        title: l10n.tabManage,
        description: l10n.managerAuthorizationHint,
        actionLabel: l10n.managerAuthorize,
        onAction: controller.authorize,
      );
    }
    if (controller.entries.isEmpty) {
      return UiEmpty(
        icon: LucideIcons.folder,
        title: l10n.managerEmpty,
        actionLabel: l10n.managerNewFolder,
        onAction: () => _createFolder(l10n),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        bottom: MediaQuery.paddingOf(context).bottom + 88,
      ),
      itemCount: controller.entries.length,
      itemBuilder: (context, index) {
        final entry = controller.entries[index];
        final selected = controller.selected.contains(entry.path);
        return Builder(
          builder: (tileContext) => UiListTile(
            title: entry.name,
            subtitle: entry.isDirectory ? null : _sizeLabel(entry),
            icon: entry.isDirectory ? CupertinoIcons.folder : CupertinoIcons.doc,
            trailing: controller.selecting
                ? Icon(
                    selected
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color: selected
                        ? context.uiColors.brand
                        : context.uiColors.textTertiary,
                  )
                : null,
            onTap: () {
              if (controller.selecting) {
                controller.toggle(entry.path);
              } else if (entry.isDirectory) {
                controller.open(entry.path);
              }
            },
            onLongPress: () => _showItemMenu(tileContext, entry, l10n),
          ),
        );
      },
    );
  }

  String _sizeLabel(LocalFileEntry entry) {
    final bytes = entry.stat.size;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _showMenu(BuildContext buttonContext, AppLocalizations l10n) {
    return UiPopupMenu.show<void>(
      context,
      anchor: UiPopupMenu.rectOf(buttonContext),
      items: [
        UiMenuItem(
          label: l10n.managerNewFolder,
          icon: LucideIcons.folderPlus,
          onSelected: () => _createFolder(l10n),
        ),
        UiMenuItem(
          label: l10n.managerSelectAll,
          icon: LucideIcons.listChecks,
          onSelected: () {
            controller.toggleSelecting(true);
            controller.selectAll();
          },
        ),
        UiMenuItem(
          label: l10n.managerRecentlyDeleted,
          icon: LucideIcons.trash2,
          onSelected: () => _showTrash(l10n),
        ),
      ],
    );
  }

  Future<void> _showItemMenu(
    BuildContext tileContext,
    LocalFileEntry entry,
    AppLocalizations l10n,
  ) {
    return UiPopupMenu.show<void>(
      context,
      anchor: UiPopupMenu.rectOf(tileContext),
      items: [
        UiMenuItem(
          label: l10n.managerRename,
          icon: LucideIcons.pencil,
          onSelected: () => _rename(entry, l10n),
        ),
        UiMenuItem(
          label: l10n.managerCopy,
          icon: LucideIcons.copy,
          onSelected: () {
            controller
              ..toggleSelecting(true)
              ..selected.add(entry.path);
            _pickDestination(copy: true);
          },
        ),
        UiMenuItem(
          label: l10n.managerMove,
          icon: LucideIcons.folderInput,
          onSelected: () {
            controller
              ..toggleSelecting(true)
              ..selected.add(entry.path);
            _pickDestination(copy: false);
          },
        ),
        if (controller.looksLikeArchive(entry.name))
          UiMenuItem(
            label: l10n.managerExtract,
            icon: LucideIcons.packageOpen,
            onSelected: () => _extract(entry, l10n),
          ),
        UiMenuItem(
          label: l10n.managerTrash,
          icon: LucideIcons.trash2,
          isDestructive: true,
          onSelected: () {
            controller
              ..toggleSelecting(true)
              ..selected.add(entry.path);
            _confirmTrash(l10n);
          },
        ),
      ],
    );
  }

  Future<void> _createFolder(AppLocalizations l10n) async {
    final name = await _promptName(l10n, l10n.managerNewFolder);
    if (name == null) return;
    await controller.createFolder(name);
  }

  Future<void> _rename(LocalFileEntry entry, AppLocalizations l10n) async {
    final name = await _promptName(
      l10n,
      l10n.managerRename,
      initial: entry.name,
    );
    if (name == null) return;
    await controller.rename(entry.path, name);
  }

  Future<String?> _promptName(
    AppLocalizations l10n,
    String title, {
    String? initial,
  }) async {
    final input = TextEditingController(text: initial);
    final result = await UiDialog.show<String>(
      context,
      title: title,
      content: UiInput(
        controller: input,
        label: l10n.managerName,
        autofocus: true,
      ),
      actions: [
        UiDialogAction(label: l10n.managerCancel),
        UiDialogAction(
          label: l10n.managerDone,
          isDefault: true,
          onPressed: () => Navigator.of(context).pop(input.text.trim()),
        ),
      ],
    );
    input.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<void> _confirmTrash(AppLocalizations l10n) async {
    final confirmed = await UiDialog.show<bool>(
      context,
      title: l10n.managerTrash,
      message: '${l10n.managerTrashConfirm}\n${l10n.managerTrashExplanation}',
      actions: [
        UiDialogAction(label: l10n.managerCancel, returnValue: false),
        UiDialogAction(
          label: l10n.managerTrash,
          isDestructive: true,
          returnValue: true,
        ),
      ],
    );
    if (confirmed == true) await controller.trashSelected();
  }

  Future<void> _showTrash(AppLocalizations l10n) async {
    await controller.refresh();
    if (!mounted) return;
    await UiBottomSheet.show<void>(
      context,
      title: l10n.managerRecentlyDeleted,
      child: controller.trash.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.managerTrashHint, style: context.uiType.body),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.managerTrashHint,
                    style: context.uiType.caption,
                  ),
                ),
                for (final item in controller.trash)
                  UiListTile(
                    title: p.basename(item.originalPath),
                    subtitle: item.deletedAt.toLocal().toString(),
                    icon: LucideIcons.trash2,
                    onTap: () => _trashActions(item, l10n),
                  ),
              ],
            ),
    );
  }

  Future<void> _trashActions(DeletedFile item, AppLocalizations l10n) async {
    final restore = await UiDialog.show<bool>(
      context,
      title: p.basename(item.originalPath),
      actions: [
        UiDialogAction(label: l10n.managerCancel),
        UiDialogAction(label: l10n.managerRestore, returnValue: true),
        UiDialogAction(
          label: l10n.managerDeletePermanently,
          isDestructive: true,
          returnValue: false,
        ),
      ],
    );
    if (restore == true) {
      await controller.restore(item);
    } else if (restore == false) {
      final confirmed = await UiDialog.show<bool>(
        context,
        title: l10n.managerDeletePermanently,
        message:
            '${l10n.managerPermanentConfirm}\n${l10n.managerPermanentExplanation}',
        actions: [
          UiDialogAction(label: l10n.managerCancel, returnValue: false),
          UiDialogAction(
            label: l10n.managerDeletePermanently,
            isDestructive: true,
            returnValue: true,
          ),
        ],
      );
      if (confirmed == true) await controller.permanentlyDelete(item);
    }
  }

  Future<void> _pickDestination({required bool copy}) async {
    final l10n = AppLocalizations.of(context)!;
    final service = controller.files;
    if (service == null) return;
    var cursor = controller.currentPath;
    final destination = await UiBottomSheet.show<String>(
      context,
      title: l10n.managerChooseDestination,
      child: _DestinationBrowser(
        service: service,
        initialPath: cursor,
        useLabel: l10n.managerUseFolder,
        onUse: (path) => Navigator.of(context).pop(path),
      ),
    );
    if (destination == null) return;
    if (copy) {
      await controller.copyTo(destination);
    } else {
      await controller.moveTo(destination);
    }
  }

  Future<void> _extract(LocalFileEntry entry, AppLocalizations l10n) async {
    var codepage = 65001;
    final password = TextEditingController();
    final confirmed = await UiDialog.show<bool>(
      context,
      title: l10n.managerExtractTitle,
      content: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.managerExtractHint, style: context.uiType.caption),
            const SizedBox(height: 12),
            UiInput(
              controller: password,
              label: l10n.managerPassword,
              obscureText: true,
            ),
            const SizedBox(height: 12),
            UiDropdown<int>(
              label: l10n.managerEncoding,
              value: codepage,
              items: [
                UiDropdownItem(value: 65001, label: l10n.managerEncodingUtf8),
                UiDropdownItem(
                  value: 54936,
                  label: l10n.managerEncodingGb18030,
                ),
                UiDropdownItem(value: 932, label: l10n.managerEncodingCp932),
              ],
              onChanged: (value) => setDialogState(() => codepage = value),
            ),
          ],
        ),
      ),
      actions: [
        UiDialogAction(label: l10n.managerCancel, returnValue: false),
        UiDialogAction(
          label: l10n.managerExtract,
          isDefault: true,
          returnValue: true,
        ),
      ],
    );
    final secret = password.text;
    password.clear();
    password.dispose();
    if (confirmed != true) return;
    await controller.extract(
      entry.path,
      password: secret.isEmpty ? null : secret,
      legacyCodepage: codepage,
    );
  }
}

class _DestinationBrowser extends StatefulWidget {
  const _DestinationBrowser({
    required this.service,
    required this.initialPath,
    required this.useLabel,
    required this.onUse,
  });

  final LocalFileService service;
  final String initialPath;
  final String useLabel;
  final ValueChanged<String> onUse;

  @override
  State<_DestinationBrowser> createState() => _DestinationBrowserState();
}

class _DestinationBrowserState extends State<_DestinationBrowser> {
  late String _path;
  List<LocalFileEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.service.list(_path);
    if (!mounted) return;
    setState(() {
      _entries = entries.where((entry) => entry.isDirectory).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UiListTile(
          title: p.basename(_path).isEmpty
              ? widget.service.rootPath
              : p.basename(_path),
          icon: LucideIcons.folder,
        ),
        if (!p.equals(_path, widget.service.rootPath))
          UiListTile(
            title: '..',
            icon: LucideIcons.cornerLeftUp,
            onTap: () {
              _path = p.dirname(_path);
              _load();
            },
          ),
        for (final entry in _entries)
          UiListTile(
            title: entry.name,
            icon: CupertinoIcons.folder,
            showChevron: true,
            onTap: () {
              _path = entry.path;
              _load();
            },
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: UiButton(
            label: widget.useLabel,
            fullWidth: true,
            onPressed: () => widget.onUse(_path),
          ),
        ),
      ],
    );
  }
}
