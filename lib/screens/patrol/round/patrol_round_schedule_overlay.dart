part of '../patrol_round_screen.dart';

/// Bottom sheet body for the schedule overlay. Pure UI wrapper around
/// [_ScheduleCard]; dismisses on the drag handle or a downward overscroll.
class _ScheduleSheet extends StatelessWidget {
  const _ScheduleSheet({
    required this.theme,
    required this.loading,
    required this.failure,
    required this.data,
    required this.messageForFailure,
  });

  final TextTheme theme;
  final bool loading;
  final ApiFailure? failure;
  final ActivePatrolRound? data;
  final String Function(ApiFailure, AppLocalizations) messageForFailure;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final h = MediaQuery.sizeOf(context).height;

    void closeSheet() {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }

    const handleReserve = 40.0;
    final maxBodyHeight = (h * 0.88 - handleReserve).clamp(120.0, h);
    final scrollPhysics = AlwaysScrollableScrollPhysics(
      parent: Theme.of(context).platform == TargetPlatform.iOS
          ? const BouncingScrollPhysics()
          : const ClampingScrollPhysics(),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + pad.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: h * 0.88),
          child: Material(
            color: PatrolShellColors.surface,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetVerticalDismissHandle(onDismiss: closeSheet),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxBodyHeight,
                  ),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification n) {
                      if (n is! OverscrollNotification) {
                        return false;
                      }
                      if (n.overscroll.abs() >= 20) {
                        closeSheet();
                        return true;
                      }
                      return false;
                    },
                    child: ListView(
                      shrinkWrap: true,
                      physics: scrollPhysics,
                      padding: const EdgeInsets.all(4),
                      children: [
                        _ScheduleCard(
                          theme: theme,
                          l10n: AppLocalizations.of(context)!,
                          loading: loading,
                          failure: failure,
                          data: data,
                          failureMessage: failure != null
                              ? messageForFailure(
                                  failure!,
                                  AppLocalizations.of(context)!,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
