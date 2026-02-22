import 'package:build_cli_annotations/build_cli_annotations.dart';

part 'autodoc_options.g.dart';

/// CLI options for the autodoc command.
@CliOptions()
class AutodocOptions {
  /// Scan repo and create initial autodoc.json.
  @CliOption(help: 'Scan repo and create initial autodoc.json')
  final bool init;

  /// Regenerate all docs regardless of hash.
  @CliOption(help: 'Regenerate all docs regardless of hash')
  final bool force;

  /// Only generate for a specific module.
  @CliOption(help: 'Only generate for a specific module')
  final String? module;

  const AutodocOptions({this.init = false, this.force = false, this.module});

  factory AutodocOptions.fromArgResults(ArgResults results) {
    return _$parseAutodocOptionsResult(results);
  }
}

extension AutodocOptionsArgParser on AutodocOptions {
  static void populateParser(ArgParser parser) {
    _$populateAutodocOptionsParser(parser);
  }
}
