import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../services/manager_file_kind.dart';
import '../ui/ui.dart';

/// Full-screen preview for a managed image, audio, video or text file.
class ManagerMediaPage extends StatelessWidget {
  const ManagerMediaPage({super.key, required this.path, required this.kind});

  final String path;
  final ManagerFileKind kind;

  static Future<void> open(
    BuildContext context, {
    required String path,
    required ManagerFileKind kind,
  }) {
    if (kind == ManagerFileKind.image && !path.toLowerCase().endsWith('.svg')) {
      return UiImageViewer.show(context, images: [FileImage(File(path))]);
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ManagerMediaPage(path: path, kind: kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.uiColors.background,
      appBar: AppBar(
        title: Text(p.basename(path)),
        backgroundColor: context.uiColors.background,
        automaticallyImplyLeading: false,
        leading: UiBarIconButton(
          icon: LucideIcons.arrowLeft,
          semanticLabel: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: switch (kind) {
        ManagerFileKind.image => _ImagePreview(path: path),
        ManagerFileKind.text => _TextPreview(path: path),
        _ => _AvPreview(path: path, kind: kind),
      },
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final lower = path.toLowerCase();
    final child = lower.endsWith('.svg')
        ? SvgPicture.file(File(path), fit: BoxFit.contain)
        : Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => _MediaError(
              message: AppLocalizations.of(context)!.managerMediaFailed,
            ),
          );
    return Center(
      child: InteractiveViewer(minScale: 0.5, maxScale: 8, child: child),
    );
  }
}

class _TextPreview extends StatefulWidget {
  const _TextPreview({required this.path});

  final String path;

  @override
  State<_TextPreview> createState() => _TextPreviewState();
}

class _TextPreviewState extends State<_TextPreview> {
  late final Future<ManagerTextPreview> _load = File(
    widget.path,
  ).readAsBytes().then(decodeManagedText);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<ManagerTextPreview>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MediaError(message: l10n.managerMediaFailed);
        }
        final preview = snapshot.data;
        if (preview == null) {
          return const Center(child: UiLoader());
        }
        if (preview.text.isEmpty) {
          return Center(
            child: Text(
              l10n.managerTextEmpty,
              style: context.uiType.body.copyWith(
                color: context.uiColors.textSecondary,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (preview.truncated)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.managerTextTruncated,
                  style: context.uiType.caption.copyWith(
                    color: context.uiColors.textSecondary,
                  ),
                ),
              ),
            SelectableText(
              preview.text,
              style: context.uiType.body.copyWith(height: 1.45),
            ),
          ],
        );
      },
    );
  }
}

class _AvPreview extends StatefulWidget {
  const _AvPreview({required this.path, required this.kind});

  final String path;
  final ManagerFileKind kind;

  @override
  State<_AvPreview> createState() => _AvPreviewState();
}

class _AvPreviewState extends State<_AvPreview> {
  VideoPlayerController? _player;
  var _seeking = false;

  @override
  void initState() {
    super.initState();
    final player = VideoPlayerController.file(File(widget.path));
    _player = player;
    player.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      player.play();
    });
    player.addListener(_onTick);
  }

  @override
  void dispose() {
    _player
      ?..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _onTick() {
    if (!_seeking && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final player = _player;
    if (player == null) {
      return const Center(child: UiLoader());
    }
    final error = player.value.errorDescription;
    if (error != null) {
      return _MediaError(message: l10n.managerMediaFailed);
    }
    if (!player.value.isInitialized) {
      return const Center(child: UiLoader());
    }

    final colors = context.uiColors;
    final duration = player.value.duration;
    final position = player.value.position;
    final totalMs = duration.inMilliseconds;
    final audioOnly =
        widget.kind == ManagerFileKind.audio ||
        player.value.size.isEmpty ||
        player.value.size.longestSide < 2;

    return Column(
      children: [
        Expanded(
          child: audioOnly
              ? Center(
                  child: Icon(
                    CupertinoIcons.music_note_2,
                    size: 88,
                    color: colors.brand,
                  ),
                )
              : Center(
                  child: AspectRatio(
                    aspectRatio: player.value.aspectRatio == 0
                        ? 16 / 9
                        : player.value.aspectRatio,
                    child: VideoPlayer(player),
                  ),
                ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              UiSlider(
                value: totalMs <= 0
                    ? 0
                    : position.inMilliseconds.clamp(0, totalMs).toDouble(),
                max: totalMs <= 0 ? 1 : totalMs.toDouble(),
                onChanged: (value) {
                  _seeking = true;
                  player.seekTo(Duration(milliseconds: value.round()));
                },
                onChangeEnd: (_) => _seeking = false,
              ),
              Row(
                children: [
                  Text(
                    _clock(position),
                    style: context.uiType.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  UiBarIconButton(
                    icon: player.value.isPlaying
                        ? LucideIcons.pause
                        : LucideIcons.play,
                    semanticLabel: player.value.isPlaying
                        ? l10n.managerPause
                        : l10n.managerPlay,
                    onPressed: () {
                      if (player.value.isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                  ),
                  const Spacer(),
                  Text(
                    _clock(duration),
                    style: context.uiType.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _clock(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UiSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.uiType.body.copyWith(
            color: context.uiColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
