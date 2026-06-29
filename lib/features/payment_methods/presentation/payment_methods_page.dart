import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:arcana_online_shop_mobile/features/payment_methods/domain/saved_payment_method.dart';
import 'package:arcana_online_shop_mobile/features/payment_methods/presentation/add_card_page.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final _api = PaymentMethodsApi();

  List<SavedPaymentMethod> _methods = [];
  bool _loading = true;
  String? _error;
  int? _actionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final methods = await _api.listMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ กรุณาลองใหม่';
        _loading = false;
      });
    }
  }

  Future<void> _setDefault(SavedPaymentMethod method) async {
    setState(() => _actionId = method.upmId);
    try {
      final updated = await _api.setDefault(method.upmId);
      if (!mounted) return;
      setState(() {
        _methods = _methods.map((item) {
          return item.copyWith(isDefault: item.upmId == updated.upmId);
        }).toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ตั้งเป็นบัตรหลักแล้ว')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _actionId = null);
    }
  }

  Future<void> _delete(SavedPaymentMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบบัตร'),
        content: Text('ต้องการลบ ${method.displayLabel} ออกจากบัญชีหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบบัตร'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionId = method.upmId);
    try {
      await _api.deleteMethod(method.upmId);
      if (!mounted) return;
      setState(() {
        _methods = _methods
            .where((item) => item.upmId != method.upmId)
            .toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลบบัตรเรียบร้อยแล้ว')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _actionId = null);
    }
  }

  Future<void> _openAddCard() async {
    final added = await Navigator.of(context).push<SavedPaymentMethod>(
      MaterialPageRoute(builder: (_) => const AddCardPage()),
    );
    if (added == null) return;

    setState(() {
      final others = _methods.where((item) => item.upmId != added.upmId);
      final updated = added.isDefault
          ? others.map((item) => item.copyWith(isDefault: false)).toList()
          : others.toList();
      _methods = [added, ...updated];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกบัตรเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('บัตรชำระเงิน')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _methods.isEmpty
          ? _EmptyView(onAdd: _openAddCard)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _methods.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final method = _methods[index];
                return _CardTile(
                  method: method,
                  isBusy: _actionId == method.upmId,
                  onSetDefault: () => _setDefault(method),
                  onDelete: () => _delete(method),
                );
              },
            ),
      floatingActionButton: _loading || _error != null || _methods.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddCard,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มบัตร'),
            ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.method,
    required this.isBusy,
    required this.onSetDefault,
    required this.onDelete,
  });

  final SavedPaymentMethod method;
  final bool isBusy;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.credit_card_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        method.displayLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (method.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'บัตรหลัก',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (method.expiryLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'หมดอายุ ${method.expiryLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (method.cardName != null &&
                      method.cardName!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      method.cardName!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isBusy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Row(
                children: [
                  if (!method.isDefault)
                    TextButton(
                      onPressed: onSetDefault,
                      child: const Text('ตั้งหลัก'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'ลบบัตร',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.credit_card_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีบัตรที่บันทึกไว้',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มบัตรใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
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
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}
