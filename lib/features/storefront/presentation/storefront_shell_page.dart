import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/cart/application/cart_controller.dart';
import 'package:arcana_online_shop_mobile/features/cart/presentation/cart_page.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/data/product_shop_repository.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/presentation/product_variant_page.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/presentation/widgets/product_card.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';
import 'package:arcana_online_shop_mobile/features/auth/presentation/login_page.dart';
import 'package:arcana_online_shop_mobile/features/chat/application/chat_controller.dart';
import 'package:arcana_online_shop_mobile/features/chat/presentation/chat_tab.dart';
import 'package:arcana_online_shop_mobile/features/coupons/data/coupons_api.dart';
import 'package:arcana_online_shop_mobile/features/coupons/domain/coupon.dart';
import 'package:arcana_online_shop_mobile/features/coupons/presentation/coupons_page.dart';
import 'package:arcana_online_shop_mobile/features/notifications/application/buyer_notification_controller.dart';
import 'package:arcana_online_shop_mobile/features/notifications/presentation/notifications_page.dart';
import 'package:arcana_online_shop_mobile/features/address/presentation/address_page.dart';
import 'package:arcana_online_shop_mobile/features/orders/presentation/order_list_page.dart';
import 'package:arcana_online_shop_mobile/features/payment_methods/presentation/payment_methods_page.dart';
import 'package:arcana_online_shop_mobile/features/profile/presentation/change_password_page.dart';
import 'package:arcana_online_shop_mobile/features/profile/presentation/profile_page.dart';
import 'package:arcana_online_shop_mobile/features/storefront/application/storefront_search_coordinator.dart';
import 'package:arcana_online_shop_mobile/l10n/app_localizations.dart';

import '../domain/storefront_category.dart';
import '../domain/storefront_language.dart';
import '../domain/storefront_type.dart';

class StorefrontShellPage extends StatefulWidget {
  const StorefrontShellPage({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  final StorefrontLanguage selectedLanguage;
  final ValueChanged<StorefrontLanguage> onLanguageChanged;

  @override
  State<StorefrontShellPage> createState() => _StorefrontShellPageState();
}

class _StorefrontShellPageState extends State<StorefrontShellPage> {
  // จำนวนสินค้าที่โหลดต่อ 1 หน้า ใช้กับ pagination/infinite scroll
  static const int _pageSize = 10;
  static const MethodChannel _badgeChannel = MethodChannel('arcana/app_badge');

  // Repository ใช้เรียก API ของ storefront และสินค้า
  final ProductShopRepository _repository = ProductShopRepository();
  final CouponsApi _couponsApi = CouponsApi();
  final BuyerNotificationController _notificationController =
      BuyerNotificationController();
  final ChatController _chatController = ChatController();
  final StorefrontSearchCoordinator _searchCoordinator =
      StorefrontSearchCoordinator.instance;
  // Controller สำหรับฟังตำแหน่ง scroll เพื่อโหลดสินค้าเพิ่มเมื่อใกล้ท้ายหน้า
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  // State หลักของหน้า storefront
  StorefrontType _selectedType = StorefrontType.arcana;
  late StorefrontLanguage _selectedLanguage;
  int _selectedFooterIndex = 0;
  int? _selectedCategoryId;
  String _searchKeyword = '';
  List<StorefrontCategory> _categories = const [];
  List<Product> _products = const [];
  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  Object? _loadError;
  int _loadRequestId = 0;
  int? _lastSyncedAppBadgeCount;
  List<Coupon> _availableCoupons = const [];
  bool _couponsLoading = false;
  int? _claimingCouponId;

  @override
  void initState() {
    super.initState();
    // รับค่าภาษาตั้งต้นจาก widget แม่ แล้วเริ่มโหลดข้อมูลหน้าแรก
    _selectedLanguage = widget.selectedLanguage;
    _scrollController.addListener(_handleScroll);
    _searchCoordinator.addListener(_focusSearch);
    AuthSession.instance.addListener(_handleAuthChanged);
    _notificationController.addListener(_refreshFooterBadges);
    _chatController.addListener(_refreshFooterBadges);
    _loadInitialStorefront();
    unawaited(_loadCoupons());
    _notificationController.syncWithSession();
    _chatController.syncWithSession();
  }

  @override
  void didUpdateWidget(covariant StorefrontShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ถ้า widget แม่เปลี่ยนภาษา ให้ sync state ในหน้านี้และโหลดข้อมูลใหม่
    if (oldWidget.selectedLanguage != widget.selectedLanguage &&
        _selectedLanguage != widget.selectedLanguage) {
      _selectedLanguage = widget.selectedLanguage;
      _selectedCategoryId = null;
      _loadInitialStorefront();
    }
  }

  @override
  void dispose() {
    // ถอด listener และ dispose controller เพื่อกัน memory leak
    _searchCoordinator.removeListener(_focusSearch);
    AuthSession.instance.removeListener(_handleAuthChanged);
    _notificationController.removeListener(_refreshFooterBadges);
    _chatController.removeListener(_refreshFooterBadges);
    _notificationController.dispose();
    _chatController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleAuthChanged() {
    if (AuthSession.instance.isLoggedIn && _selectedFooterIndex != 0) {
      setState(() => _selectedFooterIndex = 0);
    }
    _notificationController.syncWithSession();
    _chatController.syncWithSession();
    unawaited(_loadCoupons());
  }

  void _refreshFooterBadges() {
    if (!mounted) return;
    _syncAppBadge();
    setState(() {});
  }

  void _syncAppBadge() {
    final count =
        _notificationController.unreadCount + _chatController.totalUnreadCount;
    if (_lastSyncedAppBadgeCount == count) return;

    _lastSyncedAppBadgeCount = count;
    unawaited(_setAppBadge(count));
  }

  Future<void> _setAppBadge(int count) async {
    try {
      await _badgeChannel.invokeMethod<void>('setBadge', {'count': count});
    } catch (_) {
      // Android launcher badge support varies by device/launcher.
    }
  }

  Future<void> _loadInitialStorefront() async {
    final requestId = ++_loadRequestId;

    // โหลด storefront ใหม่ตั้งแต่หน้าแรก ใช้ตอนเข้าเพจ เปลี่ยนภาษา เปลี่ยนร้าน หรือเปลี่ยนหมวดหมู่
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _loadError = null;
      _currentPage = 1;
      _hasNextPage = false;
      _products = const [];
    });

    try {
      // getStorefront คืนทั้งหมวดหมู่และสินค้า page แรก
      final data = await _repository.getStorefront(
        type: _selectedType,
        languageCode: _selectedLanguage.code,
        categoryId: _selectedCategoryId,
        keyword: _searchKeyword,
        page: 1,
        limit: _pageSize,
      );

      // ถ้า widget ถูกปิดไปก่อน API ตอบกลับ ไม่ต้อง setState
      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _categories = data.categories;
        _products = data.productPage.items;
        _currentPage = data.productPage.pagination.page;
        _hasNextPage = data.productPage.pagination.hasNextPage;
        _isInitialLoading = false;
      });
    } catch (error) {
      // เก็บ error ไว้ให้ UI แสดงปุ่ม retry
      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _loadError = error;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadCoupons() async {
    if (!mounted) return;
    setState(() => _couponsLoading = true);
    try {
      final coupons = await _couponsApi.fetchAvailableCoupons();
      if (!mounted) return;
      setState(() {
        _availableCoupons = coupons;
        _couponsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _couponsLoading = false);
    }
  }

  Future<void> _claimCoupon(Coupon coupon) async {
    if (!AuthSession.instance.isLoggedIn) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }

    setState(() => _claimingCouponId = coupon.coId);
    try {
      await _couponsApi.claimCoupon(coupon.coId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เก็บคูปองสำเร็จ')));
      await _loadCoupons();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'เก็บคูปองไม่สำเร็จ'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingCouponId = null);
    }
  }

  Future<void> _openCouponsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CouponsPage(api: _couponsApi, language: _selectedLanguage),
      ),
    );
    unawaited(_loadCoupons());
  }

  bool _couponMatchesSelectedType(Coupon coupon) {
    final websiteKey = coupon.websiteKey;
    if (websiteKey == null || websiteKey == 'combined') return true;
    return switch (_selectedType) {
      StorefrontType.arcana => websiteKey == 'arcana',
      StorefrontType.deadstock => websiteKey == 'deadstock',
    };
  }

  Future<void> _loadMoreProducts() async {
    // กันยิงซ้ำระหว่างโหลด หรือถ้าไม่มีหน้าถัดไปแล้ว
    if (_isInitialLoading || _isLoadingMore || !_hasNextPage) return;
    final requestId = _loadRequestId;

    setState(() => _isLoadingMore = true);

    try {
      // โหลดสินค้าเฉพาะหน้าถัดไป แล้วนำมาต่อท้าย list เดิม
      final page = await _repository.getProducts(
        type: _selectedType,
        languageCode: _selectedLanguage.code,
        categoryId: _selectedCategoryId,
        keyword: _searchKeyword,
        page: _currentPage + 1,
        limit: _pageSize,
      );

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        // spread list เดิม + list ใหม่ เพื่อให้ grid แสดงสินค้าเพิ่ม
        _products = [..._products, ...page.items];
        _currentPage = page.pagination.page;
        _hasNextPage = page.pagination.hasNextPage;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _handleScroll() {
    // Infinite scroll ใช้เฉพาะหน้า Home เท่านั้น
    if (_selectedFooterIndex != 0) return;
    if (!_scrollController.hasClients) return;
    // extentAfter คือระยะ scroll ที่เหลือด้านล่าง ถ้าน้อยกว่า 500px ให้โหลดเพิ่ม
    if (_scrollController.position.extentAfter < 500) {
      _loadMoreProducts();
    }
  }

  void _selectType(StorefrontType type) {
    if (_selectedType == type) return;

    // เปลี่ยนระหว่าง Arcana/Deadstock แล้ว reset category ก่อนโหลดใหม่
    setState(() {
      _selectedType = type;
      _selectedCategoryId = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
    _loadInitialStorefront();
  }

  void _selectLanguage(StorefrontLanguage language) {
    if (_selectedLanguage == language) return;

    // เปลี่ยนภาษาในหน้านี้ แจ้ง widget แม่ และโหลดข้อมูลตามภาษาใหม่
    setState(() {
      _selectedLanguage = language;
      _selectedCategoryId = null;
    });
    widget.onLanguageChanged(language);
    _loadInitialStorefront();
  }

  void _selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;

    // categoryId เป็น null หมายถึง "ทุกหมวดหมู่"
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _loadInitialStorefront();
  }

  void _focusSearch() {
    setState(() => _selectedFooterIndex = 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
      _searchFocusNode.requestFocus();
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      final keyword = value.trim();
      if (_searchKeyword == keyword) return;
      setState(() => _searchKeyword = keyword);
      _loadInitialStorefront();
    });
  }

  void _submitSearch(String value) {
    _searchDebounce?.cancel();
    final keyword = value.trim();
    if (_searchKeyword == keyword) return;
    setState(() => _searchKeyword = keyword);
    _loadInitialStorefront();
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty && _searchKeyword.isEmpty) return;
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _searchKeyword = '');
    _loadInitialStorefront();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _HeaderLogo(title: l10n.appTitle),
        actions: [
          PopupMenuButton<StorefrontLanguage>(
            initialValue: _selectedLanguage,
            onSelected: _selectLanguage,
            tooltip: 'Language',
            itemBuilder: (context) => [
              for (final language in StorefrontLanguage.values)
                PopupMenuItem(value: language, child: Text(language.label)),
            ],
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _selectedLanguage.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 13),
                ),
              ),
            ),
          ),
          if (_selectedFooterIndex != 0)
            IconButton(
              onPressed: _focusSearch,
              icon: const Icon(Icons.search),
              tooltip: 'Search',
            ),
          // Cart icon พร้อม badge จำนวน item — rebuild อัตโนมัติเมื่อ cart เปลี่ยน
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CartPage(lgCode: _selectedLanguage.code),
              ),
            ),
            icon: AnimatedBuilder(
              animation: CartController.instance,
              builder: (context, child) {
                final count = CartController.instance.itemCount;
                if (count <= 0) return child!;
                return Badge.count(
                  count: count > 99 ? 99 : count,
                  child: child!,
                );
              },
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            tooltip: 'Cart',
          ),
        ],
      ),
      body: SafeArea(child: _buildSelectedBody(context, l10n)),
      bottomNavigationBar: NavigationBar(
        // index นี้ใช้เลือก body หลักของหน้า เช่น Home/Notification/Chat/Profile
        selectedIndex: _selectedFooterIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedFooterIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.homeNavLabel,
          ),
          NavigationDestination(
            icon: _NotificationNavIcon(
              unreadCount: _notificationController.unreadCount,
              selected: false,
            ),
            selectedIcon: _NotificationNavIcon(
              unreadCount: _notificationController.unreadCount,
              selected: true,
            ),
            label: l10n.notificationsNavLabel,
          ),
          NavigationDestination(
            icon: _ChatNavIcon(
              unreadCount: _chatController.totalUnreadCount,
              selected: false,
            ),
            selectedIcon: _ChatNavIcon(
              unreadCount: _chatController.totalUnreadCount,
              selected: true,
            ),
            label: l10n.chat,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.profileNavLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBody(BuildContext context, AppLocalizations l10n) {
    // สลับเนื้อหาตาม bottom navigation
    switch (_selectedFooterIndex) {
      case 1:
        return NotificationsPage(controller: _notificationController);
      case 2:
        return ChatTab(controller: _chatController);
      case 3:
        return const _AccountTab();
      case 0:
      default:
        return _buildHomeBody(context, l10n);
    }
  }

  Widget _buildHomeBody(BuildContext context, AppLocalizations l10n) {
    final isArcana = _selectedType == StorefrontType.arcana;
    final String sectionTitle;
    if (_searchKeyword.isNotEmpty) {
      sectionTitle = 'ผลการค้นหา "$_searchKeyword"';
    } else if (isArcana) {
      sectionTitle = l10n.curatedForYou;
    } else {
      sectionTitle = l10n.freshStockDrops;
    }

    // ใช้ ListView ตัวเดียวครอบ hero/category/grid เพื่อให้ scroll controller ตรวจ infinite scroll ได้ง่าย
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _HeroSection(
          type: _selectedType,
          onShopPressed: () {
            _selectType(
              isArcana ? StorefrontType.deadstock : StorefrontType.arcana,
            );
          },
        ),
        const SizedBox(height: 18),
        _QuickActions(type: _selectedType),
        const SizedBox(height: 22),
        _CouponPreviewSection(
          coupons: _availableCoupons.where(_couponMatchesSelectedType).toList(),
          loading: _couponsLoading,
          claimingCouponId: _claimingCouponId,
          onClaim: _claimCoupon,
          onViewAll: _openCouponsPage,
        ),
        const SizedBox(height: 22),
        _ProductSearchField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          onSubmitted: _submitSearch,
          onClear: _clearSearch,
        ),
        const SizedBox(height: 22),
        if (_isInitialLoading)
          const _StorefrontLoading()
        else if (_loadError != null)
          // ถ้าโหลดหน้าแรกไม่สำเร็จ แสดง error พร้อมปุ่ม retry
          _StorefrontError(onRetry: _loadInitialStorefront)
        else ...[
          _CategoryScroller(
            categories: _categories,
            selectedCategoryId: _selectedCategoryId,
            onSelected: _selectCategory,
          ),
          const SizedBox(height: 22),
          Text(sectionTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _ProductPreviewGrid(
            products: _products,
            language: _selectedLanguage,
            resolveImageUrl: _repository.resolveAssetUrl,
          ),
          // spinner เล็กด้านล่าง ใช้ตอนโหลด page ถัดไป
          if (_isLoadingMore) const _LoadingMoreProducts(),
        ],
      ],
    );
  }
}

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    // Logo บน AppBar: รูปไอคอนแอป + ชื่อแอปจาก localization
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

class _NotificationNavIcon extends StatelessWidget {
  const _NotificationNavIcon({
    required this.unreadCount,
    required this.selected,
  });

  final int unreadCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? Icons.notifications : Icons.notifications_outlined,
    );
    if (unreadCount <= 0) return icon;

    return Badge.count(
      count: unreadCount,
      isLabelVisible: unreadCount > 0,
      child: icon,
    );
  }
}

class _ChatNavIcon extends StatelessWidget {
  const _ChatNavIcon({required this.unreadCount, required this.selected});

  final int unreadCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? Icons.chat_bubble : Icons.chat_bubble_outline);
    if (unreadCount <= 0) return icon;

    return Badge.count(
      count: unreadCount > 99 ? 99 : unreadCount,
      isLabelVisible: unreadCount > 0,
      child: icon,
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthSession.instance,
      builder: (context, _) {
        final session = AuthSession.instance;
        if (!session.isLoggedIn) {
          return _LoginPrompt(onLoginPressed: () => _openLogin(context));
        }

        final user = session.user!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    _initialFor(user.username),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _AccountMenuItem(
              icon: Icons.person_outline,
              title: 'ข้อมูลส่วนตัว',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
            ),
            _AccountMenuItem(
              icon: Icons.location_on_outlined,
              title: 'ที่อยู่จัดส่ง',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddressPage())),
            ),
            _AccountMenuItem(
              icon: Icons.credit_card_outlined,
              title: 'บัตรชำระเงิน',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaymentMethodsPage()),
              ),
            ),
            _AccountMenuItem(
              icon: Icons.lock_outline,
              title: 'เปลี่ยนรหัสผ่าน',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              ),
            ),
            _AccountMenuItem(
              icon: Icons.receipt_long_outlined,
              title: 'การซื้อของฉัน',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const OrderListPage())),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: AuthSession.instance.logout,
              icon: const Icon(Icons.logout),
              label: const Text('ออกจากระบบ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  String _initialFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'บัญชีของฉัน',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'เข้าสู่ระบบเพื่อดูข้อมูลบัญชี ที่อยู่จัดส่ง และคำสั่งซื้อของคุณ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onLoginPressed,
              icon: const Icon(Icons.login),
              label: const Text('เข้าสู่ระบบ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  const _AccountMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ProductSearchField extends StatelessWidget {
  const _ProductSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'ค้นหาสินค้า',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close),
              tooltip: 'Clear search',
            );
          },
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _CategoryScroller extends StatelessWidget {
  const _CategoryScroller({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<StorefrontCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    // แถบหมวดหมู่แนวนอน มี chip แรกเป็น "ทั้งหมด"
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : categories[index - 1];
          final selected = isAll
              ? selectedCategoryId == null
              : selectedCategoryId == category!.id;

          // ChoiceChip ที่ถูกเลือกจะใช้กรองสินค้าแล้วโหลดหน้าแรกใหม่
          return ChoiceChip(
            selected: selected,
            label: Text(isAll ? l10n.allCategories : category!.name),
            onSelected: (_) => onSelected(isAll ? null : category!.id),
          );
        },
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.type, required this.onShopPressed});

  final StorefrontType type;
  final VoidCallback onShopPressed;

  @override
  Widget build(BuildContext context) {
    final isArcana = type == StorefrontType.arcana;
    // Hero เปลี่ยนสีและข้อความตามประเภท storefront ที่เลือก
    final background = isArcana
        ? const Color(0xFF0F4C81)
        : const Color(0xFF332F2A);
    final accent = isArcana ? const Color(0xFF9ED8FF) : const Color(0xFFFFB457);

    return Container(
      constraints: const BoxConstraints(minHeight: 170),
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
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            isArcana
                ? 'สินค้าคัดพิเศษสำหรับสุขภาพ ไลฟ์สไตล์ และของใช้คุณภาพสูง'
                : 'สินค้า stock พิเศษ ราคาดี จำนวนจำกัด พร้อมให้เลือกก่อนหมด',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xD1FFFFFF)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onShopPressed,
            icon: Icon(
              isArcana ? Icons.storefront_outlined : Icons.spa_outlined,
            ),
            label: Text(isArcana ? 'Shop Deadstock' : 'Shop Arcana'),
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
    // Quick action เป็นข้อความสั้นๆ ด้านใต้ hero เปลี่ยนตาม Arcana/Deadstock
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

class _CouponPreviewSection extends StatelessWidget {
  const _CouponPreviewSection({
    required this.coupons,
    required this.loading,
    required this.claimingCouponId,
    required this.onClaim,
    required this.onViewAll,
  });

  final List<Coupon> coupons;
  final bool loading;
  final int? claimingCouponId;
  final ValueChanged<Coupon> onClaim;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final previewCoupons = coupons.take(5).toList();
    if (!loading && previewCoupons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'คูปองสำหรับคุณ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton(onPressed: onViewAll, child: const Text('ดูทั้งหมด')),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: loading && previewCoupons.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: previewCoupons.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final coupon = previewCoupons[index];
                    return SizedBox(
                      width: 292,
                      child: CouponCard(
                        coupon: coupon,
                        compact: true,
                        claiming: claimingCouponId == coupon.coId,
                        onClaim: () => onClaim(coupon),
                      ),
                    );
                  },
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPreviewGrid extends StatelessWidget {
  const _ProductPreviewGrid({
    required this.products,
    required this.language,
    required this.resolveImageUrl,
  });

  final List<Product> products;
  final StorefrontLanguage language;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _EmptyProducts();
    }

    // Grid สินค้า 2 คอลัมน์ ปิด scroll ของตัวเองเพื่อให้ ListView แม่เป็นคน scroll
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (context, index) => _ProductPreviewCard(
        product: products[index],
        imageUrl: resolveImageUrl(products[index].imageUrl),
        language: language,
      ),
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  const _ProductPreviewCard({
    required this.product,
    required this.imageUrl,
    required this.language,
  });

  final Product product;
  final String imageUrl;
  final StorefrontLanguage language;

  @override
  Widget build(BuildContext context) {
    return ProductCard(
      product: product,
      imageUrl: imageUrl,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductVariantPage(
              product: product,
              language: language,
              initialImageUrl: imageUrl,
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionData {
  const _QuickActionData(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _StorefrontLoading extends StatelessWidget {
  const _StorefrontLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StorefrontError extends StatelessWidget {
  const _StorefrontError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_outlined, size: 36),
          const SizedBox(height: 10),
          Text(l10n.loadError, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          l10n.emptyProducts,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _LoadingMoreProducts extends StatelessWidget {
  const _LoadingMoreProducts();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
