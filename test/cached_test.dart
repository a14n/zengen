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

library zengen.cached;

import 'dart:async';

import 'package:unittest/unittest.dart';
import 'package:zengen/zengen.dart';

import 'transformation.dart';

main() {
  group('CustomCache', () {

    test('should cache result', () {
      int n = 0;
      final cache = new CustomCache(() {
        n++;
        return 1;
      });
      cache.getValue([]);
      expect(n, equals(1));
      cache.getValue([]);
      expect(n, equals(1));
    });

    test('should cache result with different parameters', () {
      int n = 0;
      final cache = new CustomCache((int i) {
        n++;
        return 1;
      });
      cache.getValue([1]);
      expect(n, equals(1));
      cache.getValue([2]);
      expect(n, equals(2));
      cache.getValue([1]);
      expect(n, equals(2));
      cache.getValue([2]);
      expect(n, equals(2));
    });

    test('should not cache result with maxCapacity=0', () {
      int n = 0;
      final cache = new CustomCache(() {
        n++;
        return 1;
      }, maxCapacity: 0);
      cache.getValue([]);
      expect(n, equals(1));
      cache.getValue([]);
      expect(n, equals(2));
    });

    test('should cache result with maxCapacity=2', () {
      int n = 0;
      final cache = new CustomCache(() {
        n++;
        return 1;
      }, maxCapacity: 2);
      cache.getValue([]);
      expect(n, equals(1));
      cache.getValue([]);
      expect(n, equals(1));
    });

    test('should expire the cache after access', () {
      int n = 0;
      final cache = new CustomCache(() {
        n++;
        return 1;
      }, expireAfterAccess: const Duration(milliseconds: 30));
      cache.getValue([]);
      expect(n, equals(1));
      cache.getValue([]);
      expect(n, equals(1));
      final t = new Timer.periodic(const Duration(milliseconds: 10), (t) {
        cache.getValue([]);
      });
      new Timer(const Duration(milliseconds: 50), () {
        expect(n, equals(1));
        t.cancel();
        new Timer(const Duration(milliseconds: 50), () {
          cache.getValue([]);
          expect(n, equals(2));
          cache.getValue([]);
          expect(n, equals(2));
        });
      });
    });

    test('should expire the cache after write', () {
      int n = 0;
      final cache = new CustomCache(() {
        n++;
        return 1;
      }, expireAfterWrite: const Duration(milliseconds: 30));
      cache.getValue([]);
      expect(n, equals(1));
      cache.getValue([]);
      expect(n, equals(1));
      final t = new Timer.periodic(const Duration(milliseconds: 10), (t) {
        cache.getValue([]);
      });
      new Timer(const Duration(milliseconds: 50), () {
        cache.getValue([]);
        expect(n, equals(2));
        cache.getValue([]);
        expect(n, equals(2));
        t.cancel();
      });
    });

  });

  testTransformation('@Cached() should accept getters',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @Cached() get a => "String";
  @Cached() get b { return "String"; }
}
''',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @generated get a => _caches.putIfAbsent(#a, () => _createCache(#a, () => "String")).getValue([]);
  @generated get b => _caches.putIfAbsent(#b, () => _createCache(#b, () {return "String";})).getValue([]);
  @generated final _caches = <Symbol, Cache> {};
  @generated Cache _createCache(Symbol methodName, Function compute) => new Cache(compute);
}
'''
      );

  testTransformation('@Cached() should accept methods with parameters',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @Cached() int m1() => 1;
  @Cached() int m2(int p1) => 1;
  @Cached() int m3(int p1, p2, String p3) => 1;
}
''',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @generated int m1() => _caches.putIfAbsent(#m1, () => _createCache(#m1, () => 1)).getValue([]);
  @generated int m2(int p1) => _caches.putIfAbsent(#m2, () => _createCache(#m2, (int p1) => 1)).getValue([p1]);
  @generated int m3(int p1, p2, String p3) => _caches.putIfAbsent(#m3, () => _createCache(#m3, (int p1, p2, String p3) => 1)).getValue([p1, p2, p3]);
  @generated final _caches = <Symbol, Cache> {};
  @generated Cache _createCache(Symbol methodName, Function compute) => new Cache(compute);
}
'''
      );

  testTransformation(
      '@Cached() should accept methods with optional positional parameters',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @Cached() int m2([int p1]) => 1;
  @Cached() int m3(int p1, [p2, String p3]) => 1;
}
''',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @generated int m2([int p1]) => _caches.putIfAbsent(#m2, () => _createCache(#m2, ([int p1]) => 1)).getValue([p1]);
  @generated int m3(int p1, [p2, String p3]) => _caches.putIfAbsent(#m3, () => _createCache(#m3, (int p1, [p2, String p3]) => 1)).getValue([p1, p2, p3]);
  @generated final _caches = <Symbol, Cache> {};
  @generated Cache _createCache(Symbol methodName, Function compute) => new Cache(compute);
}
'''
      );

  testTransformation(
      '@Cached() should accept methods with optional named parameters',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @Cached() int m2({int p1}) => 1;
  @Cached() int m3(int p1, {p2, String p3}) => 1;
}
''',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @generated int m2({int p1}) => _caches.putIfAbsent(#m2, () => _createCache(#m2, ({int p1}) => 1)).getValue([], {#p1: p1});
  @generated int m3(int p1, {p2, String p3}) => _caches.putIfAbsent(#m3, () => _createCache(#m3, (int p1, {p2, String p3}) => 1)).getValue([p1], {#p2: p2, #p3: p3});
  @generated final _caches = <Symbol, Cache> {};
  @generated Cache _createCache(Symbol methodName, Function compute) => new Cache(compute);
}
'''
      );

  testTransformation('@Cached() should keep the user defined _createCache',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @Cached() get a => "String";
  Cache _createCache(Symbol methodName, Function compute) => null;
}
''',
      r'''
import 'package:zengen/zengen.dart';
class A {
  @generated get a => _caches.putIfAbsent(#a, () => _createCache(#a, () => "String")).getValue([]);
  Cache _createCache(Symbol methodName, Function compute) => null;
  @generated final _caches = <Symbol, Cache> {};
}
'''
      );
}
