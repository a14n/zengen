// Copyright (c) 2014, Alexandre Ardhuin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library zengen.library_with_parts;

import 'package:barback/barback.dart';
import 'package:quiver/async.dart';
import 'package:unittest/unittest.dart';

import 'transformation.dart';

main() {
  test('modify parts of a library', () => transformAssets([new Asset.fromString(
      new AssetId('foo', 'l.dart'),
      r"""
library l;
import 'package:zengen/zengen.dart';
part 'src/p1.dart';
part 'src/p2.dart';
@ToString()
class L {}
"""
      ), new Asset.fromString(new AssetId('foo', 'src/p1.dart'),
      r"""
part of l;
@ToString()
class P1 {}
"""), new Asset.fromString(new AssetId(
      'foo', 'src/p2.dart'),
      r"""
part of l;
@EqualsAndHashCode()
class P2 {
  int a;
}
""")]).then(
      (outAsserts) {
    expect(outAsserts, hasLength(3));
    return forEachAsync(outAsserts, (Asset asset) {
      return asset.readAsString().then((content) {
        if (asset.id.path == 'l.dart') {
          expect(content,
              r"""
library l;
import 'package:zengen/zengen.dart';
part 'src/p1.dart';
part 'src/p2.dart';
@ToString()
class L {  @generated @override String toString() => "L()";
}
"""
              );
        }
        if (asset.id.path == 'src/p1.dart') {
          expect(content,
              r"""
part of l;
@ToString()
class P1 {  @generated @override String toString() => "P1()";
}
"""
              );
        }
        if (asset.id.path == 'src/p2.dart') {
          expect(content,
              r"""
part of l;
@EqualsAndHashCode()
class P2 {
  int a;
  @generated @override int get hashCode => hashObjects([a]);
  @generated @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a;
}
"""
              );
        }
      });
    });
  }));
}
