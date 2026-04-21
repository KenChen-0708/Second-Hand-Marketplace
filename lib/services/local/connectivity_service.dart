import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged
      .map(_isOnline)
      .distinct();

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return _isOnline(result);
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
