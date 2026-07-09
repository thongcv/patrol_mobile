part of '../patrol_round_screen.dart';

class _OverdueNoteDialog extends StatefulWidget {
  const _OverdueNoteDialog({
    required this.l10n,
    required this.point,
  });

  final AppLocalizations l10n;
  final CheckPoint point;

  @override
  State<_OverdueNoteDialog> createState() => _OverdueNoteDialogState();
}

class _OverdueNoteDialogState extends State<_OverdueNoteDialog> {
  static const Color _accent = Color(0xFFFBBF24);

  final _controller = TextEditingController();
  String? _errorText;

  AppLocalizations get l10n => widget.l10n;
  CheckPoint get point => widget.point;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = l10n.patrolRoundOverdueNoteEmpty);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

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
                    color: _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: _accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.patrolRoundOverdueNoteTitle,
                        style: theme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        point.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              l10n.patrolRoundOverdueNoteMessage,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              minLines: 3,
              style: theme.bodyMedium?.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.patrolRoundOverdueNoteHint,
                hintStyle: theme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _accent.withValues(alpha: 0.65),
                  ),
                ),
                errorText: _errorText,
                errorStyle: theme.bodySmall?.copyWith(
                  color: Colors.orangeAccent,
                ),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.patrolRoundCancel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF1F2937),
                    ),
                    child: Text(l10n.patrolRoundOverdueNoteSubmit),
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
