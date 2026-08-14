import 'package:flutter/foundation.dart';

/// Shared "client-switcher" state used by Workout Builder, Nutrition (and
/// future Chat) — NOT Client Detail, which takes an explicit clientId route
/// argument instead. See trainer-console-spec / design handoff README.
class ActiveClientProvider extends ChangeNotifier {
  String? _activeClientId;
  bool _pickerOpen = false;

  String? get activeClientId => _activeClientId;
  bool get pickerOpen => _pickerOpen;

  void setActiveClient(String clientId) {
    _activeClientId = clientId;
    _pickerOpen = false;
    notifyListeners();
  }

  void togglePicker() {
    _pickerOpen = !_pickerOpen;
    notifyListeners();
  }
}
