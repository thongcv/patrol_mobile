import 'package:sps/l10n/app_localizations.dart';

String patrolServerCoordLabel(
  AppLocalizations l10n,
  double lat,
  double lng, {
  double? altitude,
}) {
  final latStr = lat.toStringAsFixed(6);
  final lngStr = lng.toStringAsFixed(6);
  if (altitude != null && altitude.isFinite) {
    return l10n.patrolPointServerCoordsWithAlt(
      latStr,
      lngStr,
      altitude.toStringAsFixed(1),
    );
  }
  return l10n.patrolPointServerCoords(latStr, lngStr);
}
