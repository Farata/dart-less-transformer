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
    var id = transform.primaryInput.id;
    var newId = id.changeExtension('.css');
    transform.logger.info('Compiling to ${newId.path}', asset: id);

    return Process.run(_options.executable, ['${id.path}']).then((result) {
      transform.addOutput(new Asset.fromString(newId, result.stdout));
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
  // Fail parsing if invalid value specified for `src` parameter.
  var src = args['src'];
  if (src != null) {
    if (src is! String && src is! List<String>) {
      throw 'Invalid value of `src` parameter. Should be either a string or a '
        'list of strings';
    }
  }

  // Expect `lessc` available on the PATH if path to the executable isn't
  // explicitly configured for the transformer.
  var executable = 'lessc';
  if (args['executable'] == null) {
    executable = args['executable'];
  }

  return new TransformOptions(executable: executable, src: src);
}

/// Options used by [LessTransformer].
class TransformOptions {
  /// Path to `lessc` executable.
  final String executable;

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

  TransformOptions({this.executable, this.src});
}
