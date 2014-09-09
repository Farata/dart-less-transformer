library less_transformer;

import 'dart:io';
import 'package:barback/barback.dart';
import 'package:quiver/pattern.dart' show Glob;


/// Transforms LESS files into CSS using external tool.
class LessTransformer extends Transformer {
  final TransformOptions _options;

  LessTransformer(this._options);

  LessTransformer.asPlugin(BarbackSettings settings)
    : this(_parseSettings(settings.configuration));

  @override
  isPrimary(AssetId id) =>
    id.extension == '.less' && _matchAssetPath(id.path);

  @override
  apply(Transform transform) {
    var oldId = transform.primaryInput.id;
    var newId = oldId.changeExtension('.css');

    var separator = Platform.isWindows ? ';' : ':';
    var paths = _options.include_path.isEmpty ? '' :
      '--include-path=${_options.include_path.join(separator)}';

    return Process.run(_options.executable, [paths, '${oldId.path}'])
        .then((result) {
          if (result.exitCode != 0) {
            transform.logger.error(result.stderr, asset: oldId);
            return;
          }

          transform.addOutput(new Asset.fromString(newId, result.stdout));
          transform.logger.info('Compiled to ${newId.path}', asset: oldId);
          if (_options.replace) {
            transform.consumePrimary();
          }
        });
  }

  /// Matches [Asset]'s path against configured glob patterns.
  bool _matchAssetPath(String path) {
    var src = _options.src;
    if (src == null) return true;
    if (src is String) return new Glob(src).hasMatch(path);
    if (src is List<String>) return src.any((p) => new Glob(p).hasMatch(path));
    return true;
  }
}

/// Parses and validates configured transformer's settings, provides default
/// values for [TransformOptions].
TransformOptions _parseSettings(Map args) {
  return new TransformOptions(
      // Expect `lessc` available on the PATH if path to the executable isn't
      // explicitly configured for the transformer.
      executable: _readStringValue(args, 'executable', 'lessc'),
      include_path: _readStringListValue(args, 'include_path'),
      replace: _readBoolValue(args, 'replace', false),
      src: _readStringListValue(args, 'src'));
}

/// Options used by [LessTransformer].
class TransformOptions {
  /// Path to `lessc` executable.
  final String executable;

  /// [String] or [Lisr<String>], where each value represents LESS include path
  /// that will be passed to the LESS [executable]. Paths can be absolute or
  /// relative to the package root. Example:
  ///
  ///   transformers:
  ///   - less_transformer:
  ///       include_path:
  ///         - web/bower_components
  ///         - web/styles
  ///
  final List<String> include_path;

  /// If `true` replaces LESS files with CSS ones. Otherwise keeps both type of
  /// files. Default is `false`.
  final bool replace;

  /// [String] or [List<String>], where each value represents glob pattern that
  /// will be used to match `*.less` files. Example:
  ///
  ///   transformers:
  ///   - less_transformer:
  ///       src:
  ///         - lib/components/*.less
  ///         - web/static/**/*
  ///
  final src;

  TransformOptions({
    this.executable,
    this.include_path,
    this.replace,
    this.src});
}

bool _readBoolValue(Map args, String name, [bool defaultValue]) {
  var value = args[name];
  if (value == null) return defaultValue;
  if (value is! bool) {
    print('LESS transformer parameter "$name" value must be a bool');
    return defaultValue;
  }
  return value;
}

String _readStringValue(Map args, String name, [String defaultValue]) {
  var value = args[name];
  if (value == null) return defaultValue;
  if (value is! String) {
    print('LESS transformer parameter "$name" value must be a string');
    return defaultValue;
  }
  return value;
}

List<String> _readStringListValue(Map args, String name) {
  var value = args[name];
  if (value == null) return [];
  var results = [];
  bool error;
  if (value is List) {
    results = value;
    error = value.any((e) => e is! String);
  } else if (value is String) {
    results = [value];
    error = false;
  } else {
    error = true;
  }
  if (error) {
    print('LESS transformer parameter "$name" value must be either a string or '
        'a list of strings');
  }
  return results;
}
