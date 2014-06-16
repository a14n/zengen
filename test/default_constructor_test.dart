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

library zengen.default_constructor;

import 'transformation.dart';

main() {
  testTransformation('@DefaultConstructor() should create a constructor',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor()
class A {
}
''',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor()
class A {
  @generated A();
}
'''
      );

  testTransformation(
      '@DefaultConstructor() should create a constructor if only final fields',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor()
class A {
  final a, b;
}
@DefaultConstructor()
class B {
  var a;
  final b;
}
''',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor()
class A {
  final a, b;
  @generated A(this.a, this.b);
}
@DefaultConstructor()
class B {
  var a;
  final b;
  @generated B(this.b, {this.a});
}
'''
      );

  testTransformation(
      '@DefaultConstructor() should not use final initialized fields',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor()
class A {
  final a, b = 1;
}
''',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor()
class A {
  final a, b = 1;
  @generated A(this.a);
}
'''
      );
}
