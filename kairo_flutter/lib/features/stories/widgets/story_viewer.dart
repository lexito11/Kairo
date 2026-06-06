import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/models/story.dart';
import '../../../core/widgets/inline_video_player.dart';

class StoryViewer extends StatefulWidget {
  const StoryViewer({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.initialStoryIndex = 0,
  });

  final List<StoryGroup> groups;
  final int initialGroupIndex;
  final int initialStoryIndex;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late int _groupIndex;
  late int _storyIndex;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroupIndex;
    _storyIndex = widget.initialStoryIndex;
  }

  Story get _story => widget.groups[_groupIndex].stories[_storyIndex];

  void _next() {
    final group = widget.groups[_groupIndex];
    if (_storyIndex < group.stories.length - 1) {
      setState(() => _storyIndex++);
    } else if (_groupIndex < widget.groups.length - 1) {
      setState(() { _groupIndex++; _storyIndex = 0; });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          if (d.localPosition.dx > MediaQuery.of(context).size.width / 2) {
            _next();
          } else if (_storyIndex > 0) {
            setState(() => _storyIndex--);
          } else {
            Navigator.pop(context);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_story.isVideo)
              InlineVideoPlayer(url: _story.mediaUrl, height: MediaQuery.of(context).size.height, autoPlay: true)
            else
              CachedNetworkImage(imageUrl: _story.mediaUrl, fit: BoxFit.contain),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.groups[_groupIndex].author.displayName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
