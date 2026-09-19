import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/live_stream.dart';
import 'live_repository.dart';

class LiveFeedController extends ChangeNotifier {
  LiveFeedController._();
  static final LiveFeedController instance = LiveFeedController._();

  final LiveRepository _repo = LiveRepository();
  RealtimeChannel? _channel;

  List<LiveStream> _streams = const [];
  bool loading = false;
  bool loaded = false;
  String? error;

  List<LiveStream> get streams => List.unmodifiable(_streams);

  Future<void> ensureStarted() async {
    _listen();
    await refresh();
  }

  void _listen() {
    _channel ??= _repo.subscribeFeed(() {
      refresh();
    });
  }

  Future<void> refresh() async {
    loading = _streams.isEmpty;
    error = null;
    notifyListeners();
    try {
      _streams = await _repo.fetchLiveStreams();
      loaded = true;
    } catch (e) {
      error = _repo.mapError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    super.dispose();
  }
}
