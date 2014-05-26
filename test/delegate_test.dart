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

library zengen.delegate;

import 'transformation.dart';

main() {
  testTransformation('@Delegate() should create delagating methods',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1();
}
class B {
  @Delegate(A) var _a;
}
''',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1();
}
class B {
  @Delegate(A) var _a;
  @generated dynamic m1() => _a.m1();
}
'''
      );

  testTransformation('@Delegate() should handle parameter',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(a, int b);
}
class B {
  @Delegate(A) var _a;
}
''',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(a, int b);
}
class B {
  @Delegate(A) var _a;
  @generated dynamic m1(dynamic a, int b) => _a.m1(a, b);
}
'''
      );

  testTransformation('@Delegate() should handle optional positionnal parameter',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(String a, [int b = 1, c]);
  m2([int b = 1, c]);
}
class B {
  @Delegate(A) var _a;
}
''',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(String a, [int b = 1, c]);
  m2([int b = 1, c]);
}
class B {
  @Delegate(A) var _a;
  @generated dynamic m1(String a, [int b, dynamic c]) => _a.m1(a, b, c);
  @generated dynamic m2([int b, dynamic c]) => _a.m2(b, c);
}
'''
      );

  testTransformation('@Delegate() should handle optional named parameter',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(String a, {int b, c});
  m2({int b, c});
}
class B {
  @Delegate(A) var _a;
}
''',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(String a, {int b, c});
  m2({int b, c});
}
class B {
  @Delegate(A) var _a;
  @generated dynamic m1(String a, {int b, dynamic c}) => _a.m1(a, b: b, c: c);
  @generated dynamic m2({int b, dynamic c}) => _a.m2(b: b, c: c);
}
'''
      );

  testTransformation(
      '@Delegate(A, exclude: const[#b]) should should not create m1',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(String a, {int b, c});
  m2({int b, c});
}
class B {
  @Delegate(A, exclude:  const[#m1]) var _a;
}
''',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(String a, {int b, c});
  m2({int b, c});
}
class B {
  @Delegate(A, exclude:  const[#m1]) var _a;
  @generated dynamic m2({int b, dynamic c}) => _a.m2(b: b, c: c);
}
'''
      );
}
