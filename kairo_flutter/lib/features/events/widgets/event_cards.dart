import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/kairo_colors.dart';
import '../constants/events_constants.dart';
import '../models/event_data.dart';

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, size: compact ? 10 : 12, color: Colors.white),
          if (!compact) const SizedBox(width: 4),
          Text(
            compact ? 'EN CURSO' : 'EN CURSO',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class EventTodayCard extends StatelessWidget {
  const EventTodayCard({
    super.key,
    required this.event,
    required this.onTap,
    this.compact = false,
  });

  final EventData event;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 208.0 : 320.0;
    final imageHeight = compact ? 128.0 : 192.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: KairoColors.darkCard,
          borderRadius: BorderRadius.circular(compact ? 8 : 16),
          border: Border.all(color: KairoColors.darkBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: event.image,
                  height: imageHeight,
                  width: width,
                  fit: BoxFit.cover,
                ),
                if (event.isLive)
                  Positioned(
                    top: compact ? 6 : 12,
                    left: compact ? 6 : 12,
                    child: LiveBadge(compact: compact),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 10 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: KairoColors.primary500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.denomination,
                          style: TextStyle(
                            color: KairoColors.primary400,
                            fontSize: compact ? 9 : 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '• ${event.category}',
                          style: TextStyle(
                            color: KairoColors.darkTextSecondary,
                            fontSize: compact ? 9 : 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 8),
                  Text(
                    event.title,
                    style: TextStyle(
                      color: KairoColors.darkText,
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 12 : 18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: compact ? 4 : 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: compact ? 12 : 16, color: KairoColors.darkTextSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: compact ? 10 : 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KairoColors.primary500,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(compact ? 6 : 8)),
                        elevation: 0,
                      ),
                      child: Text('Ver detalles', style: TextStyle(fontSize: compact ? 10 : 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventUpcomingCard extends StatelessWidget {
  const EventUpcomingCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onAttending,
    required this.onNotAttending,
    required this.attendance,
    this.compact = false,
    this.showAttendance = true,
  });

  final EventData event;
  final VoidCallback onTap;
  final VoidCallback onAttending;
  final VoidCallback onNotAttending;
  final AttendanceInfo attendance;
  final bool compact;
  final bool showAttendance;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 208.0 : 320.0;
    final month = monthAbbreviations[event.date.month - 1];
    final day = '${event.date.day}';

    if (compact) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: KairoColors.darkCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: KairoColors.darkBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  CachedNetworkImage(imageUrl: event.image, height: 128, width: width, fit: BoxFit.cover),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Text(month, style: const TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold, height: 1)),
                          Text(day, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 10, fontWeight: FontWeight.bold, height: 1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: KairoColors.primary500.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(event.denomination, style: const TextStyle(color: KairoColors.primary400, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text('• ${event.category}', style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 9), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(event.title, style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: KairoColors.darkTextSecondary),
                        const SizedBox(width: 2),
                        Expanded(child: Text(event.location, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KairoColors.primary500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: const Text('Ver detalles', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KairoColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KairoColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(imageUrl: event.image, height: 128, width: width, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(month, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(day, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.bold, height: 1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: categoryBgColor(event.category), borderRadius: BorderRadius.circular(4)),
                  child: Text(event.category, style: TextStyle(color: categoryColor(event.category), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Icon(Icons.bookmark_border, color: KairoColors.darkTextSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.title, style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('${event.church} • ${event.time}', style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: KairoColors.darkTextSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(event.location, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13))),
              ],
            ),
            if (showAttendance) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _AttendanceButton(
                    label: 'Asistiré',
                    count: attendance.attending,
                    selected: attendance.userStatus == AttendanceStatus.attending,
                    selectedColor: KairoColors.primary400,
                    onTap: onAttending,
                  ),
                  const SizedBox(width: 8),
                  _AttendanceButton(
                    label: 'No asistiré',
                    count: attendance.notAttending,
                    selected: attendance.userStatus == AttendanceStatus.notAttending,
                    selectedColor: KairoColors.errorText,
                    onTap: onNotAttending,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KairoColors.primary500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Ver detalles', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EventFilteredCard extends StatelessWidget {
  const EventFilteredCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onAttending,
    required this.onNotAttending,
    required this.attendance,
  });

  final EventData event;
  final VoidCallback onTap;
  final VoidCallback onAttending;
  final VoidCallback onNotAttending;
  final AttendanceInfo attendance;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KairoColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(imageUrl: event.image, fit: BoxFit.cover),
                    if (event.isLive)
                      const Positioned(top: 12, left: 12, child: LiveBadge()),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: KairoColors.primary500.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(event.denomination, style: const TextStyle(color: KairoColors.primary400, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          Expanded(child: Text('• ${event.category}', style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(event.title, style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: KairoColors.darkTextSecondary),
                          const SizedBox(width: 4),
                          Expanded(child: Text('${event.church} • ${event.time}', style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: KairoColors.darkTextSecondary),
                          const SizedBox(width: 4),
                          Expanded(child: Text(event.location, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _AttendanceButton(
                            label: 'Asistiré',
                            count: attendance.attending,
                            selected: attendance.userStatus == AttendanceStatus.attending,
                            selectedColor: KairoColors.primary400,
                            onTap: onAttending,
                          ),
                          const SizedBox(width: 8),
                          _AttendanceButton(
                            label: 'No asistiré',
                            count: attendance.notAttending,
                            selected: attendance.userStatus == AttendanceStatus.notAttending,
                            selectedColor: KairoColors.errorText,
                            onTap: onNotAttending,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KairoColors.primary500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Text('Ver detalles'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  const _AttendanceButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: selectedColor, fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Text('$count', style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
