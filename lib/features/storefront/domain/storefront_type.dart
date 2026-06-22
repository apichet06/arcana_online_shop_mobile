enum StorefrontType { arcana, deadstock }

extension StorefrontTypeLabel on StorefrontType {
  int get catalogId {
    switch (this) {
      case StorefrontType.arcana:
        return 1;
      case StorefrontType.deadstock:
        return 2;
    }
  }
}
