part of '../patrol_point_screen.dart';

Future<void> _showPatrolCheckpointMetaDialog(
  BuildContext context, {
  required AppLocalizations l10n,
  required String title,
  required String body,
  VoidCallback? onEdit,
}) async {
  final mat = MaterialLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SelectableText(body),
      ),
      actions: [
        if (onEdit != null)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onEdit();
            },
            child: Text(l10n.patrolPointCheckpointMetaChange),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(mat.closeButtonLabel),
        ),
      ],
    ),
  );
}

