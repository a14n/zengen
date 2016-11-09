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

import 'src/transformation.dart';

main() {
  testTransformation(
      '@ToString() should create a toString() method',
      r'''
@ToString()
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
  @override String toString() => "A(a=$a, b=$b)";
}
''');

  testTransformation(
      '@ToString() should not use hashCode getter',
      r'''
@ToString()
class _A {
  static var s;
  var a;
  int b;
  int get hashCode => 1;
  _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  static var s;
  var a;
  int b;
  int get hashCode => 1;
  A();
  @override String toString() => "A(a=$a, b=$b)";
}
''');

  testTransformation(
      '@ToString() should not use private accessors',
      r'''
@ToString()
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
  @override String toString() => "A(a=$a)";
}
''');

  testTransformation(
      '@ToString(includePrivate: true) should use private accessors',
      r'''
@ToString(includePrivate: true)
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
  @override String toString() => "A(a=$a, _b=$_b)";
}
''');

  testTransformation(
      '@ToString(callSuper: true) should call super',
      r'''
@ToString(callSuper: true)
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
  @override String toString() => "A(super=${super.toString()}, a=$a, b=$b)";
}
''');

  testTransformation(
      "@ToString(callSuper: false) shouldn't call super",
      r'''
@ToString(callSuper: false)
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
  @override String toString() => "A(a=$a, b=$b)";
}
''');

  testTransformation(
      '@ToString(exclude: const[#b, #d]) should not use b or d',
      r'''
@ToString(exclude: const [#b, #d])
class _A {
  static var s;
  var a;
  int b;
  String c, d;
  _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  static var s;
  var a;
  int b;
  String c, d;
  A();
  @override String toString() => "D(a=$a, c=$c)";
}
''',
      skip: true);
}
