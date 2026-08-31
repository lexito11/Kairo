import 'package:shared_preferences/shared_preferences.dart';

class EventsPrefsService {
  static const _hasRegisteredChurchKey = 'hasRegisteredChurch';
  static const _churchStatusKey = 'churchStatus';
  static const _deviceDenominationKey = 'denomination_device';

  String _denominationKey(String userId) => 'denomination_$userId';

  Future<String?> getDenomination(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null) {
      final forUser = prefs.getString(_denominationKey(userId));
      if (forUser != null && forUser.isNotEmpty) return forUser;
    }
    final device = prefs.getString(_deviceDenominationKey);
    if (device != null && device.isNotEmpty) return device;
    return null;
  }

  Future<void> setDenomination(String? userId, String denomination) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceDenominationKey, denomination);
    if (userId != null) {
      await prefs.setString(_denominationKey(userId), denomination);
    }
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
