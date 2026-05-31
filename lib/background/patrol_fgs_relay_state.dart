/// Main-isolate callbacks wired by coordinators — read at FGS relay invoke time.
abstract final class PatrolFgsRelayState {
  PatrolFgsRelayState._();

  static void Function()? relayFgsMockLocationAlert;
}
