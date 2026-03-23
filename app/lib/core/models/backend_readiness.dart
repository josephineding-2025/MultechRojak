class BackendReadiness {
  const BackendReadiness({
    required this.status,
    required this.version,
    required this.readiness,
    required this.missingCoreEnv,
    required this.missingOptionalEnv,
    required this.capabilities,
  });

  final String status;
  final String version;
  final String readiness;
  final List<String> missingCoreEnv;
  final List<String> missingOptionalEnv;
  final Map<String, bool> capabilities;

  bool get isReady => readiness == 'ready';
  bool get isReachable => status == 'ok';
  bool get needsConfig => isReachable && !isReady;

  bool capabilityEnabled(String name) => capabilities[name] ?? false;

  factory BackendReadiness.fromJson(Map<String, dynamic> json) {
    final rawCapabilities = json['capabilities'];
    return BackendReadiness(
      status: json['status'] as String? ?? 'unknown',
      version: json['version'] as String? ?? '0.0.0',
      readiness: json['readiness'] as String? ?? 'config_needed',
      missingCoreEnv: (json['missing_core_env'] as List<dynamic>? ?? const [])
          .map((value) => value as String)
          .toList(),
      missingOptionalEnv:
          (json['missing_optional_env'] as List<dynamic>? ?? const [])
              .map((value) => value as String)
              .toList(),
      capabilities: rawCapabilities is Map<String, dynamic>
          ? rawCapabilities.map(
              (key, value) => MapEntry(key, value as bool? ?? false),
            )
          : const {},
    );
  }
}
