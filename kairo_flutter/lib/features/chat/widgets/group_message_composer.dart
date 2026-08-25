import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/kairo_colors.dart';

typedef GroupMessageSend = Future<void> Function({
  required String text,
  Uint8List? mediaBytes,
  String? fileName,
  String? mimeType,
  String? stickerEmoji,
});

class GroupMessageComposer extends StatefulWidget {
  const GroupMessageComposer({
    super.key,
    required this.canSend,
    required this.onSend,
    this.readOnlyHint,
  });

  final bool canSend;
  final GroupMessageSend onSend;
  final String? readOnlyHint;

  @override
  State<GroupMessageComposer> createState() => _GroupMessageComposerState();
}

class _GroupMessageComposerState extends State<GroupMessageComposer> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  bool _sending = false;
  bool _showEmoji = false;

  static const _stickers = [
    '🙏', '✝️', '🕊️', '❤️', '😇', '😊', '🎉', '🔥',
    '💪', '🌟', '✨', '📖', '🎵', '👏', '🤗', '💯',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || !widget.canSend) return;
    await _dispatch(text: text);
  }

  Future<void> _sendSticker(String emoji) async {
    if (_sending || !widget.canSend) return;
    setState(() => _showEmoji = false);
    await _dispatch(stickerEmoji: emoji);
  }

  Future<void> _pickImage() async {
    if (_sending || !widget.canSend) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _dispatch(
      mediaBytes: bytes,
      fileName: file.name,
      mimeType: 'image/jpeg',
    );
  }

  Future<void> _pickAudio() async {
    if (_sending || !widget.canSend) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'webm'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    await _dispatch(
      mediaBytes: bytes,
      fileName: file.name,
      mimeType: _audioMime(file.extension),
    );
  }

  String _audioMime(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'webm':
        return 'audio/webm';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
      default:
        return 'audio/mp4';
    }
  }

  Future<void> _dispatch({
    String text = '',
    Uint8List? mediaBytes,
    String? fileName,
    String? mimeType,
    String? stickerEmoji,
  }) async {
    setState(() => _sending = true);
    try {
      await widget.onSend(
        text: text,
        mediaBytes: mediaBytes,
        fileName: fileName,
        mimeType: mimeType,
        stickerEmoji: stickerEmoji,
      );
      if (stickerEmoji == null && mediaBytes == null) {
        _controller.clear();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final canSend = widget.canSend;

    if (!canSend) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPad + 14),
        decoration: const BoxDecoration(
          color: KairoColors.darkBg,
          border: Border(top: BorderSide(color: KairoColors.darkBorder)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: KairoColors.darkTextSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.readOnlyHint ?? 'Solo los administradores pueden enviar mensajes.',
                style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showEmoji) _EmojiPanel(stickers: _stickers, onPick: _sendSticker),
        Container(
          padding: EdgeInsets.fromLTRB(8, 10, 10, bottomPad + 10),
          decoration: const BoxDecoration(
            color: KairoColors.darkBg,
            border: Border(top: BorderSide(color: KairoColors.darkBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _sending ? null : () => setState(() => _showEmoji = !_showEmoji),
                icon: Icon(
                  _showEmoji ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
                  color: KairoColors.primary400,
                ),
              ),
              IconButton(
                onPressed: _sending ? null : _pickImage,
                icon: const Icon(Icons.image_outlined, color: KairoColors.primary400),
              ),
              IconButton(
                onPressed: _sending ? null : _pickAudio,
                icon: const Icon(Icons.mic_none_rounded, color: KairoColors.primary400),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: KairoColors.darkText, fontSize: 15),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Mensaje, emoji o adjunto...',
                    hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
                    filled: true,
                    fillColor: KairoColors.darkCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendText(),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _sending ? null : _sendText,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: KairoColors.buttonGradient,
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.stickers, required this.onPick});

  final List<String> stickers;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: KairoColors.darkCard,
        border: Border(top: BorderSide(color: KairoColors.darkBorder)),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: stickers.length,
        itemBuilder: (_, i) {
          final emoji = stickers[i];
          return InkWell(
            onTap: () => onPick(emoji),
            borderRadius: BorderRadius.circular(8),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
          );
        },
      ),
    );
  }
}
