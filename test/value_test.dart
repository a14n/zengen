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

library zengen.value;

import 'transformation.dart';

main() {
  testTransformation(
      '@Value() should create a constructor and hash/equals + toString',
      r'''
import 'package:zengen/zengen.dart';
@Value()
class A {
}
''',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor()
@EqualsAndHashCode()
@ToString()
@Value()
class A {
  @generated A();
  @generated @override String toString() => "A()";
  @generated @override int get hashCode => hashObjects([]);
  @generated @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType;
}
'''
      );

  testTransformation(
      '@Value() should create a const constructor and hash/equals + toString',
      r'''
import 'package:zengen/zengen.dart';
@Value(useConst: true)
class A {
}
''',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor(useConst: true)
@EqualsAndHashCode()
@ToString()
@Value(useConst: true)
class A {
  @generated const A();
  @generated @override String toString() => "A()";
  @generated @override int get hashCode => hashObjects([]);
  @generated @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType;
}
'''
      );

  testTransformation(
      '@Value() should create a constructor with named optional parameters',
      r'''
import 'package:zengen/zengen.dart';
@Value()
class A {
  final int a;
  final b, c;
  final List d;
}
''',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor()
@EqualsAndHashCode()
@ToString()
@Value()
class A {
  final int a;
  final b, c;
  final List d;
  @generated A(this.a, this.b, this.c, this.d);
  @generated @override String toString() => "A(a=$a, b=$b, c=$c, d=$d)";
  @generated @override int get hashCode => hashObjects([a, b, c, d]);
  @generated @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a && o.b == b && o.c == c && o.d == d;
}
'''
      );

  testTransformation(
      '@Value() should be customized with @EqualsAndHashCode',
      r'''
import 'package:zengen/zengen.dart';
@EqualsAndHashCode(exclude: const[#a])
@Value()
class A {
  final int a, b;
}
''',
      r'''
import 'package:zengen/zengen.dart';
@DefaultConstructor()
@ToString()
@EqualsAndHashCode(exclude: const[#a])
@Value()
class A {
  final int a, b;
  @generated @override int get hashCode => hashObjects([b]);
  @generated @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.b == b;
  @generated A(this.a, this.b);
  @generated @override String toString() => "A(a=$a, b=$b)";
}
'''
      );
}
