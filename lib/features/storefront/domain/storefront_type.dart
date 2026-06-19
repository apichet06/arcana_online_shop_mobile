enum StorefrontType {
  arcana,
  deadstock,
}

extension StorefrontTypeLabel on StorefrontType {
  String get title {
    switch (this) {
      case StorefrontType.arcana:
        return 'Arcana Premium';
      case StorefrontType.deadstock:
        return 'Deadstock';
    }
  }
}
