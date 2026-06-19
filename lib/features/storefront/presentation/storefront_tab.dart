import 'package:flutter/material.dart';

import '../domain/storefront_type.dart';

class StorefrontTab extends StatelessWidget {
  const StorefrontTab({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final StorefrontType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  type.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? colors.onPrimary : colors.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
