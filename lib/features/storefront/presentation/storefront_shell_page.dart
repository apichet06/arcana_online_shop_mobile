import 'package:flutter/material.dart';

import '../domain/storefront_type.dart';
import 'storefront_tab.dart';

class StorefrontShellPage extends StatefulWidget {
  const StorefrontShellPage({super.key});

  @override
  State<StorefrontShellPage> createState() => _StorefrontShellPageState();
}

class _StorefrontShellPageState extends State<StorefrontShellPage> {
  StorefrontType _selectedType = StorefrontType.arcana;

  @override
  Widget build(BuildContext context) {
    final isArcana = _selectedType == StorefrontType.arcana;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arcana Shop'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: 'Cart',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _StorefrontSwitcher(
              selectedType: _selectedType,
              onChanged: (type) => setState(() => _selectedType = type),
            ),
            const SizedBox(height: 18),
            _HeroSection(type: _selectedType),
            const SizedBox(height: 18),
            _QuickActions(type: _selectedType),
            const SizedBox(height: 22),
            Text(
              isArcana ? 'Curated for you' : 'Fresh stock drops',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _ProductPreviewGrid(type: _selectedType),
          ],
        ),
      ),
    );
  }
}

class _StorefrontSwitcher extends StatelessWidget {
  const _StorefrontSwitcher({
    required this.selectedType,
    required this.onChanged,
  });

  final StorefrontType selectedType;
  final ValueChanged<StorefrontType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E0D6)),
      ),
      child: Row(
        children: [
          StorefrontTab(
            type: StorefrontType.arcana,
            selected: selectedType == StorefrontType.arcana,
            onTap: () => onChanged(StorefrontType.arcana),
          ),
          StorefrontTab(
            type: StorefrontType.deadstock,
            selected: selectedType == StorefrontType.deadstock,
            onTap: () => onChanged(StorefrontType.deadstock),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.type});

  final StorefrontType type;

  @override
  Widget build(BuildContext context) {
    final isArcana = type == StorefrontType.arcana;
    final background = isArcana
        ? const Color(0xFF0F4C81)
        : const Color(0xFF332F2A);
    final accent = isArcana ? const Color(0xFF9ED8FF) : const Color(0xFFFFB457);

    return Container(
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isArcana ? 'PREMIUM SELECTION' : 'LIMITED STOCK',
              style: const TextStyle(
                color: Color(0xFF161B18),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isArcana ? 'Arcana Premium' : 'Deadstock Deals',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isArcana
                ? 'สินค้าคัดพิเศษสำหรับสุขภาพ ไลฟ์สไตล์ และของใช้คุณภาพสูง'
                : 'สินค้า stock พิเศษ ราคาดี จำนวนจำกัด พร้อมให้เลือกก่อนหมด',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xD1FFFFFF),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.arrow_forward),
            label: Text(isArcana ? 'Shop Premium' : 'Browse Deals'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: background,
              minimumSize: const Size(150, 44),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.type});

  final StorefrontType type;

  @override
  Widget build(BuildContext context) {
    final isArcana = type == StorefrontType.arcana;
    final items = isArcana
        ? const [
            _QuickActionData(Icons.spa_outlined, 'Wellness'),
            _QuickActionData(Icons.diamond_outlined, 'Premium'),
            _QuickActionData(Icons.local_shipping_outlined, 'Fast ship'),
          ]
        : const [
            _QuickActionData(Icons.inventory_2_outlined, 'In stock'),
            _QuickActionData(Icons.sell_outlined, 'Best price'),
            _QuickActionData(Icons.flash_on_outlined, 'New drops'),
          ];

    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _QuickActionCard(item: item),
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.item});

  final _QuickActionData item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: [
            Icon(item.icon),
            const SizedBox(height: 8),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPreviewGrid extends StatelessWidget {
  const _ProductPreviewGrid({required this.type});

  final StorefrontType type;

  @override
  Widget build(BuildContext context) {
    final isArcana = type == StorefrontType.arcana;
    final products = isArcana
        ? const [
            _ProductPreview('Organic daily care', '฿1,290', Color(0xFFD8E9F8)),
            _ProductPreview('Premium supplement', '฿890', Color(0xFFE6EEF8)),
          ]
        : const [
            _ProductPreview('Factory overstock set', '฿490', Color(0xFFE4D2BD)),
            _ProductPreview('Clearance tool kit', '฿690', Color(0xFFD4D9E3)),
          ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => _ProductPreviewCard(
        product: products[index],
      ),
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  const _ProductPreviewCard({required this.product});

  final _ProductPreview product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: product.color,
              child: const Icon(Icons.shopping_bag_outlined, size: 42),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.price,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _ProductPreview {
  const _ProductPreview(this.name, this.price, this.color);

  final String name;
  final String price;
  final Color color;
}
