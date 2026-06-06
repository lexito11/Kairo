import 'package:flutter/foundation.dart';

class SocialSummaryProvider extends ChangeNotifier {
  int unreadCount = 0;
  int friendsCount = 0;

  void update({required int unread, required int friends}) {
    unreadCount = unread;
    friendsCount = friends;
    notifyListeners();
  }
}
