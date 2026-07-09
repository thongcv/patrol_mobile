part of '../patrol_round_screen.dart';

class _QrPhotoConfirmDialog extends StatefulWidget {
  const _QrPhotoConfirmDialog({
    required this.l10n,
    required this.point,
  });

  final AppLocalizations l10n;
  final CheckPoint point;

  @override
  State<_QrPhotoConfirmDialog> createState() => _QrPhotoConfirmDialogState();
}

class _QrPhotoConfirmDialogState extends State<_QrPhotoConfirmDialog> {
  static const Color _success = Color(0xFF34D399);
  static const int _imageQuality = 85;

  final _photos = <String>[];
  final _picker = ImagePicker();
  bool _capturing = false;

  AppLocalizations get l10n => widget.l10n;
  CheckPoint get point => widget.point;

  Future<void> _takePhoto() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: _imageQuality,
      );
      if (!mounted || file == null) return;
      setState(() => _photos.add(file.path));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _popWithPhotos() {
    Navigator.of(context).pop(List<String>.from(_photos));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final hasPhotos = _photos.isNotEmpty;

    return Dialog(
      backgroundColor: PatrolShellColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: _success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.patrolRoundQrScanSuccess,
                        style: theme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.patrolRoundQrPhotoTitle,
                        style: theme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: PatrolShellColors.surfaceElevated.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${point.sequenceOrder}',
                      style: theme.labelLarge?.copyWith(
                        color: const Color(0xFF6EE7B7),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.patrolRoundQrPhotoMessage,
              style: theme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.35,
              ),
            ),
            if (hasPhotos) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = _photos[index];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(path),
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 76,
                              height: 76,
                              color: PatrolShellColors.surfaceElevated,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white38,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Material(
                            color: PatrolShellColors.background,
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: () => _removePhoto(index),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: Colors.white70,
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              tooltip: l10n.patrolRoundQrPhotoRemove,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.patrolRoundCancel),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: hasPhotos
                        ? _popWithPhotos
                        : () => Navigator.of(context).pop(<String>[]),
                    style: TextButton.styleFrom(
                      foregroundColor: PatrolShellColors.accentMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      hasPhotos
                          ? l10n.patrolRoundQrPhotoDone(_photos.length)
                          : l10n.patrolRoundQrPhotoSkip,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: hasPhotos
                      ? l10n.patrolRoundQrPhotoAddMore
                      : l10n.patrolRoundQrPhotoTake,
                  child: FilledButton(
                    onPressed: _capturing ? null : _takePhoto,
                    style: FilledButton.styleFrom(
                      backgroundColor: PatrolShellColors.accent,
                      foregroundColor: PatrolShellColors.background,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(52, 52),
                      maximumSize: const Size(52, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _capturing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: PatrolShellColors.background,
                            ),
                          )
                        : Icon(
                            hasPhotos
                                ? Icons.add_a_photo_rounded
                                : Icons.photo_camera_rounded,
                            size: 26,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

