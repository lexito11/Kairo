import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/kairo_user.dart';
import '../../../core/models/live_stream.dart';

const _viewerQualifyAfter = Duration(seconds: 15);

class _ViewerWatch {
  _ViewerWatch({required this.streamId});

  final String streamId;
  Timer? qualifyTimer;
  bool counted = false;
}

class LiveCatalog extends ChangeNotifier {
  LiveCatalog._();
  static final LiveCatalog instance = LiveCatalog._();

  final List<LiveStream> _streams = List<LiveStream>.from(_demoStreams);
  final Map<String, List<LiveChatMessage>> _chats = {
    for (final s in _demoStreams) s.id: List<LiveChatMessage>.from(_demoChat(s.id)),
  };
  final Set<String> _liked = {};
  final Map<String, _ViewerWatch> _watches = {};

  List<LiveStream> get streams => List.unmodifiable(_streams.where((s) => s.isLive));

  LiveStream? byId(String id) {
    for (final s in _streams) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<LiveChatMessage> messagesFor(String id) =>
      List.unmodifiable(_chats[id] ?? const []);

  bool isLiked(String id) => _liked.contains(id);

  LiveStream startLive({
    required KairoUser host,
    required String title,
  }) {
    final stream = LiveStream(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      host: host,
      title: title.trim().isEmpty ? 'Transmisión en vivo' : title.trim(),
      orientation: '16:9',
      viewerCount: 1,
      totalViewers: 1,
      likesCount: 0,
      thumbnailUrl: host.image ?? _demoStreams.first.thumbnailUrl,
      tags: const [],
      isHostSession: true,
    );
    _streams.insert(0, stream);
    _chats[stream.id] = [
      LiveChatMessage(
        id: '${stream.id}-join',
        authorName: host.displayName,
        authorImage: host.image,
        content: 'se unió al en vivo',
        isJoin: true,
      ),
    ];
    notifyListeners();
    return stream;
  }

  void endLive(String id) {
    final i = _streams.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _streams[i] = _streams[i].copyWith(isLive: false);
    notifyListeners();
  }

  void like(String id) {
    final i = _streams.indexWhere((s) => s.id == id);
    if (i < 0 || _liked.contains(id)) return;
    _liked.add(id);
    _streams[i] = _streams[i].copyWith(likesCount: _streams[i].likesCount + 1);
    notifyListeners();
  }

  void sendMessage({
    required String streamId,
    required String authorName,
    required String? authorImage,
    required String content,
  }) {
    final text = content.trim();
    if (text.isEmpty) return;
    final list = _chats.putIfAbsent(streamId, () => []);
    list.add(
      LiveChatMessage(
        id: '$streamId-${DateTime.now().microsecondsSinceEpoch}',
        authorName: authorName,
        authorImage: authorImage,
        content: text,
      ),
    );
    notifyListeners();
  }

  void join(String streamId, String name, String? image) {
    final i = _streams.indexWhere((s) => s.id == streamId);
    final hostAlreadyCounted = i >= 0 && _streams[i].isHostSession && !_watches.containsKey(streamId);
    if (!_watches.containsKey(streamId) && !hostAlreadyCounted) {
      final watch = _ViewerWatch(streamId: streamId);
      watch.qualifyTimer = Timer(_viewerQualifyAfter, () {
        if (!_watches.containsKey(streamId) || watch.counted) return;
        watch.counted = true;
        _addQualifiedViewer(streamId);
      });
      _watches[streamId] = watch;
    }

    final list = _chats.putIfAbsent(streamId, () => []);
    list.add(
      LiveChatMessage(
        id: '$streamId-join-${DateTime.now().microsecondsSinceEpoch}',
        authorName: name,
        authorImage: image,
        content: 'se unió al en vivo',
        isJoin: true,
      ),
    );
    notifyListeners();
  }

  void leave(String streamId) {
    final watch = _watches.remove(streamId);
    if (watch == null) return;
    watch.qualifyTimer?.cancel();
    if (!watch.counted) return;
    final i = _streams.indexWhere((s) => s.id == streamId);
    if (i < 0) return;
    _streams[i] = _streams[i].copyWith(
      viewerCount: (_streams[i].viewerCount - 1).clamp(0, 1 << 30),
    );
    notifyListeners();
  }

  void _addQualifiedViewer(String streamId) {
    final i = _streams.indexWhere((s) => s.id == streamId);
    if (i < 0) return;
    final current = _streams[i];
    _streams[i] = current.copyWith(
      viewerCount: current.viewerCount + 1,
      totalViewers: current.qualifiedTotal + 1,
    );
    notifyListeners();
  }
}

const _kChurch = 'https://images.unsplash.com/photo-1438232992991-995b7058bbb3?w=1200&q=80';
const _kWorship = 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=1200&q=80';
const _kHands = 'https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=1200&q=80';
const _kPray = 'https://images.unsplash.com/photo-1478146896981-b80fe463b330?w=1200&q=80';

final _demoStreams = <LiveStream>[
  LiveStream(
    id: 'demo-maranatha',
    host: const KairoUser(id: 'demo-1', email: '', name: 'Iglesia Maranatha', image: _kChurch),
    title: 'Culto Dominical en Vivo 🙏',
    orientation: '16:9',
    viewerCount: 1200,
    likesCount: 3700,
    thumbnailUrl: _kWorship,
    tags: const ['culto', 'adoración'],
  ),
  LiveStream(
    id: 'demo-jovenes',
    host: const KairoUser(id: 'demo-5', email: '', name: 'Ministerio Joven', image: _kChurch),
    title: 'Encuentro de Jóvenes 🔥',
    orientation: '16:9',
    viewerCount: 248,
    likesCount: 516,
    thumbnailUrl: _kWorship,
    tags: const ['jóvenes', 'alabanza'],
  ),
  LiveStream(
    id: 'demo-carlos',
    host: const KairoUser(id: 'demo-2', email: '', name: 'Pastor Carlos', image: _kPray),
    title: 'Testimonio & Oración ✨',
    orientation: '16:9',
    viewerCount: 389,
    likesCount: 842,
    thumbnailUrl: _kHands,
  ),
  LiveStream(
    id: 'demo-centro',
    host: const KairoUser(id: 'demo-3', email: '', name: 'Centro Cristiano', image: _kChurch),
    title: 'Noche de Alabanza 🎵',
    orientation: '16:9',
    viewerCount: 654,
    likesCount: 2000,
    thumbnailUrl: _kWorship,
  ),
  LiveStream(
    id: 'demo-ana',
    host: const KairoUser(id: 'demo-4', email: '', name: 'Hermana Ana', image: _kPray),
    title: 'Devocional Mañanero 🌅',
    orientation: '16:9',
    viewerCount: 97,
    likesCount: 210,
    thumbnailUrl: _kHands,
  ),
];

List<LiveChatMessage> _demoChat(String id) {
  if (id == 'demo-centro') {
    return const [
      LiveChatMessage(id: 'c1', authorName: 'Diego H.', content: 'se unió al en vivo', isJoin: true),
      LiveChatMessage(id: 'c2', authorName: 'Carlos', content: 'Orando junto a ustedes'),
      LiveChatMessage(id: 'c3', authorName: 'María', content: 'Dios te bendiga 💙'),
      LiveChatMessage(id: 'c4', authorName: 'Pedro', content: '¡Amén! 🔥'),
      LiveChatMessage(id: 'c5', authorName: 'Ana', content: 'Desde Venezuela 🇻🇪'),
      LiveChatMessage(id: 'c6', authorName: 'Luis', content: 'Desde México 🇲🇽'),
    ];
  }
  return const [
    LiveChatMessage(id: 'm1', authorName: 'Maria G.', content: 'Gloria a Dios 🙌'),
    LiveChatMessage(id: 'm2', authorName: 'Pedro J.', content: 'Bendiciones desde Colombia'),
    LiveChatMessage(id: 'm3', authorName: 'Laura C.', content: 'Amén hermanos ❤️'),
    LiveChatMessage(id: 'm4', authorName: 'Diego H.', content: 'se unió al en vivo', isJoin: true),
  ];
}
