enum Environment {
  development,
  staging,
  production,
}

extension EnvironmentExtension on Environment {
  String get name {
    switch (this) {
      case Environment.development:
        return 'development';
      case Environment.staging:
        return 'staging';
      case Environment.production:
        return 'production';
    }
  }

  bool get isProduction => this == Environment.production;
}