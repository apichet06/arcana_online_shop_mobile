import 'package:flutter/material.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/address_lookup_api.dart';

// Dropdown ที่อยู่แบบค้นหาได้ — เปิด bottom sheet เมื่อกด
// ใช้ร่วมกันระหว่าง AddressFormPage และ RegisterPage
class LocationPickerField extends StatelessWidget {
  const LocationPickerField({
    super.key,
    required this.label,
    required this.selectedName,
    required this.options,
    required this.loading,
    required this.placeholder,
    required this.searchHint,
    required this.onSelected,
    this.enabled = true,
    this.prefixIcon = Icons.location_on_outlined,
    this.validator,
  });

  final String label;
  final String? selectedName;
  final List<LocationOption> options;
  final bool loading;
  final String placeholder;
  final String searchHint;
  final ValueChanged<LocationOption> onSelected;
  final bool enabled;
  final IconData prefixIcon;
  final FormFieldValidator<String>? validator;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<LocationOption>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => LocationPickerSheet(
        title: label,
        options: options,
        searchHint: searchHint,
      ),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: validator,
      builder: (field) {
        return InkWell(
          onTap: (enabled && !loading) ? () => _open(context) : null,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(prefixIcon),
              suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.arrow_drop_down),
              errorText: field.errorText,
            ),
            // เมื่อยังไม่ได้เลือก (isEmpty=true) ให้ child ว่างเปล่า
            // เพื่อให้ labelText อยู่กลาง field ทำหน้าที่เป็น placeholder
            // ถ้าส่ง Text(placeholder) ตอน isEmpty=true จะซ้อนทับกับ label
            isEmpty: selectedName == null,
            child: selectedName != null
                ? Text(selectedName!)
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

// Bottom sheet สำหรับค้นหาและเลือก province/district/subdistrict
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    required this.title,
    required this.options,
    required this.searchHint,
  });

  final String title;
  final List<LocationOption> options;
  final String searchHint;

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchController = TextEditingController();
  List<LocationOption> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final keyword = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = keyword.isEmpty
          ? widget.options
          : widget.options
              .where((o) => o.name.toLowerCase().contains(keyword))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.8;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('ไม่พบผลลัพธ์'))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final option = _filtered[index];
                      return ListTile(
                        title: Text(option.name),
                        onTap: () => Navigator.of(context).pop(option),
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
