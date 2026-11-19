import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavBar({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildNavItem(
                  context,
                  0,
                  Icons.explore_outlined,
                  Icons.explore,
                  'Discover',
                ),
                _buildNavItem(
                  context,
                  1,
                  Icons.book_outlined,
                  Icons.book,
                  'Journal',
                ),
                _buildNavItem(
                  context,
                  2,
                  Icons.list_alt_outlined,
                  Icons.list_alt,
                  'Lists',
                ),
                _buildNavItem(
                  context,
                  3,
                  Icons.forum_outlined,
                  Icons.forum,
                  'Forum',
                ),
                _buildNavItem(
                  context,
                  4,
                  Icons.person_outline,
                  Icons.person,
                  'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData iconOutlined,
    IconData iconFilled,
    String label,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = navigationShell.currentIndex == index;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.72)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? iconFilled : iconOutlined,
                      color: isSelected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      size: 21,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: isSelected
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
