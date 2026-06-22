import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/features/product_shop/data/product_shop_repository.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product_detail.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product_review.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/presentation/widgets/product_card.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/presentation/widgets/lexical_description_view.dart';
import 'package:arcana_online_shop_mobile/features/storefront/application/storefront_search_coordinator.dart';
import 'package:arcana_online_shop_mobile/features/storefront/domain/storefront_language.dart';
import 'package:arcana_online_shop_mobile/features/storefront/domain/storefront_type.dart';
import 'package:arcana_online_shop_mobile/l10n/app_localizations.dart';

class ProductVariantPage extends StatefulWidget {
  const ProductVariantPage({
    super.key,
    required this.product,
    required this.language,
    required this.initialImageUrl,
  });

  final Product product;
  final StorefrontLanguage language;
  final String initialImageUrl;

  @override
  State<ProductVariantPage> createState() => _ProductVariantPageState();
}

class _ProductVariantPageState extends State<ProductVariantPage> {
  final ProductShopRepository _repository = ProductShopRepository();
  late final PageController _imagePageController;

  ProductDetailData? _data;
  ProductReviewsData? _reviewsData;
  List<Product> _relatedProducts = const [];
  ProductVariant? _selectedVariant;
  String _selectedImageUrl = '';
  List<String> _imageUrls = const [];
  int _selectedImageIndex = 0;
  int _imageLoopBasePage = 0;
  bool _loading = true;
  Object? _error;
  bool _reviewsLoading = false;
  bool _reviewsLoadingMore = false;
  bool _reviewsHasMore = false;
  int _reviewsPage = 1;
  bool _relatedLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedImageUrl = widget.initialImageUrl;
    _imagePageController = PageController();
    _loadProduct();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  void _openStorefrontSearch() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    StorefrontSearchCoordinator.instance.requestSearch();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _repository.getProductById(
        productId: widget.product.id,
        languageCode: widget.language.code,
      );
      if (!mounted) return;

      final defaultVariant = _pickDefaultVariant(data.variants);
      final imageUrls = _buildImageUrls(data);
      final primaryImage = _pickPrimaryImage(data, defaultVariant, imageUrls);
      final primaryIndex = _indexOfImage(imageUrls, primaryImage);
      final loopBasePage = imageUrls.length > 1 ? imageUrls.length * 500 : 0;

      setState(() {
        _data = data;
        _selectedVariant = defaultVariant;
        _imageUrls = imageUrls;
        _selectedImageUrl = primaryImage;
        _selectedImageIndex = primaryIndex;
        _imageLoopBasePage = loopBasePage;
        _loading = false;
      });

      _loadReviews(defaultVariant?.id);
      _loadRelatedProducts(data);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_imagePageController.hasClients) return;
        _imagePageController.jumpToPage(loopBasePage + primaryIndex);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  ProductVariant? _pickDefaultVariant(List<ProductVariant> variants) {
    if (variants.isEmpty) return null;
    return variants.firstWhere(
      (variant) => variant.isDefault && !variant.isOutOfStock,
      orElse: () => variants.firstWhere(
        (variant) => !variant.isOutOfStock,
        orElse: () => variants.firstWhere(
          (variant) => variant.isDefault,
          orElse: () => variants.first,
        ),
      ),
    );
  }

  Future<void> _loadReviews(int? variantId) async {
    if (variantId == null || variantId <= 0) {
      setState(() {
        _reviewsData = null;
        _reviewsPage = 1;
        _reviewsHasMore = false;
      });
      return;
    }

    setState(() {
      _reviewsLoading = true;
      _reviewsData = null;
      _reviewsPage = 1;
      _reviewsHasMore = false;
    });

    try {
      final data = await _repository.getReviews(
        variantId: variantId,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _reviewsData = data;
        _reviewsHasMore = data.reviews.length < data.total;
        _reviewsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _loadMoreReviews() async {
    final variantId = _selectedVariant?.id;
    if (variantId == null || _reviewsLoadingMore || !_reviewsHasMore) return;

    final nextPage = _reviewsPage + 1;
    setState(() => _reviewsLoadingMore = true);

    try {
      final nextData = await _repository.getReviews(
        variantId: variantId,
        page: nextPage,
      );
      if (!mounted) return;

      final current = _reviewsData;
      final mergedReviews = [
        ...?current?.reviews,
        ...nextData.reviews,
      ];

      setState(() {
        _reviewsData = ProductReviewsData(
          reviews: mergedReviews,
          summary: nextData.summary,
          total: nextData.total,
        );
        _reviewsPage = nextPage;
        _reviewsHasMore = mergedReviews.length < nextData.total;
        _reviewsLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reviewsLoadingMore = false);
    }
  }

  Future<void> _loadRelatedProducts(ProductDetailData data) async {
    final categoryId = data.product.categoryId;
    if (categoryId <= 0) return;

    setState(() => _relatedLoading = true);

    try {
      final products = await _repository.getRelatedProducts(
        type: _typeFromCatalogId(data.product.catalogId),
        languageCode: widget.language.code,
        categoryId: categoryId,
        excludeProductId: data.product.id,
      );
      if (!mounted) return;
      setState(() {
        _relatedProducts = products;
        _relatedLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _relatedLoading = false);
    }
  }

  StorefrontType _typeFromCatalogId(int catalogId) {
    for (final type in StorefrontType.values) {
      if (type.catalogId == catalogId) return type;
    }

    return StorefrontType.arcana;
  }

  List<String> _buildImageUrls(ProductDetailData data) {
    final urls = <String>[];

    void addUrl(String? value) {
      final url = _repository.resolveAssetUrl(value);
      if (url.isEmpty || urls.contains(url)) return;
      urls.add(url);
    }

    for (final image in data.images.where((image) => image.isPrimary)) {
      addUrl(image.url);
    }
    for (final image in data.images.where((image) => !image.isPrimary)) {
      addUrl(image.url);
    }
    for (final variant in data.variants) {
      addUrl(variant.imageUrl);
    }
    addUrl(data.product.thumbnail);
    addUrl(widget.initialImageUrl);

    return urls;
  }

  String _pickPrimaryImage(
    ProductDetailData data,
    ProductVariant? variant,
    List<String> imageUrls,
  ) {
    final variantImage = _repository.resolveAssetUrl(variant?.imageUrl);
    if (variantImage.isNotEmpty) return variantImage;

    for (final image in data.images) {
      if (!image.isPrimary || image.url.isEmpty) continue;
      final url = _repository.resolveAssetUrl(image.url);
      if (url.isNotEmpty) return url;
    }

    for (final image in data.images) {
      final url = _repository.resolveAssetUrl(image.url);
      if (url.isNotEmpty) return url;
    }

    final thumbnail = _repository.resolveAssetUrl(data.product.thumbnail);
    if (thumbnail.isNotEmpty) return thumbnail;

    return widget.initialImageUrl;
  }

  int _indexOfImage(List<String> imageUrls, String imageUrl) {
    final index = imageUrls.indexOf(imageUrl);
    if (index >= 0) return index;
    return 0;
  }

  int _carouselPageForIndex(int imageIndex) {
    if (_imageUrls.length <= 1) return imageIndex;
    return _imageLoopBasePage + imageIndex;
  }

  void _selectVariant(ProductVariant variant) {
    final imageUrl = _repository.resolveAssetUrl(variant.imageUrl);
    final imageIndex = _indexOfImage(_imageUrls, imageUrl);

    setState(() {
      _selectedVariant = variant;
      if (imageUrl.isNotEmpty) {
        _selectedImageUrl = imageUrl;
        _selectedImageIndex = imageIndex;
      }
    });

    if (imageUrl.isNotEmpty && _imagePageController.hasClients) {
      _imagePageController.animateToPage(
        _carouselPageForIndex(imageIndex),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }

    _loadReviews(variant.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _ProductHeaderLogo(title: l10n.appTitle),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                widget.language.label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 13),
              ),
            ),
          ),
          IconButton(
            onPressed: _openStorefrontSearch,
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ProductError(onRetry: _loadProduct)
            : _buildContent(context),
      ),
      bottomNavigationBar: _ProductActionFooter(
        isLoading: _loading,
        variant: _selectedVariant,
        onChat: _handleChat,
        onAddToCart: _handleAddToCart,
        onBuyNow: _handleBuyNow,
      ),
    );
  }

  void _handleChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เปิดแชทร้านค้า')),
    );
  }

  void _handleAddToCart() {
    final variant = _selectedVariant;
    if (variant == null || variant.isOutOfStock) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เพิ่ม ${variant.labelOrSku} ลงตะกร้าแล้ว')),
    );
  }

  void _handleBuyNow() {
    final variant = _selectedVariant;
    if (variant == null || variant.isOutOfStock) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ไปหน้าชำระเงิน: ${variant.labelOrSku}')),
    );
  }

  Widget _buildContent(BuildContext context) {
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    final product = data.product;
    final selectedVariant = _selectedVariant;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 120;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
      children: [
        _ProductImageCarousel(
          imageUrls: _imageUrls.isNotEmpty ? _imageUrls : [_selectedImageUrl],
          controller: _imagePageController,
          selectedIndex: _selectedImageIndex,
          onPageChanged: (index) {
            final imageUrls = _imageUrls;
            setState(() {
              _selectedImageIndex = index;
              if (index >= 0 && index < imageUrls.length) {
                _selectedImageUrl = imageUrls[index];
              }
            });
          },
        ),
        const SizedBox(height: 18),
        if (product.brandName.isNotEmpty)
          Text(
            product.brandName,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 6),
        Text(
          product.displayName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (product.storeName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(product.storeName, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 14),
        _VariantPrice(variant: selectedVariant, product: product),
        const SizedBox(height: 20),
        if (data.variants.isNotEmpty) ...[
          Text(
            'ตัวเลือกสินค้า',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final variant in data.variants)
                ChoiceChip(
                  selected: selectedVariant?.id == variant.id,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    variant.label.isNotEmpty ? variant.label : variant.sku,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onSelected: (_) => _selectVariant(variant),
                ),
            ],
          ),
        ],
        if (selectedVariant != null) ...[
          const SizedBox(height: 18),
          _VariantInfo(variant: selectedVariant),
        ],
        if (product.description.isNotEmpty) ...[
          const SizedBox(height: 22),
          _ProductDescriptionSection(
            description: product.description,
            resolveImageUrl: _repository.resolveAssetUrl,
          ),
        ],
        if (selectedVariant != null) ...[
          const SizedBox(height: 24),
          _ProductReviewsSection(
            loading: _reviewsLoading,
            loadingMore: _reviewsLoadingMore,
            hasMore: _reviewsHasMore,
            data: _reviewsData,
            resolveImageUrl: _repository.resolveAssetUrl,
            onLoadMore: _loadMoreReviews,
          ),
        ],
        if (_relatedLoading || _relatedProducts.isNotEmpty) ...[
          const SizedBox(height: 26),
          _RelatedProductsSection(
            loading: _relatedLoading,
            products: _relatedProducts,
            language: widget.language,
            resolveImageUrl: _repository.resolveAssetUrl,
          ),
        ],
      ],
    );
  }
}

extension _ProductVariantLabel on ProductVariant {
  String get labelOrSku => label.isNotEmpty ? label : sku;
}

class _ProductDescriptionSection extends StatelessWidget {
  const _ProductDescriptionSection({
    required this.description,
    required this.resolveImageUrl,
  });

  final String description;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รายละเอียด',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          LexicalDescriptionView(
            value: description,
            resolveImageUrl: resolveImageUrl,
          ),
        ],
      ),
    );
  }
}

class _ProductHeaderLogo extends StatelessWidget {
  const _ProductHeaderLogo({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/image/app_icon.jpg',
            width: 34,
            height: 34,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _ProductActionFooter extends StatelessWidget {
  const _ProductActionFooter({
    required this.isLoading,
    required this.variant,
    required this.onChat,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  final bool isLoading;
  final ProductVariant? variant;
  final VoidCallback onChat;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = isLoading || variant == null || variant!.isOutOfStock;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              _FooterActionItem(
                icon: Icons.chat_bubble_outline,
                label: 'แชท',
                onTap: isLoading ? null : onChat,
              ),
              _FooterActionDivider(color: theme.dividerColor),
              _FooterActionItem(
                icon: Icons.add_shopping_cart_outlined,
                label: 'เพิ่มลงตะกร้า',
                onTap: disabled ? null : onAddToCart,
              ),
              _FooterActionDivider(color: theme.dividerColor),
              _FooterActionItem(
                icon: Icons.flash_on_outlined,
                label: 'ซื้อเลย',
                highlight: true,
                onTap: disabled ? null : onBuyNow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterActionItem extends StatelessWidget {
  const _FooterActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final color = enabled
        ? highlight
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface
        : theme.disabledColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterActionDivider extends StatelessWidget {
  const _FooterActionDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: color.withValues(alpha: 0.32),
      ),
    );
  }
}

class _ProductImageCarousel extends StatelessWidget {
  const _ProductImageCarousel({
    required this.imageUrls,
    required this.controller,
    required this.selectedIndex,
    required this.onPageChanged,
  });

  final List<String> imageUrls;
  final PageController controller;
  final int selectedIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final urls = imageUrls.where((url) => url.isNotEmpty).toList();
    if (urls.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          child: ColoredBox(
            color: Color(0xFFF0EEE8),
            child: _ImageFallback(),
          ),
        ),
      );
    }

    final loop = urls.length > 1;
    final itemCount = loop ? urls.length * 1000 : urls.length;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: const Color(0xFFF0EEE8),
              child: PageView.builder(
                controller: controller,
                itemCount: itemCount,
                onPageChanged: (page) => onPageChanged(page % urls.length),
                itemBuilder: (context, page) {
                  final index = page % urls.length;
                  final imageUrl = urls[index];

                  return Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ImageFallback(),
                  );
                },
              ),
            ),
          ),
          if (urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < urls.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selectedIndex == i ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: selectedIndex == i
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (urls.length > 1)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${selectedIndex + 1}/${urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductReviewsSection extends StatelessWidget {
  const _ProductReviewsSection({
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.data,
    required this.resolveImageUrl,
    required this.onLoadMore,
  });

  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final ProductReviewsData? data;
  final String Function(String? value) resolveImageUrl;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final reviews = data?.reviews ?? const <ProductReview>[];
    final summary = data?.summary;

    return _SectionCard(
      title: 'รีวิวสินค้า',
      subtitle: 'Reviews',
      child: loading && data == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary != null && (data?.total ?? 0) > 0)
                  _ReviewSummary(summary: summary, total: data?.total ?? 0)
                else
                  const _EmptyReviews(),
                if (reviews.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  for (final review in reviews)
                    _ReviewCard(
                      review: review,
                      resolveImageUrl: resolveImageUrl,
                    ),
                  if (hasMore)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: loadingMore ? null : onLoadMore,
                        child: loadingMore
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('โหลดรีวิวเพิ่มเติม'),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.summary,
    required this.total,
  });

  final ProductReviewSummary summary;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScoreBox(
            value: summary.avgProductScore.toStringAsFixed(1),
            label: 'คะแนนสินค้า',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScoreBox(
            value: summary.avgDeliveryScore.toStringAsFixed(1),
            label: 'คะแนนจัดส่ง',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScoreBox(
            value: total.toString(),
            label: 'รีวิวทั้งหมด',
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.resolveImageUrl,
  });

  final ProductReview review;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final images = review.images.map(resolveImageUrl).where((url) => url.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFFE0F2FE),
                child: Text(
                  review.username.isNotEmpty ? review.username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.username.isNotEmpty ? review.username : 'ผู้ใช้',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatReviewDate(review.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('สินค้า ', style: TextStyle(fontSize: 12)),
              _StarRow(value: review.productScore),
              const SizedBox(width: 14),
              const Text('จัดส่ง ', style: TextStyle(fontSize: 12)),
              _StarRow(value: review.deliveryScore),
            ],
          ),
          if (review.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < images.length; i++)
                  _ReviewImageThumb(
                    imageUrl: images[i],
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => _ReviewImageDialog(
                          images: images,
                          initialIndex: i,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewImageThumb extends StatelessWidget {
  const _ReviewImageThumb({
    required this.imageUrl,
    required this.onTap,
  });

  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ReviewImageDialog extends StatefulWidget {
  const _ReviewImageDialog({
    required this.images,
    required this.initialIndex,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<_ReviewImageDialog> createState() => _ReviewImageDialogState();
}

class _ReviewImageDialogState extends State<_ReviewImageDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int nextIndex) {
    if (widget.images.isEmpty) return;
    final normalized = (nextIndex + widget.images.length) % widget.images.length;
    _controller.animateToPage(
      normalized,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.black,
      child: AspectRatio(
        aspectRatio: 0.75,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 3.5,
                  child: Center(
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            if (widget.images.length > 1) ...[
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton.filledTonal(
                    onPressed: () => _goTo(_index - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton.filledTonal(
                    onPressed: () => _goTo(_index + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.mode_comment_outlined,
            size: 28,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'ยังไม่มีรีวิว',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedProductsSection extends StatelessWidget {
  const _RelatedProductsSection({
    required this.loading,
    required this.products,
    required this.language,
    required this.resolveImageUrl,
  });

  final bool loading;
  final List<Product> products;
  final StorefrontLanguage language;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'คุณอาจชอบสิ่งนี้',
      subtitle: 'Related Products',
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              height: 300,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return SizedBox(
                    width: 170,
                    child: ProductCard(
                      product: product,
                      imageUrl: resolveImageUrl(product.imageUrl),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductVariantPage(
                              product: product,
                              language: language,
                              initialImageUrl: resolveImageUrl(
                                product.imageUrl,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            Icons.star,
            size: 14,
            color: i <= value ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          ),
      ],
    );
  }
}

String _formatReviewDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return '';

  return '${date.day}/${date.month}/${date.year + 543}';
}

class _VariantPrice extends StatelessWidget {
  const _VariantPrice({required this.variant, required this.product});

  final ProductVariant? variant;
  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final selectedVariant = variant;
    final color = Theme.of(context).colorScheme.primary;
    final price = selectedVariant?.finalPrice ?? product.minPrice;

    return Row(
      children: [
        Text(
          _formatPrice(price),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (selectedVariant != null && selectedVariant.discount > 0) ...[
          const SizedBox(width: 10),
          Text(
            _formatPrice(selectedVariant.price),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}

class _VariantInfo extends StatelessWidget {
  const _VariantInfo({required this.variant});

  final ProductVariant variant;

  @override
  Widget build(BuildContext context) {
    final statusColor = variant.isOutOfStock
        ? Theme.of(context).colorScheme.error
        : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E0D6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (variant.label.isNotEmpty)
            Text(variant.label, style: Theme.of(context).textTheme.titleSmall),
          if (variant.sku.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('SKU: ${variant.sku}'),
          ],
          const SizedBox(height: 6),
          Text(
            variant.isOutOfStock
                ? 'สินค้าหมด'
                : 'พร้อมขาย ${variant.availableQty} ${variant.unitName ?? ''}',
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProductError extends StatelessWidget {
  const _ProductError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              'โหลดข้อมูลสินค้าไม่สำเร็จ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Icon(Icons.shopping_bag_outlined, size: 56));
  }
}

String _formatPrice(double value) {
  final rounded = value.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return '฿$buffer';
}
