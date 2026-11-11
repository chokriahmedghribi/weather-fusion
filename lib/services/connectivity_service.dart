import 'package:connectivity_plus/connectivity_plus.dart';

/// Note: this reports whether a network interface is up, not whether the
/// internet is reachable. A real failure still surfaces as a source error.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  bool _online(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  Future<bool> isOnline() async {
    try {
      return _online(await _connectivity.checkConnectivity());
    } catch (_) {
      return true; // Unknown: let the HTTP request decide.
    }
  }

  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_online).distinct();
}
