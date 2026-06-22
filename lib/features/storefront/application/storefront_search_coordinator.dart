import 'package:flutter/foundation.dart';

class StorefrontSearchCoordinator extends ChangeNotifier {
  StorefrontSearchCoordinator._();

  static final StorefrontSearchCoordinator instance =
      StorefrontSearchCoordinator._();

  int _requestVersion = 0;

  int get requestVersion => _requestVersion;

  void requestSearch() {
    _requestVersion++;
    notifyListeners();
  }
}
