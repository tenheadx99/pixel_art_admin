import 'package:flutter/foundation.dart';

import '../core/flavors.dart';

/// Session-wide UI state: which flavor every screen is editing.
class AdminState extends ChangeNotifier {
  Flavor _flavor = kFlavors.first;

  Flavor get flavor => _flavor;

  set flavor(Flavor value) {
    if (value.id == _flavor.id) return;
    _flavor = value;
    notifyListeners();
  }
}
