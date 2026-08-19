import 'package:flutter/foundation.dart';

import '../models/church_application.dart';
import '../services/churches_repository.dart';

class ChurchAdminProvider extends ChangeNotifier {
  ChurchAdminProvider({ChurchesRepository? repository})
      : _repository = repository ?? ChurchesRepository();

  final ChurchesRepository _repository;

  bool loading = true;
  bool actionLoading = false;
  bool isAdmin = false;
  String? error;
  List<ChurchApplication> pendingApplications = [];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      isAdmin = await _repository.isCurrentUserAdmin();
      if (!isAdmin) {
        pendingApplications = [];
        return;
      }
      pendingApplications = await _repository.fetchPendingApplications();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> approve(String churchId) async {
    return _review(churchId, approve: true);
  }

  Future<String?> reject(String churchId, {String? motivoRechazo}) async {
    return _review(churchId, approve: false, motivoRechazo: motivoRechazo);
  }

  Future<String?> _review(
    String churchId, {
    required bool approve,
    String? motivoRechazo,
  }) async {
    actionLoading = true;
    error = null;
    notifyListeners();

    try {
      await _repository.reviewChurch(
        churchId,
        approve: approve,
        motivoRechazo: motivoRechazo,
      );
      pendingApplications = pendingApplications.where((c) => c.id != churchId).toList();
      return null;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      error = msg;
      return msg;
    } finally {
      actionLoading = false;
      notifyListeners();
    }
  }
}
