import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/kairo_colors.dart';

class KairoBottomNavigation extends StatelessWidget {
  const KairoBottomNavigation({super.key, required this.currentPath});

  final String currentPath;

  bool _isActive(String path) {
    if (path == '/feed') return currentPath == '/feed' || currentPath == '/';
    return currentPath.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KairoColors.darkBg.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: KairoColors.darkBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                label: 'Feed',
                active: _isActive('/feed'),
                icon: Icons.home_rounded,
                onTap: () => context.go('/feed'),
              ),
              _NavItem(
                label: 'Videos',
                active: _isActive('/videos'),
                icon: Icons.play_circle_filled_rounded,
                onTap: () => context.go('/videos'),
              ),
              _PublishButton(
                active: _isActive('/feed/create'),
                onTap: () => context.go('/feed/create'),
              ),
              _NavItem(
                label: 'Chat',
                active: _isActive('/chat'),
                icon: Icons.chat_bubble_rounded,
                onTap: () => context.go('/chat'),
                badge: 3,
              ),
              _NavItem(
                label: 'Perfil',
                active: _isActive('/profile'),
                icon: Icons.person_outline_rounded,
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final color = active ? KairoColors.primary500 : KairoColors.darkTextSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 28, color: color),
                if (badge != null)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$badge',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: KairoColors.buttonGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: KairoColors.primary500.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'Publicar',
            style: TextStyle(
              fontSize: 10,
              color: active ? KairoColors.primary500 : KairoColors.darkTextSecondary,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
