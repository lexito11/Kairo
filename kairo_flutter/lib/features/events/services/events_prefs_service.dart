import 'package:shared_preferences/shared_preferences.dart';

class EventsPrefsService {
  static const _hasRegisteredChurchKey = 'hasRegisteredChurch';
  static const _churchStatusKey = 'churchStatus';

  String _denominationKey(String userId) => 'denomination_$userId';

  Future<String?> getDenomination(String? userId) async {
    if (userId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_denominationKey(userId));
  }

  Future<void> setDenomination(String userId, String denomination) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_denominationKey(userId), denomination);
  }

  Future<bool> hasRegisteredChurch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasRegisteredChurchKey) ?? false;
  }

  Future<void> setRegisteredChurch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRegisteredChurchKey, value);
  }

  Future<String?> getChurchStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_churchStatusKey);
  }

  Future<void> setChurchStatus(String? status) async {
    final prefs = await SharedPreferences.getInstance();
    if (status == null) {
      await prefs.remove(_churchStatusKey);
    } else {
      await prefs.setString(_churchStatusKey, status);
    }
  }
}
