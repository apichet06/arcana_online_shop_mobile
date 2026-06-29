import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';
import 'package:arcana_online_shop_mobile/features/cart/data/cart_api.dart';
import 'package:arcana_online_shop_mobile/features/cart/domain/cart.dart';
import 'package:arcana_online_shop_mobile/features/cart/domain/cart_item.dart';

// Singleton ChangeNotifier สำหรับ cart state ทั้งแอป
// ใช้ AnimatedBuilder(animation: CartController.instance, ...) เพื่อ rebuild badge
class CartController extends ChangeNotifier {
  CartController._() {
    // ฟัง auth state — login: โหลด cart, logout: ล้าง cart
    AuthSession.instance.addListener(_handleAuthChanged);

    // ถ้า session initialize แล้วและ login อยู่ ให้โหลด cart ทันที
    if (AuthSession.instance.isLoggedIn) {
      unawaited(refresh());
    }
  }

  // Singleton: ใช้ร่วมกันทั้งแอป ไม่ต้อง dispose
  static final CartController instance = CartController._();

  final CartApi _api = CartApi(client: ApiClient());

  Cart _cart = Cart.empty;
  // true ระหว่างโหลด — ใช้แสดง spinner ในหน้า CartPage ตอนยังไม่มี items
  bool _loading = false;

  Cart get cart => _cart;
  bool get loading => _loading;
  // itemCount ใช้แสดง badge บน cart icon ทุกหน้า
  int get itemCount => _cart.itemCount;
  List<CartItem> get items => _cart.items;

  void _handleAuthChanged() {
    if (AuthSession.instance.isLoggedIn) {
      unawaited(refresh());
    } else {
      _clearCart();
    }
  }

  void _clearCart() {
    _cart = Cart.empty;
    notifyListeners();
  }

  // โหลด cart ใหม่ทั้งหมดจาก API พร้อมชื่อสินค้าตามภาษา
  // หมายเหตุ: ไม่ notifyListeners() ก่อน await เพราะ CartController.instance
  // อาจถูก access ครั้งแรกใน AnimatedBuilder ระหว่าง build frame
  // ซึ่งจะทำให้เกิด "setState during build" error
  Future<void> refresh({String lgCode = 'th'}) async {
    if (!AuthSession.instance.isLoggedIn) return;
    _loading = true;
    try {
      _cart = await _api.fetchCart(lgCode: lgCode);
    } catch (_) {
      // silent — คงค่าเดิมถ้า network ล้มเหลว
    } finally {
      _loading = false;
      // notifyListeners ปลอดภัยเสมอเพราะอยู่หลัง await
      notifyListeners();
    }
  }

  // เพิ่มสินค้า แล้ว refresh เพื่ออัปเดต badge + item list
  // โยน ApiException ถ้า API ล้���เหลว — ให้ caller แสดง error เอง
  Future<void> addItem({
    required int pvId,
    int qty = 1,
    String lgCode = 'th',
  }) async {
    await _api.addItem(pvId: pvId, qty: qty);
    // refresh เพื่ออัปเดต badge และรับ item ที่เพิ่มใหม่
    try {
      await refresh(lgCode: lgCode);
    } catch (_) {
      // refresh failure ไม่ถือว่า addItem ล้ม��หลว
    }
  }

  // ลบ cart item — optimistic update ทันที แล้วส่ง API ตาม
  Future<void> removeItem({required int ciId}) async {
    // Optimistic: ลบออกจาก local state ก่อนเพื่อ UX ลื่น
    final updated = _cart.items.where((i) => i.ciId != ciId).toList();
    _cart = _cart.withItems(updated);
    notifyListeners();

    try {
      await _api.removeItem(ciId: ciId);
    } catch (_) {
      // rollback: โหลดใหม่ถ้า API ล้มเหลว
      await refresh();
    }
  }

  // แก้จำนวน — ส่ง API แล้ว refresh เพื่อรับ line_total ที่ถูกต้องจาก server
  // unawaited refresh ทำให้ stepper กลับ enable ได้เร็ว ไม่ต้องรอ refresh เสร็จ
  Future<void> updateQty({
    required int ciId,
    required int qty,
    String lgCode = 'th',
  }) async {
    try {
      await _api.updateItemQty(ciId: ciId, qty: qty);
    } finally {
      // sync ทั้ง success และ failure เพื่อ rollback ถ้าจำเป็น
      unawaited(refresh(lgCode: lgCode));
    }
  }

  // เลือก/ยกเลิกเลือกทุก item พร้อมกัน
  // Optimistic update ทันที แล้วยิง API แบบ parallel
  Future<void> selectAll({required bool selected, String lgCode = 'th'}) async {
    // หา item ที่ต้องเปลี่ยน state จริงๆ เพื่อลดจำนวน API call
    final toUpdate = _cart.items.where((i) => i.isSelected != selected).toList();
    if (toUpdate.isEmpty) return;

    // Optimistic: set isSelected ทุก item ทันที
    final updated = _cart.items.map((i) => i.copyWith(isSelected: selected)).toList();
    _cart = _cart.withItems(updated);
    notifyListeners();

    try {
      // ยิง API parallel สำหรับแต่ละ item ที่ต้องเปลี่ยน
      await Future.wait(
        toUpdate.map(
          (i) => _api.toggleItemSelect(ciId: i.ciId, isSelected: selected),
        ),
      );
    } catch (_) {
      // rollback ถ้ามี API ล้มเหลว
      await refresh(lgCode: lgCode);
    }
  }

  // toggle selected — optimistic update ก่อน API
  Future<void> toggleSelect({
    required int ciId,
    required bool isSelected,
  }) async {
    // Optimistic: อัปเดต isSelected ใน local state ทันที
    final updated = _cart.items.map((i) {
      return i.ciId == ciId ? i.copyWith(isSelected: isSelected) : i;
    }).toList();
    _cart = _cart.withItems(updated);
    notifyListeners();

    try {
      await _api.toggleItemSelect(ciId: ciId, isSelected: isSelected);
    } catch (_) {
      await refresh(); // rollback ถ้า API ���้มเหลว
    }
  }
}
