import 'package:flutter/material.dart';

enum StorefrontLanguage {
  thai('th', 'ไทย'),
  english('en', 'EN'),
  japanese('ja', '日本語');

  const StorefrontLanguage(this.code, this.label);

  final String code;
  final String label;

  Locale get locale => Locale(code);
}
