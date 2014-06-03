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

import 'transformation.dart';

main() {
  testTransformation(
      '@EqualsAndHashCode() should create the getter hashCode and the operator==',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class A {
  static var s;
  var a;
  int b;
  A();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class A {
  static var s;
  var a;
  int b;
  A();
  @generated @override int get hashCode => hashObjects([a, b]);
  @generated @override bool operator ==(o) => identical(this, o) || o is A && o.a == a && o.b == b;
}
'''
      );

  testTransformation('@EqualsAndHashCode() should not use hashCode getter',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class A {
  static var s;
  var a;
  int b;
  int get hashCode => 1;
  A();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class A {
  static var s;
  var a;
  int b;
  int get hashCode => 1;
  A();
  @generated @override bool operator ==(o) => identical(this, o) || o is A && o.a == a && o.b == b;
}
'''
      );

  testTransformation('@EqualsAndHashCode() should not use private accessors',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class A {
  var a, _b;
  A();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class A {
  var a, _b;
  A();
  @generated @override int get hashCode => hashObjects([a]);
  @generated @override bool operator ==(o) => identical(this, o) || o is A && o.a == a;
}
'''
      );

  testTransformation('@EqualsAndHashCode(includePrivate: true) should use private accessors',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(includePrivate: true)
class A {
  var a, _b;
  A();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(includePrivate: true)
class A {
  var a, _b;
  A();
  @generated @override int get hashCode => hashObjects([a, _b]);
  @generated @override bool operator ==(o) => identical(this, o) || o is A && o.a == a && o._b == _b;
}
'''
      );

  testTransformation('@EqualsAndHashCode(callSuper: true) should call super',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(callSuper: true)
class B extends A {
  static var s;
  final c;
  final String d;
  B(this.c, this.d);
}
''',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(callSuper: true)
class B extends A {
  static var s;
  final c;
  final String d;
  B(this.c, this.d);
  @generated @override int get hashCode => hashObjects([super.hashCode, c, d]);
  @generated @override bool operator ==(o) => identical(this, o) || o is B && super == o && o.c == c && o.d == d;
}
'''
      );

  testTransformation(
      "@EqualsAndHashCode(callSuper: false) shouldn't call super",
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(callSuper: false)
class C extends A {
  static var s;
  final c;
  final String d;
  C(this.c, this.d);
}
''',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(callSuper: false)
class C extends A {
  static var s;
  final c;
  final String d;
  C(this.c, this.d);
  @generated @override int get hashCode => hashObjects([c, d]);
  @generated @override bool operator ==(o) => identical(this, o) || o is C && o.c == c && o.d == d;
}
'''
      );

  testTransformation(
      '@EqualsAndHashCode(exclude: const[#b, #d]) should not use b or d',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(exclude: const [#b, #d])
class D {
  static var s;
  var a;
  int b;
  String c, d;
  D();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(exclude: const [#b, #d])
class D {
  static var s;
  var a;
  int b;
  String c, d;
  D();
  @generated @override int get hashCode => hashObjects([a, c]);
  @generated @override bool operator ==(o) => identical(this, o) || o is D && o.a == a && o.c == c;
}
'''
      );

  testTransformation(
      '@EqualsAndHashCode() should be ok with generics',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class A<T> {
  T a;
  A();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode()
class A<T> {
  T a;
  A();
  @generated @override int get hashCode => hashObjects([a]);
  @generated @override bool operator ==(o) => identical(this, o) || o is A<T> && o.a == a;
}
'''
      );
}
