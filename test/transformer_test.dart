// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:barback/barback.dart';
import 'package:zengen/transformer.dart';
import 'package:quiver/async.dart';
import 'package:unittest/unittest.dart';

main() {
  group('toString', () {
    test('simple', () {
      final source =
          r'''
import 'package:zengen/zengen.dart';
@ToString()
class A {
  static var s;
  var a;
  int b;
  A();
}
''';
      return _transform([new Asset.fromString(new AssetId('foo', 'a/b/c.dart'),
          source)]).then((outAsserts) {
        expect(outAsserts, hasLength(1));
        final asset = outAsserts.first;
        return asset.readAsString().then((content) {
          expect(content,
              r'''
import 'package:zengen/zengen.dart';
@ToString()
class A {
  static var s;
  var a;
  int b;
  A();
  @generated @override String toString() => "A(a=$a, b=$b)";
}
'''
              );
        });
      });
    });
  });
}

Future<List<Asset>> _transform(List<Asset> assets) {
  final transformerGroup = new ZengenTransformer.asPlugin();
  final phases = transformerGroup.phases.map((e) => e.toList()).toList();
  List<Asset> outs = assets;
  return forEachAsync(phases, (phase) {
    return forEachAsync(phase, (transformer) {
      final newOuts = [];
      return forEachAsync(outs, (asset) {
        return transformer.isPrimary(asset.id).then((isPrimary) {
          final transform = new _MockTransform()
              ..ins = outs
              ..primaryInput = asset
              ..output = asset;
          return transformer.apply(transform).then((_) {
            newOuts.add(transform.output);
          });
        });
      }).then((_) {
        outs = newOuts;
      });
    });
  }).then((_) => outs);
}

class _MockTransform implements Transform {
  bool shouldConsumePrimary = false;
  Asset primaryInput;
  List<Asset> ins = [];
  Asset output;
  TransformLogger logger = new TransformLogger(_mockLogFn);

  _MockTransform();

  Future<Asset> getInput(AssetId id) => new Future.value(ins.firstWhere((a) =>
      a.id == id));

  void addOutput(Asset output) {
    if (output.id != primaryInput.id) throw new Error();
    this.output = output;
  }

  void consumePrimary() {
    shouldConsumePrimary = true;
  }

  readInput(id) => throw new UnimplementedError();
  Future<String> readInputAsString(AssetId id, {encoding}) {
    return ins.firstWhere((a) => a.id == id, orElse: () => new Asset.fromPath(
        id, 'packages/${id.package}/${id.path.substring('lib/'.length)}')).readAsString(
        );
  }
  Future<bool> hasInput(id) => new Future.value(ins.any((a) => a.id == id));

  static void _mockLogFn(AssetId asset, LogLevel level, String message, span) {
    // Do nothing.
  }
}
