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

library zengen.equals_and_hashcode;

import 'src/transformation.dart';

main() {
  testTransformation(
      '@EqualsAndHashCode() should create the getter hashCode and the operator==',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class _A {
  static var s;
  var a;
  int b;
  _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  static var s;
  var a;
  int b;
  A();
  @override int get hashCode => hashObjects([a, b]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a && o.b == b;
}
''');

  testTransformation(
      '@EqualsAndHashCode() should not use hashCode getter',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class _A {
  static var s;
  var a;
  int b;
  _A();
  int get hashCode => 1;
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  static var s;
  var a;
  int b;
  A();
  int get hashCode => 1;
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a && o.b == b;
}
''');

  testTransformation(
      '@EqualsAndHashCode() should not use private accessors',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class _A {
  var a, _b;
  _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  var a, _b;
  A();
  @override int get hashCode => hashObjects([a]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a;
}
''');

  testTransformation(
      '@EqualsAndHashCode(includePrivate: true) should use private accessors',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(includePrivate: true)
class _A {
  var a, _b;
  _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  var a, _b;
  A();
  @override int get hashCode => hashObjects([a, _b]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a && o._b == _b;
}
''');

  testTransformation(
      '@EqualsAndHashCode(callSuper: true) should call super',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(callSuper: true)
class _B extends A {
  static var s;
  final c;
  final String d;
  _B(this.c, this.d);
}
''',
      r'''
@GeneratedFrom(_B)
class B extends A {
  static var s;
  final c;
  final String d;
  B(this.c, this.d);
  @override int get hashCode => hashObjects([super.hashCode, c, d]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && super == o && o.c == c && o.d == d;
}
''');

  testTransformation(
      "@EqualsAndHashCode(callSuper: false) shouldn't call super",
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(callSuper: false)
class _C extends A {
  static var s;
  final c;
  final String d;
  _C(this.c, this.d);
}
''',
      r'''
@GeneratedFrom(_C)
class C extends A {
  static var s;
  final c;
  final String d;
  C(this.c, this.d);
  @override int get hashCode => hashObjects([c, d]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.c == c && o.d == d;
}
''');

  testTransformation(
      '@EqualsAndHashCode(exclude: const[#b, #d]) should not use b or d',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(exclude: const [#b, #d])
class _D {
  static var s;
  var a;
  int b;
  String c, d;
  _D();
}
''',
      r'''
@GeneratedFrom(_D)
class D {
  static var s;
  var a;
  int b;
  String c, d;
  D();
  @override int get hashCode => hashObjects([a, c]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a && o.c == c;
}
''',
      skip: true);
}
