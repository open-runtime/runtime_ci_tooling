/// Severity of an audit finding.
enum AuditSeverity { error, warning, info }

/// Category of a pubspec audit issue.
///
/// Each category maps to a specific rule that validates how a dependency is
/// declared relative to its entry in the package registry.
enum AuditCategory {
  /// The dep is just `name: ^version` with no git source.
  bareDependency,

  /// The git URL points to the wrong GitHub org.
  wrongOrg,

  /// The git URL points to the wrong repo name.
  wrongRepo,

  /// Git dep doesn't have a `tag_pattern` field.
  missingTagPattern,

  /// `tag_pattern` doesn't match the registry value.
  wrongTagPattern,

  /// Version constraint doesn't match the registry version.
  staleVersion,

  /// Git URL isn't using SSH format (`git@github.com:org/repo.git`).
  wrongUrlFormat,
}

/// A single finding from auditing a pubspec dependency against the package
/// registry.
class AuditFinding {
  /// Absolute path to the pubspec.yaml that was audited.
  final String pubspecPath;

  /// The dependency name that triggered this finding.
  final String dependencyName;

  /// How severe this finding is.
  final AuditSeverity severity;

  /// Which audit rule was violated.
  final AuditCategory category;

  /// Human-readable description of the issue.
  final String message;

  /// The current value in the pubspec (if applicable).
  final String? currentValue;

  /// The expected value from the registry (if applicable).
  final String? expectedValue;

  const AuditFinding({
    required this.pubspecPath,
    required this.dependencyName,
    required this.severity,
    required this.category,
    required this.message,
    this.currentValue,
    this.expectedValue,
  });

  @override
  String toString() => '[$severity] $dependencyName: $message';
}
