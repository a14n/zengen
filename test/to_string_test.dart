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

library zengen.to_string;

import 'transformation.dart';

main() {
  testTransformation('@ToString() should create a toString() method',
      r'''
import 'package:zengen/zengen.dart';
@ToString()
class A {
  static var s;
  var a;
  int b;
  A();
}
''',
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

  testTransformation('@ToString() should not use hashCode getter',
      r'''
import 'package:zengen/zengen.dart';
@ToString()
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
@ToString()
class A {
  static var s;
  var a;
  int b;
  int get hashCode => 1;
  A();
  @generated @override String toString() => "A(a=$a, b=$b)";
}
'''
      );

  testTransformation('@ToString() should not use private accessors',
      r'''
import 'package:zengen/zengen.dart';
@ToString()
class A {
  var a, _b;
  A();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@ToString()
class A {
  var a, _b;
  A();
  @generated @override String toString() => "A(a=$a)";
}
'''
      );

  testTransformation('@ToString(includePrivate: true) should use private accessors',
      r'''
import 'package:zengen/zengen.dart';
@ToString(includePrivate: true)
class A {
  var a, _b;
  A();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@ToString(includePrivate: true)
class A {
  var a, _b;
  A();
  @generated @override String toString() => "A(a=$a, _b=$_b)";
}
'''
      );

  testTransformation('@ToString(callSuper: true) should call super',
      r'''
import 'package:zengen/zengen.dart';
@ToString(callSuper: true)
class A {
  static var s;
  var a;
  int b;
  A();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@ToString(callSuper: true)
class A {
  static var s;
  var a;
  int b;
  A();
  @generated @override String toString() => "A(super=${super.toString()}, a=$a, b=$b)";
}
'''
      );

  testTransformation("@ToString(callSuper: false) shouldn't call super",
      r'''
import 'package:zengen/zengen.dart';
@ToString(callSuper: false)
class A {
  static var s;
  var a;
  int b;
  A();
}
''',
      r'''
import 'package:zengen/zengen.dart';
@ToString(callSuper: false)
class A {
  static var s;
  var a;
  int b;
  A();
  @generated @override String toString() => "A(a=$a, b=$b)";
}
'''
      );

  testTransformation('@ToString(exclude: const[#b, #d]) should not use b or d',
      r'''
import 'package:zengen/zengen.dart';
@ToString(exclude: const [#b, #d])
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
@ToString(exclude: const [#b, #d])
class D {
  static var s;
  var a;
  int b;
  String c, d;
  D();
  @generated @override String toString() => "D(a=$a, c=$c)";
}
'''
      );
}
