import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/user_dummy.dart';
import 'alert_service.dart';

/// Who is logged in (checked against the demo accounts in user_dummy.dart).
/// The login is remembered until the user signs out.
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  static const _prefsKey = 'logged_in_user';

  DummyUser? user;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    user = _find(prefs.getString(_prefsKey));
  }

  /// Returns false if the username or password is wrong
  Future<bool> signIn(String username, String password) async {
    final found = _find(username.trim().toLowerCase());
    if (found == null || found.password != password) return false;

    user = found;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, found.username);
    notifyListeners();
    await AlertService.instance.onSignedIn();
    return true;
  }

  Future<void> signOut() async {
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
    await AlertService.instance.onSignedOut();
  }

  static DummyUser? _find(String? username) {
    for (final u in dummyUsers) {
      if (u.username == username) return u;
    }
    return null;
  }
}
